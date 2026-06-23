import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';
import 'mock_data.dart';
import 'supabase_config.dart';

/// Tracks who has viewed each post or event.
/// Key: contentId (postId or eventId)
/// Value: Set of userIds
///
/// Stored in Hive box "view_tracker_v1" so views survive logout/restart.
class ViewTracker extends ChangeNotifier {
  static const _boxName = 'view_tracker_v1';
  late Box<dynamic> _box;
  bool _initialized = false;
  final Map<String, int> _remotePostViewCounts = {};

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<void> initialize() async {
    if (_initialized) return;
    _box = await Hive.openBox<dynamic>(_boxName);
    _initialized = true;
  }

  // ── Record a view ─────────────────────────────────────────────────────────────

  void recordView(String contentId, String userId, {bool syncRemote = false}) {
    if (userId.isEmpty) return;
    final existing = _viewerIds(contentId);
    final alreadyViewed = existing.contains(userId);
    if (!alreadyViewed) {
      existing.add(userId);
      _box.put(contentId, existing.toList());
      notifyListeners();
    }
    if (syncRemote) {
      unawaited(_recordRemotePostView(contentId: contentId, userId: userId));
    }
  }

  // ── Read ──────────────────────────────────────────────────────────────────────

  int viewCount(String contentId) =>
      _remotePostViewCounts[contentId] ?? _viewerIds(contentId).length;

  Set<String> viewerIds(String contentId) => _viewerIds(contentId);

  List<User> viewers(String contentId) {
    final ids = _viewerIds(contentId);
    return users.where((u) => ids.contains(u.id)).toList();
  }

  Future<void> hydratePostViewCounts(Iterable<String> postIds) async {
    final client = _client;
    if (client == null) return;

    final ids = postIds.where(_looksLikeUuid).toSet().toList();
    if (ids.isEmpty) return;

    try {
      final rows = await client
          .from('post_views')
          .select('post_id')
          .inFilter('post_id', ids);
      final counts = <String, int>{for (final id in ids) id: 0};
      for (final row in rows) {
        final id = (row as Map)['post_id']?.toString();
        if (id == null || id.isEmpty) continue;
        counts[id] = (counts[id] ?? 0) + 1;
      }
      _remotePostViewCounts.addAll(counts);
      notifyListeners();
    } catch (_) {
      // Keep local Hive counts if Supabase view tracking is unavailable.
    }
  }

  // ── Private ───────────────────────────────────────────────────────────────────

  Set<String> _viewerIds(String contentId) {
    if (!_initialized) return {};
    final raw = _box.get(contentId);
    if (raw == null) return {};
    return Set<String>.from(raw as List);
  }

  Future<void> _recordRemotePostView({
    required String contentId,
    required String userId,
  }) async {
    final client = _client;
    if (client == null || !_looksLikeUuid(contentId)) return;

    try {
      await client.from('post_views').upsert({
        'post_id': contentId,
        'profile_id': userId,
        'viewed_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'post_id,profile_id');
      _remotePostViewCounts[contentId] =
          (_remotePostViewCounts[contentId] ?? _viewerIds(contentId).length)
              .clamp(1, 1 << 31);
      notifyListeners();
    } catch (_) {
      // Local tracking already happened; do not disturb the feed.
    }
  }

  bool _looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
    ).hasMatch(value);
  }
}

final viewTracker = ViewTracker();
