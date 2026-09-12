import 'dart:async';
import 'performance_metrics.dart';

/// Small process-local cache for idempotent Supabase reads.
///
/// This deliberately does not persist remote rows to disk: RLS-visible data
/// can change per account, and the existing Hive stores already cover the
/// app's offline-first state. Entries are short-lived and all in-flight calls
/// for the same key share one request.
class SupabaseReadCache {
  SupabaseReadCache({this.maxEntries = 256, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final int maxEntries;
  final DateTime Function() _now;
  final Map<String, _CacheEntry> _entries = {};
  final Map<String, Future<dynamic>> _inFlight = {};
  final Map<String, Object> _requestTokens = {};
  int _generation = 0;

  /// Synchronous stale-while-revalidate read. Callers own the refresh and its
  /// error/loading state; no detached callbacks can outlive a screen/account.
  T? peek<T>(String key, {Duration? maxAge}) {
    final entry = _entries.remove(key);
    if (entry == null) return null;
    _entries[key] = entry;
    if (maxAge != null && _now().difference(entry.createdAt) >= maxAge) {
      return null;
    }
    performanceMetrics.increment('cache.peek_hits');
    return entry.value as T;
  }

  bool isFresh(String key, Duration ttl) {
    final entry = _entries[key];
    return entry != null && _now().difference(entry.createdAt) < ttl;
  }

  int get generation => _generation;

  int get entryCount => _entries.length;

  Future<T> getOrFetch<T>({
    required String key,
    required Duration ttl,
    required Future<T> Function() fetch,
    bool force = false,
    bool Function(T value)? shouldCache,
  }) async {
    if (!force) {
      final entry = _entries[key];
      if (entry != null && isFresh(key, ttl)) {
        performanceMetrics.increment('cache.hits');
        return peek<T>(key) as T;
      }
    }

    final inFlight = _inFlight[key];
    if (inFlight != null) {
      performanceMetrics.increment('cache.in_flight_hits');
      return (await inFlight) as T;
    }

    final generation = _generation;
    final token = Object();
    _requestTokens[key] = token;
    performanceMetrics.increment('cache.misses');
    final future = Future<T>.sync(fetch);
    _inFlight[key] = future;
    try {
      final value = await future;
      if (generation == _generation &&
          identical(token, _requestTokens[key]) &&
          (shouldCache?.call(value) ?? true) &&
          maxEntries > 0) {
        _entries.remove(key);
        _entries[key] = _CacheEntry(value: value, createdAt: _now());
        while (_entries.length > maxEntries) {
          _entries.remove(_entries.keys.first);
        }
      }
      return value;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
      if (identical(token, _requestTokens[key])) _requestTokens.remove(key);
    }
  }

  void invalidate(String key) {
    _requestTokens.remove(key);
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
    _requestTokens.clear();
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
