import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_message.dart';
import '../models/chat_group.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'club_admin_access.dart';
import 'mock_data.dart';
import 'people_service.dart';
import 'supabase_config.dart';
import 'user_state.dart';

/// Local-first messaging: 1:1 direct messages, student-created groups, plus
/// one members-only community chat per club.
///
/// Messages and per-user read state persist to Hive. Group membership and an
/// optional custom name are persisted too; an unnamed group's displayed name
/// is always derived from its current members at render time.
///
/// Like the other stores, every method no-ops / returns empty before
/// [initialize] so screens render safely in widget tests without Hive.
class ChatStore extends ChangeNotifier {
  static const _boxName = 'chat_v1';

  /// Bump this integer any time the club-chat seed conversations change.
  /// A mismatch drops the old seed messages and writes the fresh ones
  /// (user-sent messages are untouched).
  static const int _seedVersion = 1;

  /// Removes direct-message data created before admin messaging was limited
  /// to the managed club community.
  static const int _adminMessagingMigrationVersion = 1;

  Box<dynamic>? _box;

  final List<ChatMessage> _messages = [];

  /// Local-first outbox. IDs remain here until Supabase acknowledges storage.
  final Set<String> _pendingRemoteMessageIds = {};

  /// DM threads whose incoming delivered messages were seen while offline.
  final Set<String> _pendingSeenThreadIds = {};

  RealtimeChannel? _directMessageChannel;
  RealtimeChannel? _groupMessageChannel;
  String? _syncedUserId;
  Timer? _syncRetry;
  bool _flushingRemote = false;

  /// Direct-message threads that have been opened, including conversations
  /// that do not have a first message yet.
  final Set<String> _directThreadIds = {};

  final Map<String, ChatGroup> _groups = {};
  final Set<String> _pendingRemoteGroupIds = {};
  final Set<String> _pendingRemoteGroupMessageIds = {};

  /// userId → threadId → last time that user opened the thread.
  final Map<String, Map<String, DateTime>> _lastRead = {};

  /// Students whose demo DM threads have already been seeded.
  final Set<String> _dmSeededUserIds = {};

  // ── Thread identity ──────────────────────────────────────────────────────────

  static String dmThreadId(String a, String b) {
    final pair = [a, b]..sort();
    return 'dm:${pair.join('|')}';
  }

  static String clubThreadId(String clubId) => 'club:$clubId';

  static String groupThreadId(String groupId) => 'group:$groupId';

  static bool isClubThread(String threadId) => threadId.startsWith('club:');

  static bool isDirectThread(String threadId) => threadId.startsWith('dm:');

  static bool isGroupThread(String threadId) => threadId.startsWith('group:');

  /// The club id of a `club:` thread, or null for DM threads.
  static String? clubIdOf(String threadId) =>
      isClubThread(threadId) ? threadId.substring(5) : null;

  static String? groupIdOf(String threadId) =>
      isGroupThread(threadId) ? threadId.substring(6) : null;

  static List<String> dmParticipants(String threadId) {
    if (!threadId.startsWith('dm:')) return const [];
    final participants = threadId.substring(3).split('|');
    return participants.length == 2 && participants.every((id) => id.isNotEmpty)
        ? participants
        : const [];
  }

  /// The other participant of a DM thread, or null if [myId] isn't in it.
  static String? dmPeerOf(String threadId, String myId) {
    final parts = dmParticipants(threadId);
    if (!parts.contains(myId)) return null;
    return parts.firstWhere((id) => id != myId, orElse: () => myId);
  }

  ChatGroup? groupForThread(String threadId) {
    final groupId = groupIdOf(threadId);
    return groupId == null ? null : _groups[groupId];
  }

  List<String> groupParticipants(String threadId) =>
      groupForThread(threadId)?.memberIds ?? const [];

  String _nameForUser(String userId) {
    final cachedIndex = peopleService.cachedPeople.indexWhere(
      (user) => user.id == userId,
    );
    final mockIndex = users.indexWhere((user) => user.id == userId);
    final fallback = cachedIndex != -1
        ? peopleService.cachedPeople[cachedIndex].name
        : mockIndex != -1
        ? users[mockIndex].name
        : userId;
    return userState.displayNameFor(userId, fallback);
  }

  String groupDisplayName(String threadId, String viewerId) {
    final group = groupForThread(threadId);
    if (group == null) return 'Group';
    return group.displayName(viewerId: viewerId, nameForUser: _nameForUser);
  }

  // ── Lifecycle ────────────────────────────────────────────────────────────────

  Future<void> initialize() async {
    if (_box != null) return;
    final box = await Hive.openBox<dynamic>(_boxName);

    final rawMessages = box.get('messages');
    if (rawMessages is List) {
      _messages.addAll(
        rawMessages.map(
          (m) => ChatMessage.fromMap(Map<String, dynamic>.from(m as Map)),
        ),
      );
    }
    final rawLastRead = box.get('lastRead');
    if (rawLastRead is Map) {
      for (final entry in rawLastRead.entries) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        _lastRead[entry.key.toString()] = inner.map(
          (threadId, iso) => MapEntry(threadId, DateTime.parse(iso as String)),
        );
      }
    }
    _migrateLegacyDmReadState();
    final rawPendingRemote = box.get('pendingRemoteMessageIds');
    if (rawPendingRemote is List) {
      _pendingRemoteMessageIds.addAll(
        rawPendingRemote.map((id) => id.toString()),
      );
    }
    final rawPendingSeen = box.get('pendingSeenThreadIds');
    if (rawPendingSeen is List) {
      _pendingSeenThreadIds.addAll(rawPendingSeen.map((id) => id.toString()));
    }
    final rawSeeded = box.get('dmSeededUserIds');
    if (rawSeeded is List) {
      _dmSeededUserIds.addAll(rawSeeded.map((id) => id.toString()));
    }
    final rawDirectThreads = box.get('directThreadIds');
    if (rawDirectThreads is List) {
      _directThreadIds.addAll(
        rawDirectThreads
            .map((id) => id.toString())
            .where((id) => id.startsWith('dm:')),
      );
    }
    final rawGroups = box.get('groups');
    if (rawGroups is List) {
      for (final raw in rawGroups) {
        final group = ChatGroup.fromMap(Map<String, dynamic>.from(raw as Map));
        if (group.id.isNotEmpty) _groups[group.id] = group;
      }
    }
    final rawPendingGroups = box.get('pendingRemoteGroupIds');
    if (rawPendingGroups is List) {
      _pendingRemoteGroupIds.addAll(
        rawPendingGroups.map((id) => id.toString()),
      );
    }
    final rawPendingGroupMessages = box.get('pendingRemoteGroupMessageIds');
    if (rawPendingGroupMessages is List) {
      _pendingRemoteGroupMessageIds.addAll(
        rawPendingGroupMessages.map((id) => id.toString()),
      );
    }
    // Existing installs predate the explicit empty-thread registry. Preserve
    // every conversation that can already be inferred from its messages.
    _directThreadIds.addAll(
      _messages.map((message) => message.threadId).where(isDirectThread),
    );

    final storedAdminMigrationVersion =
        box.get('adminMessagingMigrationVersion') as int? ?? 0;
    final migratedAdminMessaging =
        storedAdminMigrationVersion < _adminMessagingMigrationVersion;
    if (migratedAdminMessaging) {
      _removeLegacyAdminDirectData();
      await box.put(
        'adminMessagingMigrationVersion',
        _adminMessagingMigrationVersion,
      );
    }

    final storedVersion = box.get('seedVersion') as int? ?? 0;
    if (storedVersion != _seedVersion) {
      _messages.removeWhere((m) => m.id.startsWith('seed_club_'));
      _seedClubHistory();
      box.put('seedVersion', _seedVersion);
    }

    _box = box;
    if (storedVersion != _seedVersion || migratedAdminMessaging) {
      unawaited(saveAll());
    }
  }

  void _migrateLegacyDmReadState() {
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (!isDirectThread(message.threadId) || message.seenAt != null) continue;
      final recipientId = dmPeerOf(message.threadId, message.senderId);
      if (recipientId == null) continue;
      final lastRead = _lastRead[recipientId]?[message.threadId];
      if (lastRead != null && !message.createdAt.isAfter(lastRead)) {
        _messages[i] = message.copyWith(seenAt: lastRead);
      }
    }
  }

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      // Widget tests and offline previews do not initialize Supabase.
      return null;
    }
  }

  /// Starts authenticated realtime streams for direct and group messages,
  /// then reconciles the local Hive mirror and outboxes.
  Future<void> startDirectMessageSync(String userId) async {
    if (userId.isEmpty || isAdminAccountId(userId)) return;
    final client = _client;
    if (client == null || client.auth.currentUser?.id != userId) return;
    if (_syncedUserId == userId &&
        _directMessageChannel != null &&
        _groupMessageChannel != null) {
      await _reconcileRemoteMessages(client, userId);
      await _reconcileRemoteGroups(client, userId);
      return;
    }

    final oldChannel = _directMessageChannel;
    if (oldChannel != null) await client.removeChannel(oldChannel);
    final oldGroupChannel = _groupMessageChannel;
    if (oldGroupChannel != null) await client.removeChannel(oldGroupChannel);
    _syncRetry?.cancel();
    _syncedUserId = userId;

    final channel = client
        .channel('direct-messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'sender_id',
            value: userId,
          ),
          callback: _handleDirectMessageChange,
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'direct_messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'receiver_id',
            value: userId,
          ),
          callback: _handleDirectMessageChange,
        );
    _directMessageChannel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(_flushRemoteChanges());
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        if (identical(_directMessageChannel, channel)) {
          _directMessageChannel = null;
        }
        _scheduleSyncRetry();
      }
    });

    await _reconcileRemoteMessages(client, userId);
    await _startGroupMessageSync(client, userId);
  }

  Future<void> _startGroupMessageSync(
    SupabaseClient client,
    String userId,
  ) async {
    final channel = client
        .channel('group-messages:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_chats',
          callback: (_) => unawaited(_reconcileRemoteGroups(client, userId)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_chat_members',
          callback: (_) => unawaited(_reconcileRemoteGroups(client, userId)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_messages',
          callback: (payload) {
            final record = payload.newRecord;
            if (record.isNotEmpty) _mergeRemoteGroupMessage(record, userId);
          },
        );
    _groupMessageChannel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(_flushRemoteChanges());
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        if (identical(_groupMessageChannel, channel)) {
          _groupMessageChannel = null;
        }
        _scheduleSyncRetry();
      }
    });
    await _reconcileRemoteGroups(client, userId);
  }

  Future<void> _reconcileRemoteGroups(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final ownMembershipRows = await client
          .from('group_chat_members')
          .select('group_id')
          .eq('user_id', userId);
      final groupIds = ownMembershipRows
          .map((row) => row['group_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();
      final removedGroupIds = _groups.values
          .where(
            (group) =>
                group.memberIds.contains(userId) &&
                !groupIds.contains(group.id) &&
                !_pendingRemoteGroupIds.contains(group.id),
          )
          .map((group) => group.id)
          .toList();
      for (final groupId in removedGroupIds) {
        _groups.remove(groupId);
        final threadId = groupThreadId(groupId);
        _messages.removeWhere((message) => message.threadId == threadId);
        _lastRead[userId]?.remove(threadId);
      }
      if (groupIds.isEmpty) {
        if (removedGroupIds.isNotEmpty) {
          scheduleSave();
          notifyListeners();
        }
        await _flushRemoteChanges();
        return;
      }

      final results = await Future.wait([
        client
            .from('group_chats')
            .select('id, creator_id, custom_name, photo_url, created_at')
            .inFilter('id', groupIds),
        client
            .from('group_chat_members')
            .select('group_id, user_id, position, joined_at')
            .inFilter('group_id', groupIds)
            .order('position')
            .order('joined_at'),
        client
            .from('group_messages')
            .select('id, group_id, sender_id, content, created_at')
            .inFilter('group_id', groupIds)
            .order('created_at'),
      ]);
      final membersByGroup = <String, List<String>>{};
      for (final raw in results[1]) {
        final row = Map<String, dynamic>.from(raw as Map);
        final groupId = row['group_id']?.toString() ?? '';
        final memberId = row['user_id']?.toString() ?? '';
        if (groupId.isNotEmpty && memberId.isNotEmpty) {
          (membersByGroup[groupId] ??= []).add(memberId);
        }
      }
      for (final raw in results[0]) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = row['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        // Do not let a realtime echo replace an optimistic local edit while
        // its custom name, membership, or device-local photo is still syncing.
        if (_pendingRemoteGroupIds.contains(id) && _groups[id] != null) {
          continue;
        }
        final custom = row['custom_name']?.toString().trim() ?? '';
        _groups[id] = ChatGroup(
          id: id,
          creatorId: row['creator_id']?.toString() ?? '',
          memberIds: membersByGroup[id] ?? const [],
          customName: custom.isEmpty ? null : custom,
          photoUrl: row['photo_url']?.toString(),
          createdAt:
              DateTime.tryParse(
                row['created_at']?.toString() ?? '',
              )?.toLocal() ??
              DateTime.now(),
        );
      }
      for (final raw in results[2]) {
        _mergeRemoteGroupMessage(
          Map<String, dynamic>.from(raw as Map),
          userId,
          notifyRecipient: false,
        );
      }
      scheduleSave();
      notifyListeners();
      await _flushRemoteChanges();
    } catch (_) {
      _scheduleSyncRetry();
    }
  }

  void _mergeRemoteGroupMessage(
    Map<String, dynamic> row,
    String viewerId, {
    bool notifyRecipient = true,
  }) {
    final id = row['id']?.toString() ?? '';
    final groupId = row['group_id']?.toString() ?? '';
    final senderId = row['sender_id']?.toString() ?? '';
    final content = row['content']?.toString() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id.isEmpty ||
        groupId.isEmpty ||
        senderId.isEmpty ||
        content.isEmpty ||
        createdAt == null ||
        _groups[groupId] == null) {
      return;
    }
    if (_messages.any((message) => message.id == id)) {
      _pendingRemoteGroupMessageIds.remove(id);
      return;
    }
    final message = ChatMessage(
      id: id,
      threadId: groupThreadId(groupId),
      senderId: senderId,
      content: content,
      createdAt: createdAt.toLocal(),
      deliveredAt: createdAt.toLocal(),
    );
    _messages.add(message);
    _pendingRemoteGroupMessageIds.remove(id);
    if (notifyRecipient && senderId != viewerId) {
      final groupName = groupDisplayName(message.threadId, viewerId);
      final senderName = _nameForUser(senderId);
      userState.addNotification(
        AppNotification(
          id: 'remote_group_msg_${message.id}_$viewerId',
          userId: viewerId,
          message: '$groupName: $senderName sent a message.',
          createdAt: message.createdAt,
          targetType: 'message',
          targetId: message.threadId,
          fromId: senderId,
        ),
      );
    }
    scheduleSave();
    notifyListeners();
  }

  Future<void> _reconcileRemoteMessages(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final rows = await client
          .from('direct_messages')
          .select(
            'id, sender_id, receiver_id, content, created_at, delivered_at, seen_at, read_at',
          )
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at');
      _mergeRemoteRows(rows);
      await _flushRemoteChanges();
    } catch (_) {
      _scheduleSyncRetry();
    }
  }

  void _handleDirectMessageChange(PostgresChangePayload payload) {
    final record = payload.newRecord;
    if (record.isEmpty) return;
    final message = _messageFromRemoteRow(record);
    if (message == null) return;
    _mergeRemoteMessages([message]);
  }

  void _mergeRemoteRows(List<dynamic> rows) {
    _mergeRemoteMessages(
      rows
          .map(
            (row) =>
                _messageFromRemoteRow(Map<String, dynamic>.from(row as Map)),
          )
          .whereType<ChatMessage>(),
    );
  }

  ChatMessage? _messageFromRemoteRow(Map<String, dynamic> row) {
    final id = row['id']?.toString() ?? '';
    final senderId = row['sender_id']?.toString() ?? '';
    final receiverId = row['receiver_id']?.toString() ?? '';
    final content = row['content']?.toString() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id.isEmpty ||
        senderId.isEmpty ||
        receiverId.isEmpty ||
        content.isEmpty ||
        createdAt == null) {
      return null;
    }
    final deliveredAt =
        DateTime.tryParse(row['delivered_at']?.toString() ?? '') ?? createdAt;
    final seenAt = DateTime.tryParse(
      (row['seen_at'] ?? row['read_at'])?.toString() ?? '',
    );
    return ChatMessage(
      id: id,
      threadId: dmThreadId(senderId, receiverId),
      senderId: senderId,
      content: content,
      createdAt: createdAt.toLocal(),
      deliveredAt: deliveredAt.toLocal(),
      seenAt: seenAt?.toLocal(),
    );
  }

  void _mergeRemoteMessages(Iterable<ChatMessage> remoteMessages) {
    var changed = false;
    for (final remote in remoteMessages) {
      final index = _messages.indexWhere((local) => local.id == remote.id);
      if (index == -1) {
        _messages.add(remote);
        changed = true;
      } else {
        final local = _messages[index];
        // Never roll back an optimistic offline Seen receipt while its batch
        // update is waiting to reach Supabase.
        final merged = remote.seenAt == null && local.seenAt != null
            ? remote.copyWith(seenAt: local.seenAt)
            : remote;
        if (local.content != merged.content ||
            local.deliveredAt != merged.deliveredAt ||
            local.seenAt != merged.seenAt) {
          _messages[index] = merged;
          changed = true;
        }
      }
      _directThreadIds.add(remote.threadId);
      _pendingRemoteMessageIds.remove(remote.id);
    }
    if (!changed) return;
    scheduleSave();
    notifyListeners();
  }

  Future<void> _flushRemoteChanges() async {
    if (_flushingRemote) return;
    final userId = _syncedUserId;
    final client = _client;
    if (userId == null ||
        client == null ||
        client.auth.currentUser?.id != userId) {
      return;
    }
    _flushingRemote = true;
    var failed = false;
    try {
      for (final groupId in _pendingRemoteGroupIds.toList()) {
        final group = _groups[groupId];
        if (group == null || group.creatorId != userId) continue;
        try {
          final localPhoto = group.photoUrl?.trim() ?? '';
          final hasRemotePhoto =
              localPhoto.startsWith('http://') ||
              localPhoto.startsWith('https://');
          await client.from('group_chats').upsert({
            'id': group.id,
            'creator_id': group.creatorId,
            'custom_name': group.customName,
            'photo_url': hasRemotePhoto ? localPhoto : null,
            'created_at': group.createdAt.toUtc().toIso8601String(),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
          if (localPhoto.isNotEmpty && !hasRemotePhoto) {
            final file = File(localPhoto);
            if (await file.exists()) {
              final objectPath = '${group.id}/avatar.jpg';
              await client.storage
                  .from('group-chat-photos')
                  .uploadBinary(
                    objectPath,
                    await file.readAsBytes(),
                    fileOptions: const FileOptions(
                      upsert: true,
                      contentType: 'image/jpeg',
                    ),
                  );
              final publicUrl = client.storage
                  .from('group-chat-photos')
                  .getPublicUrl(objectPath);
              await client
                  .from('group_chats')
                  .update({'photo_url': publicUrl})
                  .eq('id', group.id);
              _groups[group.id] = group.withPhoto(publicUrl);
            }
          }
          final existingRows = await client
              .from('group_chat_members')
              .select('user_id')
              .eq('group_id', group.id);
          final existingIds = existingRows
              .map((row) => row['user_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toSet();
          final staleIds = existingIds.difference(group.memberIds.toSet());
          if (staleIds.isNotEmpty) {
            await client
                .from('group_chat_members')
                .delete()
                .eq('group_id', group.id)
                .inFilter('user_id', staleIds.toList());
          }
          await client.from('group_chat_members').upsert([
            for (var index = 0; index < group.memberIds.length; index++)
              {
                'group_id': group.id,
                'user_id': group.memberIds[index],
                'position': index,
              },
          ]);
          _pendingRemoteGroupIds.remove(groupId);
        } catch (_) {
          failed = true;
        }
      }

      final pendingGroupMessages = _messages.where((message) {
        return _pendingRemoteGroupMessageIds.contains(message.id) &&
            message.senderId == userId &&
            isGroupThread(message.threadId);
      }).toList();
      for (final message in pendingGroupMessages) {
        final groupId = groupIdOf(message.threadId);
        if (groupId == null) continue;
        try {
          await client.from('group_messages').insert({
            'id': message.id,
            'group_id': groupId,
            'sender_id': userId,
            'content': message.content,
            'created_at': message.createdAt.toUtc().toIso8601String(),
          });
          _pendingRemoteGroupMessageIds.remove(message.id);
        } on PostgrestException catch (error) {
          if (error.code == '23505') {
            _pendingRemoteGroupMessageIds.remove(message.id);
          } else {
            failed = true;
          }
        } catch (_) {
          failed = true;
        }
      }

      final pendingMessages = _messages.where((message) {
        return _pendingRemoteMessageIds.contains(message.id) &&
            message.senderId == userId &&
            isDirectThread(message.threadId);
      }).toList();
      for (final message in pendingMessages) {
        final receiverId = dmPeerOf(message.threadId, userId);
        if (receiverId == null) continue;
        try {
          await client.from('direct_messages').insert({
            'id': message.id,
            'sender_id': userId,
            'receiver_id': receiverId,
            'content': message.content,
            'created_at': message.createdAt.toUtc().toIso8601String(),
            'delivered_at': message.deliveredAt.toUtc().toIso8601String(),
          });
          _pendingRemoteMessageIds.remove(message.id);
        } on PostgrestException catch (error) {
          if (error.code == '23505') {
            _pendingRemoteMessageIds.remove(message.id);
          } else {
            failed = true;
          }
        } catch (_) {
          failed = true;
        }
      }

      for (final threadId in _pendingSeenThreadIds.toList()) {
        final senderId = dmPeerOf(threadId, userId);
        if (senderId == null) continue;
        final seenAt = _messages
            .where(
              (message) =>
                  message.threadId == threadId &&
                  message.senderId == senderId &&
                  message.seenAt != null,
            )
            .map((message) => message.seenAt!)
            .fold<DateTime?>(
              null,
              (latest, value) =>
                  latest == null || value.isAfter(latest) ? value : latest,
            );
        if (seenAt == null) {
          _pendingSeenThreadIds.remove(threadId);
          continue;
        }
        try {
          final iso = seenAt.toUtc().toIso8601String();
          await client
              .from('direct_messages')
              .update({'seen_at': iso, 'read_at': iso})
              .eq('sender_id', senderId)
              .eq('receiver_id', userId)
              .isFilter('seen_at', null);
          _pendingSeenThreadIds.remove(threadId);
        } catch (_) {
          failed = true;
        }
      }
      scheduleSave();
    } finally {
      _flushingRemote = false;
    }
    if (failed) _scheduleSyncRetry();
  }

  void _scheduleSyncRetry() {
    if (_syncRetry?.isActive ?? false) return;
    _syncRetry = Timer(const Duration(seconds: 5), () {
      final userId = _syncedUserId;
      if (userId != null) unawaited(startDirectMessageSync(userId));
    });
  }

  void _removeLegacyAdminDirectData() {
    bool isLegacyAdminDm(String threadId) {
      final participants = dmParticipants(threadId);
      return participants.any(isAdminAccountId);
    }

    _directThreadIds.removeWhere(isLegacyAdminDm);
    _messages.removeWhere((message) => isLegacyAdminDm(message.threadId));
    for (final reads in _lastRead.values) {
      reads.removeWhere((threadId, _) => isLegacyAdminDm(threadId));
    }
    _dmSeededUserIds.removeWhere(isAdminAccountId);
  }

  /// Seeds this user's demo DM threads once (works for any student, including
  /// fresh signups) and baselines their club-room read state so the first
  /// login badge only counts the DM messages. Idempotent; skips admins.
  void ensureSeededFor(String userId) {
    if (_box == null || userId.isEmpty) return;
    if (isAdminAccountId(userId)) return;
    if (_dmSeededUserIds.contains(userId)) return;

    final partners = [
      'u1',
      'u4',
      'u8',
      'u13',
    ].where((id) => id != userId).take(2).toList();
    final now = DateTime.now();
    for (var p = 0; p < partners.length; p++) {
      final partner = partners[p];
      final threadId = dmThreadId(userId, partner);
      _directThreadIds.add(threadId);
      final script = _dmSeedScripts[p % _dmSeedScripts.length];
      for (var i = 0; i < script.length; i++) {
        final fromPartner = script[i].$1;
        _messages.add(
          ChatMessage(
            id: 'seed_dm_${userId}_${partner}_$i',
            threadId: threadId,
            senderId: fromPartner ? partner : userId,
            content: script[i].$2,
            createdAt: now.subtract(
              Duration(hours: 26 * (p + 1), minutes: -14 * i),
            ),
          ),
        );
      }
    }

    // Club seed history predates this login: mark it read so the badge
    // starts at just the unread DMs.
    final reads = _lastRead.putIfAbsent(userId, () => {});
    for (final m in _messages) {
      if (isClubThread(m.threadId)) reads[m.threadId] = now;
    }

    _dmSeededUserIds.add(userId);
    scheduleSave();
    notifyListeners();
  }

  // ── Access rule ──────────────────────────────────────────────────────────────

  /// Single enforcement point for who may read/write a thread.
  ///
  /// DM threads: only the two participants. Club threads: the club's members
  /// (current session's [UserState.followedClubIds]) or the club-admin account
  /// that manages that club. The super admin has no chat access.
  bool canAccessThread(String threadId, String userId) {
    if (userId.isEmpty) return false;
    if (isAdminAccountId(userId)) {
      return managedCommunityThreadId(userId) == threadId;
    }
    if (isGroupThread(threadId)) {
      final group = groupForThread(threadId);
      return group != null &&
          group.memberIds.contains(userId) &&
          !group.memberIds.any(isAdminAccountId);
    }
    if (isDirectThread(threadId)) {
      final participants = dmParticipants(threadId);
      return participants.contains(userId) &&
          !participants.any(isAdminAccountId);
    }
    final clubId = clubIdOf(threadId);
    final club = clubId == null ? null : clubForId(clubId);
    if (club == null) return false;
    return userState.isFollowing(club.id);
  }

  /// Role lookup shared by every messaging entry point. UI visibility is not
  /// treated as authorization.
  static bool isAdminAccountId(String userId) =>
      userId == appAdmin.id || clubAdmins.any((a) => a.id == userId);

  /// The sole messaging destination for a club admin. Returns null for the
  /// super admin and for club admins without an assigned club.
  String? managedCommunityThreadId(String userId) {
    if (!isAdminAccountId(userId) || userId == appAdmin.id) return null;
    final club = managedClubForAdmin(userId);
    return club == null ? null : clubThreadId(club.id);
  }

  // ── Reads ────────────────────────────────────────────────────────────────────

  /// All threads [userId] can see: every DM thread they participate in plus
  /// one room per accessible club (even rooms with no messages yet). Sorted
  /// by last activity, newest first; empty club rooms last, alphabetically.
  List<ChatThreadSummary> threadsFor(String userId) {
    if (_box == null || userId.isEmpty) return const [];

    final byThread = <String, List<ChatMessage>>{};
    for (final m in _messages) {
      (byThread[m.threadId] ??= []).add(m);
    }

    final result = <ChatThreadSummary>[];
    if (isAdminAccountId(userId)) {
      final threadId = managedCommunityThreadId(userId);
      if (threadId == null || !canAccessThread(threadId, userId)) {
        return const [];
      }
      return [_summarize(threadId, userId, byThread[threadId] ?? const [])];
    }
    final directThreadIds = {
      ..._directThreadIds,
      ...byThread.keys.where(isDirectThread),
    };
    for (final threadId in directThreadIds) {
      if (!canAccessThread(threadId, userId)) continue;
      final peerId = dmPeerOf(threadId, userId);
      if (peerId == null) continue;
      result.add(_summarize(threadId, userId, byThread[threadId] ?? const []));
    }
    for (final group in _groups.values) {
      final threadId = group.threadId;
      if (!canAccessThread(threadId, userId)) continue;
      result.add(_summarize(threadId, userId, byThread[threadId] ?? const []));
    }
    for (final club in clubs) {
      final threadId = clubThreadId(club.id);
      if (!canAccessThread(threadId, userId)) continue;
      result.add(_summarize(threadId, userId, byThread[threadId] ?? const []));
    }

    result.sort((a, b) {
      final aLast = a.lastMessage;
      final bLast = b.lastMessage;
      if (aLast != null && bLast != null) {
        return bLast.createdAt.compareTo(aLast.createdAt);
      }
      if (aLast != null) return -1;
      if (bLast != null) return 1;
      return _threadSortName(a, userId).compareTo(_threadSortName(b, userId));
    });
    return result;
  }

  String _threadSortName(ChatThreadSummary t, String viewerId) {
    if (t.groupId != null) return groupDisplayName(t.threadId, viewerId);
    return t.clubId == null ? t.threadId : (clubForId(t.clubId!)?.name ?? '');
  }

  ChatThreadSummary _summarize(
    String threadId,
    String userId,
    List<ChatMessage> messages,
  ) {
    ChatMessage? last;
    for (final m in messages) {
      if (last == null || m.createdAt.isAfter(last.createdAt)) last = m;
    }
    return ChatThreadSummary(
      threadId: threadId,
      clubId: clubIdOf(threadId),
      groupId: groupIdOf(threadId),
      peerId: dmPeerOf(threadId, userId),
      lastMessage: last,
      unread: unreadCountFor(threadId, userId),
    );
  }

  /// Messages in [threadId], oldest first.
  List<ChatMessage> messagesFor(String threadId, {String? viewerId}) {
    if (_box == null) return const [];
    if (viewerId != null && !canAccessThread(threadId, viewerId)) {
      return const [];
    }
    final list = _messages.where((m) => m.threadId == threadId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(list);
  }

  int unreadCountFor(String threadId, String userId) {
    if (_box == null || userId.isEmpty) return 0;
    if (!canAccessThread(threadId, userId)) return 0;
    if (isDirectThread(threadId)) {
      return _messages.where((message) {
        return message.threadId == threadId &&
            message.senderId != userId &&
            message.seenAt == null;
      }).length;
    }
    final lastRead = _lastRead[userId]?[threadId];
    return _messages.where((m) {
      if (m.threadId != threadId || m.senderId == userId) return false;
      return lastRead == null || m.createdAt.isAfter(lastRead);
    }).length;
  }

  int totalUnreadFor(String userId) {
    if (_box == null || userId.isEmpty) return 0;
    var total = 0;
    for (final t in threadsFor(userId)) {
      total += t.unread;
    }
    return total;
  }

  // ── Writes ───────────────────────────────────────────────────────────────────

  /// Opens (or returns) the canonical DM thread for two distinct users.
  /// Registering the thread makes a brand-new conversation visible in the
  /// inbox before either participant sends the first message.
  String? ensureDirectThread(String currentUserId, String recipientId) {
    if (currentUserId.isEmpty ||
        recipientId.isEmpty ||
        currentUserId == recipientId ||
        isAdminAccountId(currentUserId) ||
        isAdminAccountId(recipientId)) {
      return null;
    }
    final threadId = dmThreadId(currentUserId, recipientId);
    if (_directThreadIds.add(threadId)) {
      if (_box != null) scheduleSave();
      notifyListeners();
    }
    return threadId;
  }

  /// Creates a student group. [recipientIds] intentionally excludes the
  /// creator; at least two recipients are required so DMs remain canonical.
  String? createGroupThread({
    required String creatorId,
    required Iterable<String> recipientIds,
    String? customName,
    String? photoPath,
  }) {
    if (creatorId.isEmpty || isAdminAccountId(creatorId)) return null;
    final recipients = recipientIds
        .where(
          (id) => id.isNotEmpty && id != creatorId && !isAdminAccountId(id),
        )
        .toSet()
        .toList(growable: false);
    if (recipients.length < 2) return null;

    final id = const Uuid().v4();
    final trimmedName = customName?.trim() ?? '';
    final trimmedPhoto = photoPath?.trim() ?? '';
    final group = ChatGroup(
      id: id,
      creatorId: creatorId,
      memberIds: [creatorId, ...recipients],
      customName: trimmedName.isEmpty ? null : trimmedName,
      photoUrl: trimmedPhoto.isEmpty ? null : trimmedPhoto,
      createdAt: DateTime.now(),
    );
    _groups[id] = group;
    _pendingRemoteGroupIds.add(id);
    if (_box != null) scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return group.threadId;
  }

  bool setGroupCustomName(String threadId, String? customName) {
    final group = groupForThread(threadId);
    if (group == null) return false;
    _groups[group.id] = group.withCustomName(customName);
    _pendingRemoteGroupIds.add(group.id);
    scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return true;
  }

  bool setGroupPhoto(String threadId, String? photoPath) {
    final group = groupForThread(threadId);
    if (group == null) return false;
    _groups[group.id] = group.withPhoto(photoPath);
    _pendingRemoteGroupIds.add(group.id);
    scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return true;
  }

  bool updateGroupMembers(String threadId, Iterable<String> memberIds) {
    final group = groupForThread(threadId);
    if (group == null) return false;
    final members = {
      group.creatorId,
      ...memberIds.where((id) => id.isNotEmpty && !isAdminAccountId(id)),
    };
    if (members.length < 2) return false;
    _groups[group.id] = group.withMembers(members);
    _pendingRemoteGroupIds.add(group.id);
    scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return true;
  }

  bool addGroupMembers(String threadId, Iterable<String> memberIds) {
    final group = groupForThread(threadId);
    if (group == null) return false;
    return updateGroupMembers(threadId, {...group.memberIds, ...memberIds});
  }

  bool removeGroupMember(String threadId, String memberId) {
    final group = groupForThread(threadId);
    if (group == null || memberId == group.creatorId) return false;
    return updateGroupMembers(
      threadId,
      group.memberIds.where((id) => id != memberId),
    );
  }

  /// Appends a message and returns it, or returns null (no mutation) when the
  /// content is empty or [senderId] has no access to the thread.
  ChatMessage? sendMessage({
    required String threadId,
    required String senderId,
    required String content,
  }) {
    if (_box == null) return null;
    final text = content.trim();
    if (text.isEmpty) return null;
    if (!canAccessThread(threadId, senderId)) return null;

    if (isDirectThread(threadId)) _directThreadIds.add(threadId);

    final now = DateTime.now();
    final message = ChatMessage(
      id: const Uuid().v4(),
      threadId: threadId,
      senderId: senderId,
      content: text,
      createdAt: now,
      deliveredAt: now,
    );
    _messages.add(message);
    if (isDirectThread(threadId)) {
      _pendingRemoteMessageIds.add(message.id);
    } else if (isGroupThread(threadId)) {
      _pendingRemoteGroupMessageIds.add(message.id);
    }
    scheduleSave();
    notifyListeners();
    if (isDirectThread(threadId) || isGroupThread(threadId)) {
      unawaited(_flushRemoteChanges());
    }
    _maybeScheduleAutoReply(message);
    if (isGroupThread(threadId)) _createGroupMessageNotifications(message);
    return message;
  }

  /// Records that [userId] has seen [threadId] up to now. Only saves and
  /// notifies when something was actually unread, so screens can safely call
  /// this from a [ChatStore] listener without causing a notify loop.
  void markThreadRead(String threadId, String userId) {
    if (_box == null || userId.isEmpty) return;
    if (!canAccessThread(threadId, userId)) return;
    final unread = unreadCountFor(threadId, userId);
    final now = DateTime.now();
    var markedSeen = false;
    if (isDirectThread(threadId)) {
      for (var i = 0; i < _messages.length; i++) {
        final message = _messages[i];
        if (message.threadId != threadId ||
            message.senderId == userId ||
            message.seenAt != null) {
          continue;
        }
        _messages[i] = message.copyWith(seenAt: now);
        markedSeen = true;
      }
      if (markedSeen) _pendingSeenThreadIds.add(threadId);
    }
    if (unread == 0 && !markedSeen) return;
    (_lastRead[userId] ??= {})[threadId] = now;
    scheduleSave();
    notifyListeners();
    if (markedSeen) unawaited(_flushRemoteChanges());
  }

  // ── Demo presence ────────────────────────────────────────────────────────────

  /// Deterministic mock presence — there is no backend, so a stable subset of
  /// users simply reads as "online" (same answer every call, every session).
  static bool isUserOnline(String userId) {
    if (userId.isEmpty) return false;
    var sum = 0;
    for (final unit in userId.codeUnits) {
      sum += unit;
    }
    return sum.isEven;
  }

  void _createGroupMessageNotifications(ChatMessage message) {
    final group = groupForThread(message.threadId);
    if (group == null) return;
    final senderName = _nameForUser(message.senderId);
    for (final recipientId in group.memberIds) {
      if (recipientId == message.senderId) continue;
      final groupName = group.displayName(
        viewerId: recipientId,
        nameForUser: _nameForUser,
      );
      userState.addNotification(
        AppNotification(
          id: 'group_msg_${message.id}_$recipientId',
          userId: recipientId,
          message: '$groupName: $senderName sent a message.',
          createdAt: message.createdAt,
          targetType: 'message',
          targetId: message.threadId,
          fromId: message.senderId,
        ),
      );
    }
  }

  // ── Demo auto-reply ──────────────────────────────────────────────────────────
  // Purely a demo nicety: a DM to a mock student gets one canned reply a few
  // seconds later so the conversation feels alive. Never fires in club rooms,
  // never replies to a reply (replies are inserted directly, not sent), and
  // at most one reply is pending per thread.

  /// Tests can switch this off to avoid stray timers mutating state.
  bool autoRepliesEnabled = true;

  final Set<String> _pendingAutoReplies = {};

  /// DM threads whose peer is "typing" right now — set while a demo
  /// auto-reply is pending so the thread and inbox can show the indicator.
  final Set<String> _typingThreadIds = {};

  bool isPeerTyping(String threadId) => _typingThreadIds.contains(threadId);

  static const _cannedReplies = [
    'Haha nice 😄',
    'Sounds good, see you there!',
    'Wait really? Tell me more later 👀',
    'Yesss let\'s do it',
    'On my way to the library, talk in a bit!',
  ];

  void _maybeScheduleAutoReply(ChatMessage sent) {
    if (!autoRepliesEnabled || !isDirectThread(sent.threadId)) return;
    final peerId = dmPeerOf(sent.threadId, sent.senderId);
    if (peerId == null || peerId == sent.senderId) return;
    final peerIdx = users.indexWhere((u) => u.id == peerId);
    if (peerIdx == -1) return; // only mock students reply
    final peer = users[peerIdx];
    if (!_pendingAutoReplies.add(sent.threadId)) return;

    final delay = Duration(
      milliseconds: 2200 + (sent.id.hashCode.abs() % 1800),
    );
    // Peer "starts typing" shortly after the send, until the reply lands.
    Timer(const Duration(milliseconds: 700), () {
      if (_box == null) return;
      if (!_pendingAutoReplies.contains(sent.threadId)) return;
      if (_typingThreadIds.add(sent.threadId)) notifyListeners();
    });
    Timer(delay, () {
      _pendingAutoReplies.remove(sent.threadId);
      final wasTyping = _typingThreadIds.remove(sent.threadId);
      if (_box == null) return;
      // Only reply if the original sender is still the logged-in user.
      final currentId =
          authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
      if (currentId != sent.senderId) {
        if (wasTyping) notifyListeners();
        return;
      }
      final now = DateTime.now();
      _messages.add(
        ChatMessage(
          id: 'm${now.microsecondsSinceEpoch}_$peerId',
          threadId: sent.threadId,
          senderId: peerId,
          content:
              _cannedReplies[sent.id.hashCode.abs() % _cannedReplies.length],
          createdAt: now,
        ),
      );
      scheduleSave();
      notifyListeners();
      userState.addNotification(
        AppNotification(
          id: 'msg_${peerId}_${now.millisecondsSinceEpoch}',
          userId: sent.senderId,
          message: '${peer.name} sent you a message.',
          createdAt: now,
          targetType: 'message',
          targetId: peerId,
          fromId: peerId,
        ),
      );
    });
  }

  // ── Persistence ──────────────────────────────────────────────────────────────

  Timer? _saveDebounce;

  void scheduleSave() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(seconds: 1), () {
      unawaited(saveAll());
    });
  }

  Future<void> saveAll() async {
    _saveDebounce?.cancel();
    _saveDebounce = null;
    final box = _box;
    if (box == null) return;
    await Future.wait([
      box.put('messages', _messages.map((m) => m.toMap()).toList()),
      box.put('lastRead', {
        for (final entry in _lastRead.entries)
          entry.key: {
            for (final inner in entry.value.entries)
              inner.key: inner.value.toIso8601String(),
          },
      }),
      box.put('dmSeededUserIds', _dmSeededUserIds.toList()),
      box.put('directThreadIds', _directThreadIds.toList()),
      box.put('groups', _groups.values.map((group) => group.toMap()).toList()),
      box.put('pendingRemoteMessageIds', _pendingRemoteMessageIds.toList()),
      box.put('pendingSeenThreadIds', _pendingSeenThreadIds.toList()),
      box.put('pendingRemoteGroupIds', _pendingRemoteGroupIds.toList()),
      box.put(
        'pendingRemoteGroupMessageIds',
        _pendingRemoteGroupMessageIds.toList(),
      ),
    ]);
  }

  // ── Seed content ─────────────────────────────────────────────────────────────

  /// Club-room history authored by real mock members of each club, so names
  /// and avatars resolve. User-agnostic: whoever follows these clubs sees it.
  void _seedClubHistory() {
    final now = DateTime.now();
    void seed(String clubId, List<(String, String, int)> script) {
      for (var i = 0; i < script.length; i++) {
        final (senderId, content, minutesAgo) = script[i];
        _messages.add(
          ChatMessage(
            id: 'seed_club_${clubId}_$i',
            threadId: clubThreadId(clubId),
            senderId: senderId,
            content: content,
            createdAt: now.subtract(Duration(minutes: minutesAgo)),
          ),
        );
      }
    }

    // c1 — Arkeoloji ve Sanat Tarihi (KUARHA): members u1 Alice, u6 Elif
    seed('c1', [
      ('u1', 'The Ephesus trip photos are up! Check the shared album 📸', 2860),
      (
        'u6',
        'They look amazing. Can we plan a museum visit for next month?',
        2790,
      ),
      ('u1', 'Yes! Thinking Pera Museum — who else is in?', 2740),
      ('u6', 'Count me in. I can ask about a student group discount.', 1500),
      ('u1', 'Perfect, let\'s finalize the date at Thursday\'s meeting.', 130),
    ]);
    // c4 — Bilgisayar Kulübü (KUACM): members u1, u2 Can, u5 Hakan, u15 Serkan
    seed('c4', [
      (
        'u2',
        'Hackathon team registrations close Friday — get your teams in!',
        2950,
      ),
      ('u5', 'Anyone need a backend person? I\'m free that weekend 🙋', 2900),
      ('u15', 'We do! DM me, we\'re two people short.', 2840),
      (
        'u1',
        'Workshop room booked for Wednesday 18:00, same as last time.',
        1420,
      ),
      (
        'u2',
        'Reminder: bring your laptops charged, sockets are limited 😅',
        260,
      ),
      ('u5', 'Noted. Also the Git basics slides are in the drive now.', 45),
    ]);
    // c5 — Dağcılık Kulübü (KUDAK): members u3 Emir, u11 Yunuscan, u15 Serkan
    seed('c5', [
      ('u3', 'Weather looks clear for the Uludağ hike this weekend 🏔️', 2810),
      ('u15', 'What time do we meet at the campus gate?', 2760),
      ('u3', '06:30 sharp — bus leaves at 06:45.', 2720),
      (
        'u11',
        'Bringing my camera this time, the sunrise spot is unreal.',
        1350,
      ),
    ]);
    // c7 — Ekonomi Kulübü: members u2 Can, u9 Ahmet, u15 Serkan
    seed('c7', [
      (
        'u9',
        'Case competition briefs are out — teams of 3, deadline in two weeks.',
        2880,
      ),
      ('u2', 'The guest speaker from the CBRT confirmed for the 24th 🎉', 1980),
      ('u15', 'Nice! Is it open seating or do we need to sign up?', 1930),
      (
        'u9',
        'Sign-up sheet goes live tomorrow, I\'ll post the link here.',
        310,
      ),
    ]);
    // c22 — KU Gönüllüleri: members u1, u5 Hakan, u11 Yunuscan, u13 Emre
    seed('c22', [
      (
        'u13',
        'This Saturday\'s tutoring session needs 2 more volunteers 🙏',
        2830,
      ),
      ('u5', 'I can come. Same school as last time?', 2770),
      ('u13', 'Yes, shuttle from west gate at 09:00.', 2730),
      (
        'u11',
        'I\'ll join too. Should we bring the art supplies left from the fair?',
        1210,
      ),
      ('u1', 'Good idea — they\'re in the club locker, code is with me.', 180),
    ]);
  }

  /// Two short DM scripts; `$1` = message is from the partner (vs. the
  /// current user), `$2` = text. Written to read naturally for any student.
  static const _dmSeedScripts = <List<(bool, String)>>[
    [
      (true, 'Heyy, are you going to the club fair tomorrow?'),
      (false, 'Thinking about it — what time does it start?'),
      (
        true,
        '11:00 by the main quad. Come, half the clubs are giving free stuff 😄',
      ),
      (true, 'Also I\'ll save you a spot at our stand if you want!'),
    ],
    [
      (true, 'Did you get the notes from today\'s lecture?'),
      (false, 'Yeah, I\'ll send them tonight.'),
      (true, 'You\'re a lifesaver 🙏 Coffee\'s on me this week.'),
    ],
  ];
}

final chatStore = ChatStore();

/// Lightweight view model for the inbox list; derived, never persisted.
class ChatThreadSummary {
  final String threadId;
  final String? clubId; // set for club rooms
  final String? groupId; // set for student-created groups
  final String? peerId; // set for DM threads
  final ChatMessage? lastMessage;
  final int unread;

  ChatThreadSummary({
    required this.threadId,
    required this.clubId,
    required this.groupId,
    required this.peerId,
    required this.lastMessage,
    required this.unread,
  });

  bool get isClub => clubId != null;
  bool get isGroup => groupId != null;
}
