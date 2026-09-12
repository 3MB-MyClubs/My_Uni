import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'guest_session.dart';
import 'locale_service.dart';
import 'paged_controller.dart';
import 'supabase_config.dart';
import 'supabase_read_cache.dart';

typedef RowPage = CursorPage<Map<String, dynamic>>;

/// Pure, account-scoped reads. Screens merge only accepted controller revisions
/// into legacy registries, never a response from an obsolete search/account.
class FocusedReadService {
  FocusedReadService({SupabaseClient? client, SupabaseReadCache? cache})
    : _override = client,
      _cache = cache ?? supabaseReadCache;
  final SupabaseClient? _override;
  final SupabaseReadCache _cache;
  int _generation = 0;

  SupabaseClient? get client {
    if (guestSession.isActive) return null;
    if (_override != null) return _override;
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get available => client?.auth.currentUser != null;
  String get scope => client?.auth.currentUser?.id ?? 'local';
  String key(String rpc, Map<String, dynamic> params) =>
      'focused:$scope:$rpc:${jsonEncode(params)}';

  RowPage? cached(String rpc, Map<String, dynamic> params) =>
      _cache.peek<RowPage>(key(rpc, params));

  Future<RowPage> page(
    String rpc,
    Map<String, dynamic> params, {
    Map<String, dynamic>? cursor,
    bool force = false,
  }) async {
    final source = client;
    if (source == null) throw StateError('Remote content is unavailable');
    final actor = scope;
    final generation = _generation;
    final cacheGeneration = _cache.generation;
    Future<RowPage> fetch() async {
      final response = await source.rpc(
        rpc,
        params: {...params, 'p_cursor': cursor},
      );
      if (scope != actor ||
          generation != _generation ||
          cacheGeneration != _cache.generation) {
        throw StateError('Read invalidated');
      }
      final json = Map<String, dynamic>.from(response as Map);
      return RowPage(
        items: [
          for (final row in json['items'] as List)
            Map<String, dynamic>.from(row as Map),
        ],
        nextCursor: json['next_cursor'] is Map
            ? Map<String, dynamic>.from(json['next_cursor'] as Map)
            : null,
      );
    }

    if (cursor != null) return fetch();
    return _cache.getOrFetch<RowPage>(
      key: key(rpc, params),
      ttl: const Duration(seconds: 60),
      force: force,
      fetch: fetch,
    );
  }

  Map<String, dynamic> directoryParams({
    required String kind,
    String query = '',
    Map<String, dynamic> filters = const {},
    int limit = 25,
  }) => {
    'p_kind': kind,
    'p_query': query.trim(),
    'p_filters': filters,
    'p_limit': limit.clamp(1, 50),
    'p_language': localeService.languageCode,
  };

  Future<T> read<T>(
    String name,
    Map<String, dynamic> params, {
    bool force = false,
  }) async {
    final actor = scope;
    final generation = _generation;
    final cacheGeneration = _cache.generation;
    final value = await _cache.getOrFetch<T>(
      key: key(name, params),
      ttl: const Duration(seconds: 30),
      force: force,
      fetch: () async => await client!.rpc(name, params: params) as T,
    );
    if (scope != actor ||
        generation != _generation ||
        cacheGeneration != _cache.generation) {
      throw StateError('Read invalidated');
    }
    return value;
  }

  void invalidate() {
    _generation++;
    _cache.invalidateWhere((key) => key.startsWith('focused:'));
  }
}

final focusedReadService = FocusedReadService();
