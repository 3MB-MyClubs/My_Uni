import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/news_post.dart';
import 'auth_service.dart';
import 'supabase_config.dart';

/// Local safety state plus the authenticated Supabase moderation queue.
///
/// Reports and blocks take effect locally before network work begins. This is
/// intentional: objectionable content disappears immediately even if the
/// device is offline, while the server write is retried by the user if it
/// cannot be delivered.
class ModerationService extends ChangeNotifier {
  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  final Set<String> _hiddenPostIds = {};
  final Set<String> _blockedUserIds = {};
  String? _activeUserId;

  Set<String> get hiddenPostIds => Set.unmodifiable(_hiddenPostIds);
  Set<String> get blockedUserIds => Set.unmodifiable(_blockedUserIds);

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String get _actorId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  String _hiddenKey(String userId) => 'moderation_hidden_posts_$userId';
  String _blockedKey(String userId) => 'moderation_blocked_users_$userId';

  bool isPostHidden(NewsPost post) =>
      _hiddenPostIds.contains(post.id) ||
      (post.authorId.isNotEmpty && _blockedUserIds.contains(post.authorId));

  bool isUserBlocked(String userId) => _blockedUserIds.contains(userId);

  /// Loads this account's safety choices and merges server-side blocks.
  Future<void> activateForUser(String userId) async {
    if (userId.isEmpty) return;
    _activeUserId = userId;
    final preferences = await SharedPreferences.getInstance();
    _hiddenPostIds
      ..clear()
      ..addAll(preferences.getStringList(_hiddenKey(userId)) ?? const []);
    _blockedUserIds
      ..clear()
      ..addAll(preferences.getStringList(_blockedKey(userId)) ?? const []);
    notifyListeners();

    final client = _client;
    if (client == null || !_uuidPattern.hasMatch(userId)) return;
    try {
      final rows = await client
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);
      _blockedUserIds.addAll(
        rows
            .map((row) => (row as Map)['blocked_id']?.toString() ?? '')
            .where((id) => id.isNotEmpty),
      );
      await _persist();
      notifyListeners();
    } catch (error) {
      debugPrint('Could not hydrate moderation blocks: $error');
    }
  }

  void clearActiveUser() {
    _activeUserId = null;
    _hiddenPostIds.clear();
    _blockedUserIds.clear();
    notifyListeners();
  }

  /// Queues a post report and removes the post from this user's feed now.
  Future<void> reportPost(NewsPost post, {required String reason}) async {
    _hiddenPostIds.add(post.id);
    await _persist();
    notifyListeners();
    await _submitReport(
      targetType: 'post',
      targetId: post.id,
      reportedUserId: post.authorId,
      reason: reason,
      snapshot: post.content,
    );
  }

  Future<void> reportUser(String userId, {required String reason}) {
    return _submitReport(
      targetType: 'profile',
      targetId: userId,
      reportedUserId: userId,
      reason: reason,
    );
  }

  /// Blocks an abusive account and creates a moderation report in the same
  /// action so the developer is notified of every block.
  Future<void> blockUser(String userId, {required String reason}) async {
    final actorId = _actorId;
    if (userId.isEmpty || userId == actorId) return;

    _blockedUserIds.add(userId);
    await _persist();
    notifyListeners();

    final client = _client;
    if (client != null &&
        _uuidPattern.hasMatch(actorId) &&
        _uuidPattern.hasMatch(userId)) {
      try {
        await client.from('user_blocks').upsert({
          'blocker_id': actorId,
          'blocked_id': userId,
        }, onConflict: 'blocker_id,blocked_id');
      } catch (error) {
        debugPrint('Could not sync user block: $error');
      }
    }

    await _submitReport(
      targetType: 'profile',
      targetId: userId,
      reportedUserId: userId,
      reason: reason,
      source: 'block',
    );
  }

  Future<void> _submitReport({
    required String targetType,
    required String targetId,
    required String reason,
    String? reportedUserId,
    String? snapshot,
    String source = 'report',
  }) async {
    final client = _client;
    final actorId = _actorId;
    if (client == null || !_uuidPattern.hasMatch(actorId)) return;

    final payload = <String, dynamic>{
      'reporter_id': actorId,
      'target_type': targetType,
      'target_id': targetId,
      'reason': reason,
      'source': source,
    };
    if (reportedUserId != null && _uuidPattern.hasMatch(reportedUserId)) {
      payload['reported_user_id'] = reportedUserId;
    }
    final trimmedSnapshot = snapshot?.trim() ?? '';
    if (trimmedSnapshot.isNotEmpty) {
      payload['content_snapshot'] = trimmedSnapshot.length > 2000
          ? trimmedSnapshot.substring(0, 2000)
          : trimmedSnapshot;
    }

    try {
      await client.from('moderation_reports').insert(payload);
    } catch (error) {
      debugPrint('Could not submit moderation report: $error');
      rethrow;
    }
  }

  Future<void> _persist() async {
    final userId = _activeUserId ?? _actorId;
    if (userId.isEmpty) return;
    final preferences = await SharedPreferences.getInstance();
    await Future.wait([
      preferences.setStringList(_hiddenKey(userId), _hiddenPostIds.toList()),
      preferences.setStringList(_blockedKey(userId), _blockedUserIds.toList()),
    ]);
  }
}

final moderationService = ModerationService();
