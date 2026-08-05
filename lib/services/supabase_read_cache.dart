import 'dart:async';

/// Small process-local cache for idempotent Supabase reads.
///
/// This deliberately does not persist remote rows to disk: RLS-visible data
/// can change per account, and the existing Hive stores already cover the
/// app's offline-first state. Entries are short-lived and all in-flight calls
/// for the same key share one request.
class SupabaseReadCache {
  final Map<String, _CacheEntry> _entries = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  final Map<String, int> _keyGenerations = {};
  int _generation = 0;

  Future<T> getOrFetch<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetch,
    bool force = false,
    bool Function(T value)? shouldCache,
  }) async {
    if (!force) {
      final entry = _entries[key];
      if (entry != null && DateTime.now().difference(entry.createdAt) < ttl) {
        return entry.value as T;
      }
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) return (await inFlight) as T;

    final generation = _generation;
    final keyGeneration = _keyGenerations[key] ?? 0;
    final future = fetch();
    _inFlight[key] = future;
    try {
      final value = await future;
      if (generation == _generation &&
          keyGeneration == (_keyGenerations[key] ?? 0) &&
          (shouldCache?.call(value) ?? true)) {
        _entries[key] = _CacheEntry(value: value, createdAt: DateTime.now());
      }
      return value;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  void invalidate(String key) {
    _keyGenerations[key] = (_keyGenerations[key] ?? 0) + 1;
    _entries.remove(key);
    _inFlight.remove(key);
  }

  void invalidateWhere(bool Function(String key) predicate) {
    final keys = {
      ..._entries.keys,
      ..._inFlight.keys,
    }.where(predicate).toList();
    for (final key in keys) {
      invalidate(key);
    }
  }

  void clear() {
    _generation++;
    _entries.clear();
    _keyGenerations.clear();
    // Do not let a request started under the previous auth scope satisfy a
    // later caller after logout/login. The old future may still complete, but
    // it is no longer reachable through this cache.
    _inFlight.clear();
  }
}

class _CacheEntry {
  final dynamic value;
  final DateTime createdAt;

  const _CacheEntry({required this.value, required this.createdAt});
}

final supabaseReadCache = SupabaseReadCache();
