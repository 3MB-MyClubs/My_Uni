import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/notification.dart';
import 'auth_service.dart';
import 'supabase_club_service.dart';
import 'supabase_config.dart';
import 'guest_session.dart';

/// Shared remote notification inbox used by both the Home bell and the
/// notification center.
///
/// Keeping this state outside the screen means the bell can show the server's
/// unread count before the inbox is opened, and both surfaces receive the same
/// realtime inserts and read-state updates.
class NotificationInboxService extends ChangeNotifier {
  final List<Map<String, dynamic>> _rows = [];
  RealtimeChannel? _channel;
  String? _activeUserId;
  Future<void>? _loading;
  bool _isLoading = false;
  bool _hasMore = false;
  Future<void>? _olderTask;
  Map<String, dynamic>? _olderCursor;
  int _generation = 0;
  Object? pageError;
  bool get hasMore => _hasMore;
  bool get isLoadingOlder => _olderTask != null;
  static const _columns =
      'id,user_id,actor_user_id,type,title,body,target_id,target_type,created_at,read_at,localization_args,message_count,notification_group_key';

  Future<void> loadOlder() {
    if (_olderTask != null) return _olderTask!;
    if (!_hasMore || _olderCursor == null || _isLoading) return Future.value();
    final userId = _activeUserId;
    if (userId == null || guestSession.isActive) return Future.value();
    final generation = _generation;
    final cursor = Map<String, dynamic>.from(_olderCursor!);
    late final Future<void> task;
    task =
        (() async {
          pageError = null;
          try {
            final time = cursor['created_at'];
            final id = cursor['id'];
            final page = await Supabase.instance.client
                .from('notifications')
                .select(_columns)
                .eq('user_id', userId)
                .or('created_at.lt.$time,and(created_at.eq.$time,id.lt.$id)')
                .order('created_at', ascending: false)
                .order('id', ascending: false)
                .limit(26);
            final rows = await _attachClubActors(
              page
                  .take(25)
                  .map((row) => Map<String, dynamic>.from(row))
                  .toList(),
            );
            if (_activeUserId != userId || generation != _generation) return;
            final existing = _rows.map((row) => row['id']).toSet();
            _rows.addAll(rows.where((row) => !existing.contains(row['id'])));
            _hasMore = page.length > 25;
            if (rows.isNotEmpty) _olderCursor = rows.last;
          } catch (error) {
            if (generation == _generation) pageError = error;
          }
        })().whenComplete(() {
          if (identical(_olderTask, task)) {
            _olderTask = null;
            notifyListeners();
          }
        });
    _olderTask = task;
    notifyListeners();
    return task;
  }

  List<Map<String, dynamic>> get rows => List.unmodifiable(_rows);

  bool get isLoading => _isLoading;

  int get unreadCount => _rows.where((row) => row['read_at'] == null).length;

  String get _currentUserId =>
      authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';

  Future<void> startForCurrentUser() {
    // No backend inbox exists for a guest; the seed world supplies the alerts
    // through userState.dynamicNotifications instead.
    if (guestSession.isActive) return Future.value();
    final userId = _currentUserId;
    if (!SupabaseConfig.isConfigured || userId.isEmpty) {
      return Future.value();
    }
    // A matching user may already be mid-refresh before its realtime channel
    // is attached. Reuse that work instead of recursively switching users.
    if (_activeUserId == userId) {
      return _loading ?? Future.value();
    }
    return _switchUser(userId);
  }

  Future<void> _switchUser(String userId) async {
    final oldChannel = _channel;
    _channel = null;
    _activeUserId = userId;
    _generation++;
    _olderTask = null;
    _loading = null;
    _olderCursor = null;
    _hasMore = false;
    _rows.clear();
    notifyListeners();
    if (oldChannel != null) {
      try {
        await Supabase.instance.client.removeChannel(oldChannel);
      } catch (_) {
        // Supabase may not be initialized in offline/widget-test sessions.
      }
    }
    await refresh();
    if (_activeUserId != userId) return;
    _subscribe(userId);
  }

  Future<void> refresh() {
    if (guestSession.isActive) return Future.value();
    final userId = _activeUserId ?? _currentUserId;
    if (!SupabaseConfig.isConfigured || userId.isEmpty) {
      return Future.value();
    }
    if (_loading != null) return _loading!;
    late final Future<void> task;
    task = _load(userId).whenComplete(() {
      if (identical(_loading, task)) _loading = null;
    });
    return _loading = task;
  }

  Future<void> _load(String userId) async {
    final generation = ++_generation;
    _olderTask = null;
    _isLoading = true;
    notifyListeners();
    try {
      final rows = await Supabase.instance.client
          .from('notifications')
          .select(_columns)
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(101);
      if (_activeUserId != userId) return;
      final hydratedRows = await _attachClubActors(
        rows.take(100).map((row) => Map<String, dynamic>.from(row)).toList(),
      );
      if (_activeUserId != userId || generation != _generation) return;
      _hasMore = rows.length > 100;
      _olderCursor = hydratedRows.isEmpty ? null : hydratedRows.last;
      _rows
        ..clear()
        ..addAll(hydratedRows);
      notifyListeners();
    } catch (_) {
      // The local/mock notification feed remains available offline.
    } finally {
      if (_activeUserId == userId && generation == _generation) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void _subscribe(String userId) {
    try {
      _channel = Supabase.instance.client
          .channel('notification-inbox:$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'notifications',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) {
              if (_activeUserId != userId) return;
              final record = payload.newRecord;
              if (record.isEmpty) {
                final deletedId = payload.oldRecord['id']?.toString();
                final before = _rows.length;
                if (deletedId != null) {
                  _rows.removeWhere(
                    (row) => row['id']?.toString() == deletedId,
                  );
                }
                if (_rows.length != before) {
                  notifyListeners();
                }
                return;
              }
              final row = Map<String, dynamic>.from(record);
              _upsert(row);
              if (_canHaveClubActor(row)) {
                unawaited(_hydrateRealtimeClubActor(row, userId));
              }
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime is an enhancement; the inbox still works from local data.
    }
  }

  bool _canHaveClubActor(Map<String, dynamic> row) {
    final type = row['type']?.toString();
    return row['target_type']?.toString() == 'club' ||
        type == 'club_post' ||
        type == 'club_event' ||
        type == 'club_channel_message' ||
        type == 'club_inbox_message';
  }

  Future<void> _hydrateRealtimeClubActor(
    Map<String, dynamic> row,
    String userId,
  ) async {
    final hydrated = await _attachClubActors([row]);
    if (_activeUserId != userId || hydrated.isEmpty) return;
    _upsert(hydrated.first);
  }

  /// Adds transient club identity fields to club-originated notification rows.
  /// These are UI metadata only; they are never written back to Supabase.
  Future<List<Map<String, dynamic>>> _attachClubActors(
    List<Map<String, dynamic>> source,
  ) async {
    final rows = source.map((row) => {...row}).toList();
    if (rows.isEmpty || !rows.any(_canHaveClubActor)) return rows;

    final client = Supabase.instance.client;
    final postIds = <String>{};
    final eventIds = <String>{};
    final inboxThreadIds = <String>{};
    final clubIdByRow = <int, String>{};

    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      final type = row['type']?.toString();
      final targetType = row['target_type']?.toString();
      final targetId = row['target_id']?.toString();
      if (targetId == null || targetId.isEmpty) continue;

      if (targetType == 'club' || type == 'club_channel_message') {
        clubIdByRow[index] = targetId;
      } else if (type == 'club_post') {
        postIds.add(targetId);
      } else if (type == 'club_event') {
        eventIds.add(targetId);
      } else if (type == 'club_inbox_message') {
        inboxThreadIds.add(targetId);
      }
    }

    final postClubIds = <String, String>{};
    final eventClubIds = <String, String>{};
    final inboxThreads = <String, ({String clubId, String studentProfileId})>{};

    if (postIds.isNotEmpty) {
      try {
        final matches = await client
            .from('club_posts')
            .select('id, club_id')
            .inFilter('id', postIds.toList());
        for (final item in matches) {
          final id = item['id']?.toString();
          final clubId = item['club_id']?.toString();
          if (id != null && clubId != null) postClubIds[id] = clubId;
        }
      } catch (_) {
        // The inbox still renders with its normal fallback if content is gone.
      }
    }

    if (eventIds.isNotEmpty) {
      try {
        final matches = await client
            .from('events')
            .select('id, club_id')
            .inFilter('id', eventIds.toList());
        for (final item in matches) {
          final id = item['id']?.toString();
          final clubId = item['club_id']?.toString();
          if (id != null && clubId != null) eventClubIds[id] = clubId;
        }
      } catch (_) {
        // The inbox still renders with its normal fallback if content is gone.
      }
    }

    if (inboxThreadIds.isNotEmpty) {
      try {
        final matches = await client
            .from('club_inbox_threads')
            .select('id, club_id, profile_id')
            .inFilter('id', inboxThreadIds.toList());
        for (final item in matches) {
          final id = item['id']?.toString();
          final clubId = item['club_id']?.toString();
          final profileId = item['profile_id']?.toString();
          if (id != null && clubId != null && profileId != null) {
            inboxThreads[id] = (clubId: clubId, studentProfileId: profileId);
          }
        }
      } catch (_) {
        // Student-authored inbox messages should continue to use the student.
      }
    }

    for (var index = 0; index < rows.length; index++) {
      if (clubIdByRow.containsKey(index)) continue;
      final row = rows[index];
      final type = row['type']?.toString();
      final targetId = row['target_id']?.toString();
      if (targetId == null) continue;
      if (type == 'club_post') {
        final clubId = postClubIds[targetId];
        if (clubId != null) clubIdByRow[index] = clubId;
      } else if (type == 'club_event') {
        final clubId = eventClubIds[targetId];
        if (clubId != null) clubIdByRow[index] = clubId;
      } else if (type == 'club_inbox_message') {
        final thread = inboxThreads[targetId];
        // The thread's student receives only club-authored messages. Club
        // admins receiving the same notification should see the student actor.
        if (thread != null &&
            thread.studentProfileId == row['user_id']?.toString()) {
          clubIdByRow[index] = thread.clubId;
        }
      }
    }

    if (clubIdByRow.isEmpty) return rows;

    for (final entry in clubIdByRow.entries) {
      final args = rows[entry.key]['localization_args'];
      final clubName = args is Map ? args['clubName']?.toString() : null;
      rows[entry.key]['_actor_club_id'] = entry.value;
      if (clubName != null && clubName.trim().isNotEmpty) {
        rows[entry.key]['_actor_club_name'] = clubName;
      }
    }

    try {
      final clubIds = clubIdByRow.values.toSet().toList();
      final clubRows = await client
          .from('clubs')
          .select('id, name, logo_url')
          .inFilter('id', clubIds);
      final clubsById = <String, Map<String, dynamic>>{};
      for (final club in clubRows) {
        final id = club['id']?.toString();
        if (id != null) clubsById[id] = Map<String, dynamic>.from(club);
      }
      for (final entry in clubIdByRow.entries) {
        final club = clubsById[entry.value];
        if (club == null) continue;
        final name = club['name']?.toString().trim();
        final logoUrl = supabaseClubService.publicLogoUrl(
          club['logo_url']?.toString(),
        );
        if (name != null && name.isNotEmpty) {
          rows[entry.key]['_actor_club_name'] = name;
        }
        if (logoUrl != null && logoUrl.isNotEmpty) {
          rows[entry.key]['_actor_club_logo_url'] = logoUrl;
        }
      }
    } catch (_) {
      // A name from localization args and ClubAvatar's local fallback remain.
    }
    return rows;
  }

  void _upsert(Map<String, dynamic> row) {
    final id = row['id']?.toString();
    if (id == null || id.isEmpty) return;
    final index = _rows.indexWhere((item) => item['id']?.toString() == id);
    if (index < 0) {
      _rows.insert(0, row);
    } else {
      final existing = _rows[index];
      final merged = {...existing, ...row};
      // Club metadata arrives asynchronously. Preserve it across normal
      // realtime row updates, and never undo an optimistic local read while an
      // older realtime payload is still in flight.
      if (existing['read_at'] != null && row['read_at'] == null) {
        merged['read_at'] = existing['read_at'];
      }
      _rows[index] = merged;
    }
    _rows.sort((a, b) {
      final aDate = DateTime.tryParse(a['created_at']?.toString() ?? '');
      final bDate = DateTime.tryParse(b['created_at']?.toString() ?? '');
      return (bDate ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
        aDate ?? DateTime.fromMillisecondsSinceEpoch(0),
      );
    });
    notifyListeners();
  }

  void markRead(String notificationId) {
    if (guestSession.isActive) return;
    final index = _rows.indexWhere(
      (item) => item['id']?.toString() == notificationId,
    );
    if (index < 0 || _rows[index]['read_at'] != null) return;
    final readAt = DateTime.now().toUtc().toIso8601String();
    _rows[index] = {..._rows[index], 'read_at': readAt};
    notifyListeners();
    unawaited(_persistRead(notificationId, readAt));
  }

  Future<void> _persistRead(String notificationId, String readAt) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': readAt})
          .eq('id', notificationId);
    } catch (_) {
      // Preserve the optimistic local read state while offline.
    }
  }

  /// Marks every remote notification row belonging to the open chat as read.
  /// Other conversations and non-message notifications are left unchanged.
  Future<void> markChatThreadRead({
    required String threadId,
    required String userId,
  }) async {
    final conversationKey = notificationConversationKeyForThread(
      threadId: threadId,
      userId: userId,
    );
    if (conversationKey == null) return;

    await startForCurrentUser();
    if (_activeUserId != userId) return;

    final readAt = DateTime.now().toUtc().toIso8601String();
    final notificationIds = <String>[];
    for (var index = 0; index < _rows.length; index++) {
      final row = _rows[index];
      if (row['read_at'] != null || row['target_type'] != 'message') continue;
      final notification = AppNotification(
        id: row['id']?.toString() ?? '',
        userId: row['user_id']?.toString() ?? '',
        message: row['body']?.toString() ?? '',
        createdAt:
            DateTime.tryParse(row['created_at']?.toString() ?? '') ??
            DateTime.fromMillisecondsSinceEpoch(0),
        notificationType: row['type']?.toString(),
        targetType: row['target_type']?.toString(),
        targetId: row['target_id']?.toString(),
        fromId: row['actor_user_id']?.toString(),
      );
      if (notificationConversationKey(notification) != conversationKey) {
        continue;
      }
      final notificationId = notification.id;
      if (notificationId.isEmpty) continue;
      notificationIds.add(notificationId);
      _rows[index] = {...row, 'read_at': readAt};
    }
    if (notificationIds.isEmpty) return;
    notifyListeners();
    await _persistChatThreadRead(userId, notificationIds, readAt);
  }

  Future<void> _persistChatThreadRead(
    String userId,
    List<String> notificationIds,
    String readAt,
  ) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': readAt})
          .eq('user_id', userId)
          .inFilter('id', notificationIds);
    } catch (_) {
      // Preserve the optimistic local read state while offline.
    }
  }

  void markAllRead() {
    if (guestSession.isActive) return;
    if (_rows.every((row) => row['read_at'] != null)) return;
    final readAt = DateTime.now().toUtc().toIso8601String();
    for (var index = 0; index < _rows.length; index++) {
      _rows[index] = {..._rows[index], 'read_at': readAt};
    }
    notifyListeners();
    final userId = _activeUserId ?? _currentUserId;
    if (userId.isNotEmpty) unawaited(_persistAllRead(userId, readAt));
  }

  Future<void> _persistAllRead(String userId, String readAt) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': readAt})
          .eq('user_id', userId)
          .isFilter('read_at', null);
    } catch (_) {
      // Preserve the optimistic local read state while offline.
    }
  }
}

final notificationInboxService = NotificationInboxService();
