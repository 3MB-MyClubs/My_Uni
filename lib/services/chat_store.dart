import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/chat_group.dart';
import '../models/chat_media_selection.dart';
import '../models/chat_message.dart';
import '../models/notification.dart';
import 'auth_service.dart';
import 'club_admin_access.dart';
import 'image_cache_service.dart';
import 'mock_data.dart';
import 'people_service.dart';
import 'supabase_config.dart';
import 'user_state.dart';

/// The two lanes of a club room, per the Club Board + Chat handoff: `board` is
/// the official notice area, `chat` is the room where the conversation lives.
enum ClubChatLane { board, chat }

/// Local-first messaging: 1:1 direct messages, student-created groups, plus
/// one members-only community chat per club.
///
/// Messages and per-user read state persist to Hive. Group membership and an
/// optional custom name are persisted too; an unnamed group's displayed name is
/// always derived from its current members at render time.
///
/// Like the other stores, every method no-ops / returns empty before
/// [initialize] so screens render safely in widget tests without Hive.
class ChatStore extends ChangeNotifier {
  static const _boxName = 'chat_v1';
  static const _chatAttachmentBucket = 'chat-attachments';
  static const _chatAttachmentReferencePrefix = 'chat-attachment://';
  static const _chatAttachmentSignedUrlLifetimeSeconds = 3600;
  static const _remoteMessageColumns = 'message_kind, payload, crypto_version';

  /// Removes the old scripted DMs, club messages, and empty demo threads from
  /// installs that opened the chat store before chats became real-data-only.
  static const int _mockChatRemovalVersion = 1;

  /// Removes direct-message data created before admin messaging was limited
  /// to the managed club community.
  static const int _adminMessagingMigrationVersion = 1;

  Box<dynamic>? _box;

  final List<ChatMessage> _messages = [];
  final Map<String, ({String url, DateTime expiresAt})>
  _signedChatAttachmentUrls = {};

  /// Local-first outbox. IDs remain here until Supabase acknowledges storage.
  final Set<String> _pendingRemoteMessageIds = {};

  /// DM/group threads with receipt changes waiting to reach Supabase.
  ///
  /// Group delivery and read rows intentionally reuse this durable queue so
  /// there is one retry mechanism for every student-chat receipt.
  final Set<String> _pendingSeenThreadIds = {};

  RealtimeChannel? _directMessageChannel;
  RealtimeChannel? _groupMessageChannel;
  RealtimeChannel? _clubMessageChannel;
  String? _syncedUserId;
  String? _clubSyncedActorId;
  Timer? _syncRetry;
  bool _flushingRemote = false;
  bool _flushRemoteAgain = false;

  /// Direct-message threads that have been opened, including conversations
  /// that do not have a first message yet.
  final Set<String> _directThreadIds = {};

  final Map<String, ChatGroup> _groups = {};
  final Set<String> _pendingRemoteGroupIds = {};
  final Set<String> _pendingRemoteGroupMessageIds = {};
  final Set<String> _pendingRemoteClubMessageIds = {};
  final Map<String, ClubInboxConversation> _clubInboxes = {};
  final Set<String> _pendingRemoteClubInboxMessageIds = {};

  /// Set when a photo remains in the local outbox because Storage or the
  /// following message-row insert failed. The active chat screen consumes this
  /// to show the user that the photo is queued locally and will be retried.
  bool _attachmentUploadFailed = false;

  /// Group id → user id for groups an admin deleted locally and still needs
  /// to delete from Supabase.
  final Map<String, String> _pendingRemoteGroupDeleteActorIds = {};

  /// Group id → user id for membership rows that a non-creator left locally
  /// and still needs to delete from Supabase.
  final Map<String, String> _pendingRemoteGroupLeaveUserIds = {};

  /// Message id → thread id for locally deleted messages awaiting remote
  /// deletion. Keeping this separate from the message outboxes prevents a
  /// failed delete from being resurrected by a later remote reconciliation.
  final Map<String, String> _pendingRemoteDeleteThreadIds = {};

  /// userId → threadId → last time that user opened the thread.
  final Map<String, Map<String, DateTime>> _lastRead = {};

  /// userId → `threadId|lane` → last time that user opened one lane of a club
  /// room. The Board + Chat design gives each segment its own count, so a
  /// reader who only opens the Board keeps the Chat count they left behind.
  final Map<String, Map<String, DateTime>> _lastReadLanes = {};

  bool takeAttachmentUploadFailure() {
    final failed = _attachmentUploadFailed;
    _attachmentUploadFailed = false;
    return failed;
  }

  void _recordAttachmentUploadFailure(
    ChatMessage message,
    Object error,
    StackTrace stackTrace,
  ) {
    if (message.kind != ChatMessageKind.photo) return;
    _attachmentUploadFailed = true;
    debugPrint('Chat photo upload failed for ${message.id}: $error');
    debugPrintStack(stackTrace: stackTrace);
    notifyListeners();
  }

  // ── Thread identity ──────────────────────────────────────────────────────────

  static String dmThreadId(String a, String b) {
    final pair = [a, b]..sort();
    return 'dm:${pair.join('|')}';
  }

  static String clubThreadId(String clubId) => 'club:$clubId';

  static String groupThreadId(String groupId) => 'group:$groupId';

  static String clubInboxThreadId(String inboxId) => 'clubdm:$inboxId';

  static bool isClubThread(String threadId) => threadId.startsWith('club:');

  static bool isDirectThread(String threadId) => threadId.startsWith('dm:');

  static bool isGroupThread(String threadId) => threadId.startsWith('group:');

  static bool isClubInboxThread(String threadId) =>
      threadId.startsWith('clubdm:');

  static String? _messageTableForThread(String threadId) {
    if (isDirectThread(threadId)) return 'direct_messages';
    if (isGroupThread(threadId)) return 'group_messages';
    if (isClubThread(threadId)) return 'club_channel_messages';
    if (isClubInboxThread(threadId)) return 'club_inbox_messages';
    return null;
  }

  /// The club id of a `club:` thread, or null for DM threads.
  static String? clubIdOf(String threadId) =>
      isClubThread(threadId) ? threadId.substring(5) : null;

  static String? groupIdOf(String threadId) =>
      isGroupThread(threadId) ? threadId.substring(6) : null;

  static String? clubInboxIdOf(String threadId) =>
      isClubInboxThread(threadId) ? threadId.substring(7) : null;

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

  ClubInboxConversation? clubInboxForThread(String threadId) {
    final inboxId = clubInboxIdOf(threadId);
    return inboxId == null ? null : _clubInboxes[inboxId];
  }

  List<String> groupParticipants(String threadId) =>
      groupForThread(threadId)?.memberIds ?? const [];

  String _nameForUser(String userId) {
    final cached = peopleService.cachedPeople.where(
      (user) => user.id == userId,
    );
    final known = users.where((user) => user.id == userId);
    final fallback = cached.isNotEmpty
        ? cached.first.name
        : (known.isNotEmpty ? known.first.name : '');
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
    final rawLastReadLanes = box.get('lastReadLanes');
    if (rawLastReadLanes is Map) {
      for (final entry in rawLastReadLanes.entries) {
        final inner = Map<String, dynamic>.from(entry.value as Map);
        _lastReadLanes[entry.key.toString()] = inner.map(
          (laneKey, iso) => MapEntry(laneKey, DateTime.parse(iso as String)),
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
    final rawPendingClubMessages = box.get('pendingRemoteClubMessageIds');
    if (rawPendingClubMessages is List) {
      _pendingRemoteClubMessageIds.addAll(
        rawPendingClubMessages.map((id) => id.toString()),
      );
    }
    final rawPendingClubInboxMessages = box.get(
      'pendingRemoteClubInboxMessageIds',
    );
    if (rawPendingClubInboxMessages is List) {
      _pendingRemoteClubInboxMessageIds.addAll(
        rawPendingClubInboxMessages.map((id) => id.toString()),
      );
    }
    final rawPendingRemoteDeletes = box.get('pendingRemoteDeleteThreadIds');
    if (rawPendingRemoteDeletes is Map) {
      for (final entry in rawPendingRemoteDeletes.entries) {
        final messageId = entry.key.toString();
        final threadId = entry.value.toString();
        if (messageId.isNotEmpty && threadId.isNotEmpty) {
          _pendingRemoteDeleteThreadIds[messageId] = threadId;
        }
      }
    }
    final rawPendingGroupLeaves = box.get('pendingRemoteGroupLeaveUserIds');
    if (rawPendingGroupLeaves is Map) {
      for (final entry in rawPendingGroupLeaves.entries) {
        final groupId = entry.key.toString();
        final userId = entry.value.toString();
        if (groupId.isNotEmpty && userId.isNotEmpty) {
          _pendingRemoteGroupLeaveUserIds[groupId] = userId;
        }
      }
    }
    final rawPendingGroupDeletes = box.get('pendingRemoteGroupDeleteActorIds');
    if (rawPendingGroupDeletes is Map) {
      for (final entry in rawPendingGroupDeletes.entries) {
        final groupId = entry.key.toString();
        final actorId = entry.value.toString();
        if (groupId.isNotEmpty && actorId.isNotEmpty) {
          _pendingRemoteGroupDeleteActorIds[groupId] = actorId;
        }
      }
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

    final storedMockRemovalVersion =
        box.get('mockChatRemovalVersion') as int? ?? 0;
    final removedMockChats = storedMockRemovalVersion < _mockChatRemovalVersion;
    if (removedMockChats) {
      _removeMockChatData();
      await Future.wait([
        box.put('mockChatRemovalVersion', _mockChatRemovalVersion),
        box.delete('dmSeededUserIds'),
        box.delete('seedVersion'),
      ]);
    }

    _box = box;
    if (removedMockChats || migratedAdminMessaging) {
      unawaited(saveAll());
    }
  }

  void _removeMockChatData() {
    final demoIdPattern = RegExp(r'^u\d+$');
    final demoUserIds = users
        .map((user) => user.id)
        .where(demoIdPattern.hasMatch)
        .toSet();
    final demoDirectThreads = _directThreadIds.where((threadId) {
      return dmParticipants(threadId).any(demoUserIds.contains);
    }).toSet();
    _messages.removeWhere(
      (message) =>
          message.id.startsWith('seed_dm_') ||
          message.id.startsWith('seed_club_') ||
          demoDirectThreads.contains(message.threadId),
    );

    final removedDirectThreads = _directThreadIds.where((threadId) {
      return !_messages.any((message) => message.threadId == threadId);
    }).toSet();
    _directThreadIds.removeAll(removedDirectThreads);
    _pendingSeenThreadIds.removeAll(removedDirectThreads);
    final retainedMessageIds = _messages.map((message) => message.id).toSet();
    _pendingRemoteMessageIds.retainAll(retainedMessageIds);
    _pendingRemoteGroupMessageIds.retainAll(retainedMessageIds);
    _pendingRemoteDeleteThreadIds.removeWhere(
      (_, threadId) => removedDirectThreads.contains(threadId),
    );
    for (final reads in _lastRead.values) {
      for (final threadId in removedDirectThreads) {
        reads.remove(threadId);
      }
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
    if (_syncedUserId != userId) _signedChatAttachmentUrls.clear();
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
          callback: (payload) => unawaited(_handleDirectMessageChange(payload)),
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
          callback: (payload) => unawaited(_handleDirectMessageChange(payload)),
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
          callback: (payload) =>
              unawaited(_handleGroupMessageChange(payload, userId)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'group_message_receipts',
          callback: (payload) => unawaited(_handleGroupReceiptChange(payload)),
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

  /// Starts the follower-visible, board-written club channel stream. The
  /// authenticated Supabase ID may differ from [actorId] for club accounts,
  /// whose in-app sender identity is the managed club ID.
  Future<void> startClubMessageSync(String actorId) async {
    if (actorId.isEmpty) return;
    _clubSyncedActorId = actorId;
    final client = _client;
    final authId = client?.auth.currentUser?.id ?? '';
    if (client == null || authId.isEmpty) return;
    final existing = _clubMessageChannel;
    if (existing != null) await client.removeChannel(existing);
    final channel = client
        .channel('club-channel-messages:$authId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_channel_messages',
          callback: (payload) =>
              unawaited(_handleClubMessageChange(payload, actorId)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_channel_poll_votes',
          callback: (payload) => _handleClubPollVoteChange(payload, actorId),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_inbox_threads',
          callback: (_) =>
              unawaited(_reconcileRemoteClubInboxes(client, actorId)),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'club_inbox_messages',
          callback: (payload) =>
              unawaited(_handleClubInboxMessageChange(payload, actorId)),
        );
    _clubMessageChannel = channel;
    channel.subscribe((status, error) {
      if (status == RealtimeSubscribeStatus.subscribed) {
        unawaited(_flushClubMessages());
      } else if (status == RealtimeSubscribeStatus.channelError ||
          status == RealtimeSubscribeStatus.timedOut ||
          status == RealtimeSubscribeStatus.closed) {
        if (identical(_clubMessageChannel, channel)) {
          _clubMessageChannel = null;
        }
        _scheduleSyncRetry();
      }
    });
    await _reconcileRemoteClubMessages(client, actorId);
    await _reconcileRemoteClubInboxes(client, actorId);
  }

  Set<String> _accessibleClubIds(String actorId) {
    final managed = managedClubForAdmin(actorId);
    return <String>{
      ...userState.followedClubIds,
      if (managed != null) managed.id,
      for (final club in clubs)
        if (club.boardMemberIds.contains(actorId)) club.id,
    };
  }

  Future<void> _reconcileRemoteClubMessages(
    SupabaseClient client,
    String actorId,
  ) async {
    final clubIds = _accessibleClubIds(actorId).toList(growable: false);
    if (clubIds.isEmpty) return;
    try {
      final rows = await client
          .from('club_channel_messages')
          .select(
            'id, club_id, sender_auth_id, sender_profile_id, sender_club_id, content, created_at, $_remoteMessageColumns',
          )
          .inFilter('club_id', clubIds)
          .order('created_at');
      for (final raw in rows) {
        await _mergeRemoteClubMessage(
          Map<String, dynamic>.from(raw),
          actorId,
          notifyRecipient: false,
        );
      }
      await _reconcileRemoteClubPollVotes(client, rows, actorId);
      await _flushClubMessages();
    } catch (_) {
      _scheduleSyncRetry();
    }
  }

  Future<void> _handleClubMessageChange(
    PostgresChangePayload payload,
    String actorId,
  ) async {
    final isDelete = payload.newRecord.isEmpty;
    final record = isDelete ? payload.oldRecord : payload.newRecord;
    if (record.isEmpty) return;
    if (isDelete) {
      _removeRemoteMessageLocally(record['id']?.toString() ?? '');
      return;
    }
    await _mergeRemoteClubMessage(record, actorId);
  }

  Future<void> _reconcileRemoteClubPollVotes(
    SupabaseClient client,
    List<dynamic> messageRows,
    String actorId,
  ) async {
    final pollMessageIds = messageRows
        .where((row) => row['message_kind']?.toString() == 'poll')
        .map((row) => row['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (pollMessageIds.isEmpty) return;
    final rows = await client
        .from('club_channel_poll_votes')
        .select('message_id, voter_auth_id, option_index')
        .inFilter('message_id', pollMessageIds);
    final votesByMessage = <String, Map<String, int>>{
      for (final id in pollMessageIds) id: <String, int>{},
    };
    final authId = client.auth.currentUser?.id ?? '';
    for (final raw in rows) {
      final row = Map<String, dynamic>.from(raw);
      final messageId = row['message_id']?.toString() ?? '';
      final voterAuthId = row['voter_auth_id']?.toString() ?? '';
      final optionIndex = row['option_index'];
      if (messageId.isEmpty || voterAuthId.isEmpty || optionIndex is! int) {
        continue;
      }
      final voterKey = voterAuthId == authId ? actorId : voterAuthId;
      votesByMessage[messageId]?[voterKey] = optionIndex;
    }
    var changed = false;
    for (final entry in votesByMessage.entries) {
      final index = _messages.indexWhere((message) => message.id == entry.key);
      if (index == -1 || mapEquals(_messages[index].pollVotes, entry.value)) {
        continue;
      }
      _messages[index] = _messages[index].copyWith(pollVotes: entry.value);
      changed = true;
    }
    if (changed) {
      scheduleSave();
      notifyListeners();
    }
  }

  void _handleClubPollVoteChange(
    PostgresChangePayload payload,
    String actorId,
  ) {
    final isDelete = payload.newRecord.isEmpty;
    final row = isDelete ? payload.oldRecord : payload.newRecord;
    final messageId = row['message_id']?.toString() ?? '';
    final voterAuthId = row['voter_auth_id']?.toString() ?? '';
    final optionIndex = row['option_index'];
    final authId = _client?.auth.currentUser?.id ?? '';
    if (messageId.isEmpty || voterAuthId.isEmpty) return;
    final voterKey = voterAuthId == authId ? actorId : voterAuthId;
    final message = messageById(messageId);
    if (message == null || message.kind != ChatMessageKind.poll) return;
    final votes = Map<String, int>.from(message.pollVotes);
    if (isDelete) {
      votes.remove(voterKey);
    } else if (optionIndex is int &&
        optionIndex >= 0 &&
        optionIndex < message.pollOptions.length) {
      votes[voterKey] = optionIndex;
    } else {
      return;
    }
    _replaceMessage(messageId, (current) => current.copyWith(pollVotes: votes));
  }

  Future<void> _mergeRemoteClubMessage(
    Map<String, dynamic> row,
    String actorId, {
    bool notifyRecipient = true,
  }) async {
    final id = row['id']?.toString() ?? '';
    final clubId = row['club_id']?.toString() ?? '';
    final senderId =
        row['sender_profile_id']?.toString().trim().isNotEmpty == true
        ? row['sender_profile_id'].toString()
        : row['sender_club_id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id.isEmpty || clubId.isEmpty || senderId.isEmpty || createdAt == null) {
      return;
    }
    if (_pendingRemoteDeleteThreadIds.containsKey(id)) return;
    final message = await _messageFromRemotePayload(
      row: row,
      id: id,
      threadId: clubThreadId(clubId),
      senderId: senderId,
      createdAt: createdAt,
      deliveredAt: createdAt,
    );
    if (message == null) return;
    final existingIndex = _messages.indexWhere(
      (candidate) => candidate.id == id,
    );
    if (existingIndex != -1) {
      if (_messages[existingIndex].attachmentPath != message.attachmentPath) {
        _messages[existingIndex] = _messages[existingIndex].copyWith(
          attachmentPath: message.attachmentPath,
        );
        scheduleSave();
        notifyListeners();
      }
      _pendingRemoteClubMessageIds.remove(id);
      return;
    }
    _messages.add(message);
    _pendingRemoteClubMessageIds.remove(id);
    if (notifyRecipient && senderId != actorId) {
      final clubName = clubForId(clubId)?.name ?? '';
      userState.addNotification(
        AppNotification(
          id: 'remote_club_msg_${message.id}_$actorId',
          userId: actorId,
          message: '$clubName sent a message.',
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

  /// Creates or returns the private inbox between one student and one club.
  /// The public follower channel remains read-only for that student.
  Future<String?> ensureClubInboxThread({
    required String profileId,
    required String clubId,
  }) async {
    final client = _client;
    if (client == null ||
        profileId.isEmpty ||
        clubId.isEmpty ||
        client.auth.currentUser?.id != profileId) {
      return null;
    }
    try {
      final row = await client
          .from('club_inbox_threads')
          .upsert(<String, dynamic>{
            'club_id': clubId,
            'profile_id': profileId,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }, onConflict: 'club_id,profile_id')
          .select('id, club_id, profile_id, created_at, updated_at')
          .single();
      final conversation = ClubInboxConversation.fromRemoteRow(row);
      _clubInboxes[conversation.id] = conversation;
      notifyListeners();
      await startClubMessageSync(profileId);
      return conversation.threadId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _reconcileRemoteClubInboxes(
    SupabaseClient client,
    String actorId,
  ) async {
    try {
      final rows = await client
          .from('club_inbox_threads')
          .select('id, club_id, profile_id, created_at, updated_at')
          .order('updated_at', ascending: false);
      final visibleIds = <String>{};
      for (final raw in rows) {
        final conversation = ClubInboxConversation.fromRemoteRow(
          Map<String, dynamic>.from(raw),
        );
        if (conversation.id.isEmpty) continue;
        visibleIds.add(conversation.id);
        _clubInboxes[conversation.id] = conversation;
      }
      _clubInboxes.removeWhere((id, _) => !visibleIds.contains(id));
      if (visibleIds.isEmpty) {
        notifyListeners();
        return;
      }
      final messages = await client
          .from('club_inbox_messages')
          .select(
            'id, thread_id, sender_auth_id, sender_profile_id, sender_club_id, content, created_at, delivered_at, seen_at, $_remoteMessageColumns',
          )
          .inFilter('thread_id', visibleIds.toList(growable: false))
          .order('created_at');
      for (final raw in messages) {
        await _mergeRemoteClubInboxMessage(
          Map<String, dynamic>.from(raw),
          actorId,
          notifyRecipient: false,
        );
      }
      notifyListeners();
      await _flushClubInboxMessages();
    } catch (_) {
      _scheduleSyncRetry();
    }
  }

  Future<void> _handleClubInboxMessageChange(
    PostgresChangePayload payload,
    String actorId,
  ) async {
    final isDelete = payload.newRecord.isEmpty;
    final record = isDelete ? payload.oldRecord : payload.newRecord;
    if (record.isEmpty) return;
    if (isDelete) {
      _removeRemoteMessageLocally(record['id']?.toString() ?? '');
      return;
    }
    await _mergeRemoteClubInboxMessage(record, actorId);
  }

  Future<void> _mergeRemoteClubInboxMessage(
    Map<String, dynamic> row,
    String actorId, {
    bool notifyRecipient = true,
  }) async {
    final id = row['id']?.toString() ?? '';
    final inboxId = row['thread_id']?.toString() ?? '';
    final senderId =
        row['sender_profile_id']?.toString().trim().isNotEmpty == true
        ? row['sender_profile_id'].toString()
        : row['sender_club_id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    final deliveredAt =
        DateTime.tryParse(row['delivered_at']?.toString() ?? '') ?? createdAt;
    final seenAt = DateTime.tryParse(row['seen_at']?.toString() ?? '');
    if (id.isEmpty ||
        inboxId.isEmpty ||
        senderId.isEmpty ||
        createdAt == null ||
        deliveredAt == null ||
        _clubInboxes[inboxId] == null) {
      return;
    }
    if (_pendingRemoteDeleteThreadIds.containsKey(id)) return;
    final message = await _messageFromRemotePayload(
      row: row,
      id: id,
      threadId: clubInboxThreadId(inboxId),
      senderId: senderId,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      seenAt: seenAt,
    );
    if (message == null) return;
    final existingIndex = _messages.indexWhere(
      (candidate) => candidate.id == id,
    );
    if (existingIndex != -1) {
      if (_messages[existingIndex].attachmentPath != message.attachmentPath) {
        _messages[existingIndex] = _messages[existingIndex].copyWith(
          attachmentPath: message.attachmentPath,
        );
        scheduleSave();
        notifyListeners();
      }
      _pendingRemoteClubInboxMessageIds.remove(id);
      return;
    }
    _messages.add(message);
    _pendingRemoteClubInboxMessageIds.remove(id);
    if (notifyRecipient && senderId != actorId) {
      final conversation = _clubInboxes[inboxId]!;
      final title = senderId == conversation.clubId
          ? clubForId(conversation.clubId)?.name ?? ''
          : _nameForUser(senderId);
      userState.addNotification(
        AppNotification(
          id: 'remote_club_inbox_${message.id}_$actorId',
          userId: actorId,
          message: '$title sent a message.',
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

  Future<void> _reconcileRemoteGroups(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final pendingLeaveGroupIds = _pendingRemoteGroupLeaveUserIds.entries
          .where((entry) => entry.value == userId)
          .map((entry) => entry.key)
          .toSet();
      final pendingDeleteGroupIds = _pendingRemoteGroupDeleteActorIds.entries
          .where((entry) => entry.value == userId)
          .map((entry) => entry.key)
          .toSet();
      final ownMembershipRows = await client
          .from('group_chat_members')
          .select('group_id')
          .eq('user_id', userId);
      final groupIds = ownMembershipRows
          .map((row) => row['group_id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .where((id) => !pendingLeaveGroupIds.contains(id))
          .where((id) => !pendingDeleteGroupIds.contains(id))
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
            .select(
              'id, creator_id, admin_ids, custom_name, photo_url, created_at',
            )
            .inFilter('id', groupIds),
        client
            .from('group_chat_members')
            .select('group_id, user_id, position, joined_at')
            .inFilter('group_id', groupIds)
            .order('position')
            .order('joined_at'),
        client
            .from('group_messages')
            .select(
              'id, group_id, sender_id, content, created_at, $_remoteMessageColumns',
            )
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
      final messageIds = results[2]
          .map((row) => row['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(growable: false);
      var receiptRows = <Map<String, dynamic>>[];
      if (messageIds.isNotEmpty) {
        try {
          final remoteReceipts = await client
              .from('group_message_receipts')
              .select('message_id, user_id, delivered_at, seen_at')
              .inFilter('message_id', messageIds);
          receiptRows = remoteReceipts
              .map((row) => Map<String, dynamic>.from(row))
              .toList(growable: false);
        } catch (_) {
          // Messages remain usable while a newly deployed receipts migration
          // is still propagating. The existing sync retry will fetch them.
        }
      }
      final receiptsByMessage = <String, List<MessageReceipt>>{};
      for (final row in receiptRows) {
        final messageId = row['message_id']?.toString() ?? '';
        final receipt = _receiptFromRemoteRow(row);
        if (messageId.isNotEmpty && receipt != null) {
          (receiptsByMessage[messageId] ??= []).add(receipt);
        }
      }
      // Do not expose a group message until its sender's real profile name and
      // avatar have been resolved. This also preloads identities used by the
      // automatic group title and avatar stack.
      await peopleService.hydrateProfilesByIds(
        <String>{
          ...membersByGroup.values.expand((memberIds) => memberIds),
          ...receiptRows.map((row) => row['user_id']?.toString() ?? ''),
        }.where((id) => id.isNotEmpty),
      );
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
        final rawAdminIds = row['admin_ids'];
        final adminIds = rawAdminIds is List
            ? rawAdminIds
                  .map((id) => id.toString())
                  .where((id) => id.isNotEmpty)
                  .toList(growable: false)
            : const <String>[];
        _groups[id] = ChatGroup(
          id: id,
          creatorId: row['creator_id']?.toString() ?? '',
          memberIds: membersByGroup[id] ?? const [],
          adminIds: adminIds,
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
        final row = Map<String, dynamic>.from(raw as Map);
        await _mergeRemoteGroupMessage(
          row,
          userId,
          receipts: receiptsByMessage[row['id']?.toString() ?? ''] ?? const [],
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

  Future<void> _mergeRemoteGroupMessage(
    Map<String, dynamic> row,
    String viewerId, {
    List<MessageReceipt> receipts = const [],
    bool notifyRecipient = true,
  }) async {
    final id = row['id']?.toString() ?? '';
    final groupId = row['group_id']?.toString() ?? '';
    final senderId = row['sender_id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id.isEmpty ||
        groupId.isEmpty ||
        senderId.isEmpty ||
        createdAt == null ||
        _groups[groupId] == null) {
      return;
    }
    if (_pendingRemoteDeleteThreadIds.containsKey(id)) return;
    final remoteMessage = await _messageFromRemotePayload(
      row: row,
      id: id,
      threadId: groupThreadId(groupId),
      senderId: senderId,
      createdAt: createdAt,
      deliveredAt: createdAt,
    );
    if (remoteMessage == null) return;
    final existingIndex = _messages.indexWhere(
      (candidate) => candidate.id == id,
    );
    final localReceipts = existingIndex == -1
        ? const <MessageReceipt>[]
        : _messages[existingIndex].receipts;
    var mergedReceipts = _mergeRemoteReceiptLists(localReceipts, receipts);
    var queuedDelivery = false;
    if (senderId != viewerId) {
      final viewerReceipt = _receiptFor(mergedReceipts, viewerId);
      if (viewerReceipt?.deliveredAt == null) {
        mergedReceipts = _withLocalReceipt(
          mergedReceipts,
          userId: viewerId,
          deliveredAt: DateTime.now(),
        );
        _pendingSeenThreadIds.add(groupThreadId(groupId));
        queuedDelivery = true;
      }
    }
    final message = remoteMessage.copyWith(receipts: mergedReceipts);
    if (existingIndex != -1) {
      final local = _messages[existingIndex];
      final pendingChanged = _pendingRemoteGroupMessageIds.remove(id);
      if (local.attachmentPath != message.attachmentPath ||
          !listEquals(local.receipts, mergedReceipts)) {
        _messages[existingIndex] = local.copyWith(
          attachmentPath: message.attachmentPath,
          receipts: mergedReceipts,
        );
      }
      if (local.attachmentPath != message.attachmentPath ||
          !listEquals(local.receipts, mergedReceipts) ||
          pendingChanged) {
        scheduleSave();
        notifyListeners();
      }
      if (queuedDelivery) unawaited(_flushRemoteChanges());
      return;
    }
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
    if (queuedDelivery) unawaited(_flushRemoteChanges());
  }

  static MessageReceipt? _receiptFromRemoteRow(Map<String, dynamic> row) {
    final userId = row['user_id']?.toString() ?? '';
    if (userId.isEmpty) return null;
    return MessageReceipt(
      userId: userId,
      deliveredAt: DateTime.tryParse(
        row['delivered_at']?.toString() ?? '',
      )?.toLocal(),
      seenAt: DateTime.tryParse(row['seen_at']?.toString() ?? '')?.toLocal(),
    );
  }

  static MessageReceipt? _receiptFor(
    Iterable<MessageReceipt> receipts,
    String userId,
  ) {
    for (final receipt in receipts) {
      if (receipt.userId == userId) return receipt;
    }
    return null;
  }

  static List<MessageReceipt> _mergeRemoteReceiptLists(
    Iterable<MessageReceipt> localReceipts,
    Iterable<MessageReceipt> remoteReceipts,
  ) {
    final merged = {
      for (final receipt in localReceipts) receipt.userId: receipt,
    };
    for (final remote in remoteReceipts) {
      final local = merged[remote.userId];
      // Realtime/reconciliation snapshots can race an optimistic offline
      // receipt. A null remote field must never erase a local timestamp.
      merged[remote.userId] = MessageReceipt(
        userId: remote.userId,
        deliveredAt: remote.deliveredAt ?? local?.deliveredAt,
        seenAt: remote.seenAt ?? local?.seenAt,
      );
    }
    return List.unmodifiable(merged.values);
  }

  static List<MessageReceipt> _withLocalReceipt(
    Iterable<MessageReceipt> receipts, {
    required String userId,
    DateTime? deliveredAt,
    DateTime? seenAt,
  }) {
    final merged = {for (final receipt in receipts) receipt.userId: receipt};
    final current = merged[userId];
    merged[userId] = MessageReceipt(
      userId: userId,
      deliveredAt: current?.deliveredAt ?? deliveredAt,
      seenAt: current?.seenAt ?? seenAt,
    );
    return List.unmodifiable(merged.values);
  }

  Future<void> _handleGroupReceiptChange(PostgresChangePayload payload) async {
    // Receipt rows cannot be deleted by clients. Ignore an unexpected delete
    // rather than rolling a locally known receipt backward.
    if (payload.newRecord.isEmpty) return;
    final row = payload.newRecord;
    final messageId = row['message_id']?.toString() ?? '';
    final receipt = _receiptFromRemoteRow(row);
    if (messageId.isEmpty || receipt == null) return;
    await peopleService.hydrateProfilesByIds([receipt.userId]);
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) return;
    final message = _messages[index];
    final merged = _mergeRemoteReceiptLists(message.receipts, [receipt]);
    if (listEquals(message.receipts, merged)) return;
    _messages[index] = message.copyWith(receipts: merged);
    scheduleSave();
    notifyListeners();
  }

  Future<void> _handleGroupMessageChange(
    PostgresChangePayload payload,
    String viewerId,
  ) async {
    final isDelete = payload.newRecord.isEmpty;
    final record = isDelete ? payload.oldRecord : payload.newRecord;
    if (record.isEmpty) return;
    if (isDelete) {
      _removeRemoteMessageLocally(record['id']?.toString() ?? '');
      return;
    }
    final senderId = record['sender_id']?.toString() ?? '';
    if (senderId.isNotEmpty) {
      await peopleService.hydrateProfilesByIds([senderId]);
    }
    await _mergeRemoteGroupMessage(record, viewerId);
  }

  Future<void> _reconcileRemoteMessages(
    SupabaseClient client,
    String userId,
  ) async {
    try {
      final rows = await client
          .from('direct_messages')
          .select(
            'id, sender_id, receiver_id, content, created_at, delivered_at, seen_at, read_at, $_remoteMessageColumns',
          )
          .or('sender_id.eq.$userId,receiver_id.eq.$userId')
          .order('created_at');
      await peopleService.hydrateProfilesByIds(
        rows.expand(
          (row) => [
            row['sender_id']?.toString() ?? '',
            row['receiver_id']?.toString() ?? '',
          ],
        ),
      );
      await _mergeRemoteRows(rows);
      await _flushRemoteChanges();
    } catch (_) {
      _scheduleSyncRetry();
    }
  }

  Future<void> _handleDirectMessageChange(PostgresChangePayload payload) async {
    final isDelete = payload.newRecord.isEmpty;
    final record = isDelete ? payload.oldRecord : payload.newRecord;
    if (record.isEmpty) return;
    if (isDelete) {
      _removeRemoteMessageLocally(record['id']?.toString() ?? '');
      return;
    }
    final message = await _messageFromRemoteRow(record);
    if (message == null) return;
    await peopleService.hydrateProfilesByIds([
      record['sender_id']?.toString() ?? '',
      record['receiver_id']?.toString() ?? '',
    ]);
    _mergeRemoteMessages([message]);
  }

  Future<void> _mergeRemoteRows(List<dynamic> rows) async {
    final messages = <ChatMessage>[];
    for (final raw in rows) {
      final message = await _messageFromRemoteRow(
        Map<String, dynamic>.from(raw as Map),
      );
      if (message != null) messages.add(message);
    }
    _mergeRemoteMessages(messages);
  }

  Future<ChatMessage?> _messageFromRemoteRow(Map<String, dynamic> row) async {
    final id = row['id']?.toString() ?? '';
    final senderId = row['sender_id']?.toString() ?? '';
    final receiverId = row['receiver_id']?.toString() ?? '';
    final createdAt = DateTime.tryParse(row['created_at']?.toString() ?? '');
    if (id.isEmpty ||
        senderId.isEmpty ||
        receiverId.isEmpty ||
        createdAt == null) {
      return null;
    }
    final deliveredAt =
        DateTime.tryParse(row['delivered_at']?.toString() ?? '') ?? createdAt;
    final seenAt = DateTime.tryParse(
      (row['seen_at'] ?? row['read_at'])?.toString() ?? '',
    );
    return _messageFromRemotePayload(
      row: row,
      id: id,
      threadId: dmThreadId(senderId, receiverId),
      senderId: senderId,
      createdAt: createdAt,
      deliveredAt: deliveredAt,
      seenAt: seenAt,
    );
  }

  Future<ChatMessage?> _messageFromRemotePayload({
    required Map<String, dynamic> row,
    required String id,
    required String threadId,
    required String senderId,
    required DateTime createdAt,
    required DateTime deliveredAt,
    DateTime? seenAt,
  }) async {
    // Rows written by the retired E2EE client are intentionally preserved in
    // Supabase, but their plaintext cannot be recovered without device keys.
    if (row['crypto_version'] != null) return null;
    final content = row['content']?.toString() ?? '';
    final rawPayload = row['payload'];
    final messageKind = row['message_kind']?.toString() ?? 'text';
    final hasStructuredPayload =
        rawPayload is Map && rawPayload.isNotEmpty && messageKind != 'text';
    if (content.isEmpty && !hasStructuredPayload) return null;

    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    payload
      ..['id'] = id
      ..['threadId'] = threadId
      ..['senderId'] = senderId
      ..['content'] = content
      ..['kind'] = messageKind == 'post_share' ? 'postShare' : messageKind
      ..['createdAt'] = createdAt.toLocal().toIso8601String()
      ..['deliveredAt'] = deliveredAt.toLocal().toIso8601String()
      ..['seenAt'] = seenAt?.toLocal().toIso8601String();
    final attachmentReference = payload['attachmentPath']?.toString() ?? '';
    if (attachmentReference.startsWith(_chatAttachmentReferencePrefix)) {
      final objectPath = attachmentReference.substring(
        _chatAttachmentReferencePrefix.length,
      );
      if (objectPath.isNotEmpty) {
        try {
          payload['attachmentPath'] = await _signedChatAttachmentUrl(
            objectPath,
          );
        } catch (_) {
          // Keep the reference so a later reconciliation can refresh it.
        }
      }
    }
    return ChatMessage.fromMap(payload);
  }

  Future<String> _signedChatAttachmentUrl(String objectPath) async {
    final client = _client;
    if (client == null) return objectPath;
    final now = DateTime.now();
    final cached = _signedChatAttachmentUrls[objectPath];
    if (cached != null &&
        cached.expiresAt.isAfter(now.add(const Duration(minutes: 1)))) {
      return cached.url;
    }
    final url = await client.storage
        .from(_chatAttachmentBucket)
        .createSignedUrl(objectPath, _chatAttachmentSignedUrlLifetimeSeconds);
    _signedChatAttachmentUrls[objectPath] = (
      url: url,
      expiresAt: now.add(
        const Duration(seconds: _chatAttachmentSignedUrlLifetimeSeconds),
      ),
    );
    return url;
  }

  void _removeRemoteMessageLocally(String messageId) {
    if (messageId.isEmpty) return;
    final index = _messages.indexWhere((message) => message.id == messageId);
    _pendingRemoteDeleteThreadIds.remove(messageId);
    if (index == -1) return;
    _messages.removeAt(index);
    scheduleSave();
    notifyListeners();
  }

  void _mergeRemoteMessages(Iterable<ChatMessage> remoteMessages) {
    var changed = false;
    for (final remote in remoteMessages) {
      if (_pendingRemoteDeleteThreadIds.containsKey(remote.id)) continue;
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
            local.kind != merged.kind ||
            local.title != merged.title ||
            local.replyToMessageId != merged.replyToMessageId ||
            local.replyToSenderId != merged.replyToSenderId ||
            local.replyToPreview != merged.replyToPreview ||
            local.sharedPostId != merged.sharedPostId ||
            local.attachmentPath != merged.attachmentPath ||
            local.attachmentName != merged.attachmentName ||
            local.attachmentSize != merged.attachmentSize ||
            !listEquals(local.pollOptions, merged.pollOptions) ||
            local.deliveredAt != merged.deliveredAt ||
            local.seenAt != merged.seenAt) {
          _messages[index] = merged;
          changed = true;
        }
      }
      _directThreadIds.add(remote.threadId);
      if (_pendingRemoteMessageIds.remove(remote.id)) changed = true;
    }
    if (!changed) return;
    scheduleSave();
    notifyListeners();
  }

  Future<void> _flushRemoteDeletes() async {
    final client = _client;
    if (client == null || client.auth.currentUser == null) return;
    var failed = false;
    for (final entry in _pendingRemoteDeleteThreadIds.entries.toList()) {
      final table = _messageTableForThread(entry.value);
      if (table == null) {
        _pendingRemoteDeleteThreadIds.remove(entry.key);
        continue;
      }
      try {
        await client.from(table).delete().eq('id', entry.key);
        _pendingRemoteDeleteThreadIds.remove(entry.key);
      } catch (_) {
        failed = true;
      }
    }
    scheduleSave();
    if (failed) _scheduleSyncRetry();
  }

  Future<ChatMessage?> _prepareMessageForRemote(
    SupabaseClient client,
    ChatMessage message,
  ) async {
    final attachmentPath = message.attachmentPath?.trim() ?? '';
    final isPhoto = message.kind == ChatMessageKind.photo;
    final isVideo =
        message.kind == ChatMessageKind.file &&
        isVideoMediaPath(message.attachmentName ?? attachmentPath);
    if ((!isPhoto && !isVideo) || attachmentPath.isEmpty) {
      return message;
    }
    if (attachmentPath.startsWith(_chatAttachmentReferencePrefix)) {
      return message;
    }
    if (_isRemoteAttachmentUrl(attachmentPath)) {
      final objectPath = _chatAttachmentObjectPathFromUrl(attachmentPath);
      return objectPath == null
          ? message
          : message.copyWith(
              attachmentPath: '$_chatAttachmentReferencePrefix$objectPath',
            );
    }

    final file = File(attachmentPath);
    if (!await file.exists()) return null;
    final size = await file.length();
    final authUserId = client.auth.currentUser?.id ?? '';
    if (size <= 0 || size > maxChatMediaFileBytes || authUserId.isEmpty) {
      return null;
    }

    final extension = _attachmentExtension(
      message.attachmentName ?? attachmentPath,
    );
    // Storage RLS keys the first path segment to auth.uid(). Do not use the
    // in-app actor/profile id here: club accounts deliberately have a
    // different actor id from their Supabase auth id.
    final objectPath = '$authUserId/${message.id}.$extension';
    await client.storage
        .from(_chatAttachmentBucket)
        .upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _attachmentContentType(extension),
            cacheControl: '31536000',
          ),
        );

    // Keep the storage reference in the remote row. A signed URL requires
    // SELECT access to storage.objects, but the participant-based policy can
    // only see the attachment after the chat message row exists. Signing here
    // would therefore fail before the insert below gets a chance to run.
    // The remote hydration path creates a signed URL after the row is present.
    final remoteMessage = message.copyWith(
      attachmentPath: '$_chatAttachmentReferencePrefix$objectPath',
    );
    return remoteMessage;
  }

  static bool _isRemoteAttachmentUrl(String value) =>
      value.startsWith('http://') || value.startsWith('https://');

  static String? _chatAttachmentObjectPathFromUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final segments = uri.pathSegments;
    final bucketIndex = segments.lastIndexOf(_chatAttachmentBucket);
    if (bucketIndex == -1 || bucketIndex == segments.length - 1) return null;
    return segments.skip(bucketIndex + 1).map(Uri.decodeComponent).join('/');
  }

  static String _attachmentExtension(String value) {
    final lower = value.toLowerCase();
    for (final extension in [
      'jpg',
      'jpeg',
      'png',
      'webp',
      'gif',
      'heic',
      'heif',
      'mp4',
      'mov',
      'm4v',
      'avi',
      'webm',
      'mkv',
      '3gp',
    ]) {
      if (lower.endsWith('.$extension')) return extension;
    }
    return 'jpg';
  }

  static String _attachmentContentType(String extension) => switch (extension) {
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'heif' => 'image/heif',
    'mp4' => 'video/mp4',
    'mov' => 'video/quicktime',
    'm4v' => 'video/x-m4v',
    'avi' => 'video/x-msvideo',
    'webm' => 'video/webm',
    'mkv' => 'video/x-matroska',
    '3gp' => 'video/3gpp',
    _ => 'image/jpeg',
  };

  Future<void> _flushRemoteChanges() async {
    if (_flushingRemote) {
      // A receipt can advance from delivered to seen while the earlier value
      // is still being uploaded. Remember the overlapping request so the
      // durable queue is drained again after the active upload completes.
      _flushRemoteAgain = true;
      return;
    }
    final userId = _syncedUserId;
    final client = _client;
    if (userId == null ||
        client == null ||
        client.auth.currentUser?.id != userId) {
      return;
    }
    _flushingRemote = true;
    final pendingMessageCountBefore =
        _pendingRemoteMessageIds.length + _pendingRemoteGroupMessageIds.length;
    var failed = false;
    var removedLocalGroup = false;
    try {
      for (final entry in _pendingRemoteGroupDeleteActorIds.entries.toList()) {
        final groupId = entry.key;
        final actorId = entry.value;
        if (actorId != userId) continue;
        try {
          await client.from('group_chats').delete().eq('id', groupId);
          _pendingRemoteGroupDeleteActorIds.remove(groupId);
        } catch (_) {
          failed = true;
        }
      }

      for (final entry in _pendingRemoteGroupLeaveUserIds.entries.toList()) {
        final groupId = entry.key;
        final leaveUserId = entry.value;
        if (leaveUserId != userId) continue;
        try {
          await client
              .from('group_chat_members')
              .delete()
              .eq('group_id', groupId)
              .eq('user_id', leaveUserId);
          _pendingRemoteGroupLeaveUserIds.remove(groupId);
          final group = _groups.remove(groupId);
          if (group != null) {
            final threadId = group.threadId;
            _messages.removeWhere((message) => message.threadId == threadId);
            _lastRead[userId]?.remove(threadId);
            removedLocalGroup = true;
          }
        } catch (_) {
          failed = true;
        }
      }

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
            'admin_ids': {group.creatorId, ...group.adminIds}.toList(),
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
                      cacheControl: '31536000',
                    ),
                  );
              final publicUrl = versionedStorageUrl(
                client.storage
                    .from('group-chat-photos')
                    .getPublicUrl(objectPath),
              );
              final versionedUrl = publicUrl;
              await client
                  .from('group_chats')
                  .update({'photo_url': versionedUrl})
                  .eq('id', group.id);
              _groups[group.id] = group.withPhoto(versionedUrl);
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
          final remoteMessage = await _prepareMessageForRemote(client, message);
          if (remoteMessage == null) {
            _recordAttachmentUploadFailure(
              message,
              StateError('The local chat photo is no longer available.'),
              StackTrace.current,
            );
            failed = true;
            continue;
          }
          await client.from('group_messages').insert({
            'id': remoteMessage.id,
            'group_id': groupId,
            'sender_id': userId,
            'content': remoteMessage.content,
            'message_kind': _databaseKind(remoteMessage.kind),
            'payload': _remotePayload(remoteMessage),
            'created_at': remoteMessage.createdAt.toUtc().toIso8601String(),
          });
          _pendingRemoteGroupMessageIds.remove(remoteMessage.id);
        } on PostgrestException catch (error, stackTrace) {
          if (error.code == '23505') {
            _pendingRemoteGroupMessageIds.remove(message.id);
          } else {
            _recordAttachmentUploadFailure(message, error, stackTrace);
            failed = true;
          }
        } catch (error, stackTrace) {
          _recordAttachmentUploadFailure(message, error, stackTrace);
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
          final remoteMessage = await _prepareMessageForRemote(client, message);
          if (remoteMessage == null) {
            _recordAttachmentUploadFailure(
              message,
              StateError('The local chat photo is no longer available.'),
              StackTrace.current,
            );
            failed = true;
            continue;
          }
          await client.from('direct_messages').insert({
            'id': remoteMessage.id,
            'sender_id': userId,
            'receiver_id': receiverId,
            'content': remoteMessage.content,
            'message_kind': _databaseKind(remoteMessage.kind),
            'payload': _remotePayload(remoteMessage),
            'created_at': remoteMessage.createdAt.toUtc().toIso8601String(),
            'delivered_at': remoteMessage.deliveredAt.toUtc().toIso8601String(),
          });
          _pendingRemoteMessageIds.remove(remoteMessage.id);
        } on PostgrestException catch (error, stackTrace) {
          if (error.code == '23505') {
            _pendingRemoteMessageIds.remove(message.id);
          } else {
            _recordAttachmentUploadFailure(message, error, stackTrace);
            failed = true;
          }
        } catch (error, stackTrace) {
          _recordAttachmentUploadFailure(message, error, stackTrace);
          failed = true;
        }
      }

      for (final threadId in _pendingSeenThreadIds.toList()) {
        // Claim this queue item before awaiting the network. If another local
        // receipt arrives for the same thread meanwhile, markThreadRead adds
        // it back and the newer value remains queued for the next drain.
        _pendingSeenThreadIds.remove(threadId);
        if (isGroupThread(threadId)) {
          final receiptMessages = _messages
              .where((message) {
                if (message.threadId != threadId ||
                    message.senderId == userId) {
                  return false;
                }
                return _receiptFor(message.receipts, userId)?.deliveredAt !=
                    null;
              })
              .toList(growable: false);
          if (receiptMessages.isEmpty) continue;
          try {
            await client.from('group_message_receipts').upsert([
              for (final message in receiptMessages)
                {
                  'message_id': message.id,
                  'user_id': userId,
                  'delivered_at': _receiptFor(
                    message.receipts,
                    userId,
                  )!.deliveredAt!.toUtc().toIso8601String(),
                },
            ], onConflict: 'message_id,user_id');
            for (final message in receiptMessages) {
              final seenAt = _receiptFor(message.receipts, userId)?.seenAt;
              if (seenAt == null) continue;
              await client
                  .from('group_message_receipts')
                  .update({'seen_at': seenAt.toUtc().toIso8601String()})
                  .eq('message_id', message.id)
                  .eq('user_id', userId);
            }
          } catch (_) {
            _pendingSeenThreadIds.add(threadId);
            failed = true;
          }
          continue;
        }
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
        if (seenAt == null) continue;
        try {
          final iso = seenAt.toUtc().toIso8601String();
          await client
              .from('direct_messages')
              .update({'seen_at': iso, 'read_at': iso})
              .eq('sender_id', senderId)
              .eq('receiver_id', userId)
              .isFilter('seen_at', null);
        } catch (_) {
          _pendingSeenThreadIds.add(threadId);
          failed = true;
        }
      }
      await _flushRemoteDeletes();
      scheduleSave();
      final pendingMessageCountAfter =
          _pendingRemoteMessageIds.length +
          _pendingRemoteGroupMessageIds.length;
      if (removedLocalGroup ||
          pendingMessageCountBefore != pendingMessageCountAfter) {
        notifyListeners();
      }
    } finally {
      _flushingRemote = false;
    }
    final flushAgain = _flushRemoteAgain;
    _flushRemoteAgain = false;
    if (failed) {
      _scheduleSyncRetry();
    } else if (flushAgain || _pendingSeenThreadIds.isNotEmpty) {
      unawaited(_flushRemoteChanges());
    }
  }

  Future<void> _flushClubMessages() async {
    final client = _client;
    final authId = client?.auth.currentUser?.id ?? '';
    final actorId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (client == null || authId.isEmpty || actorId.isEmpty) return;
    var failed = false;
    final pending = _messages
        .where((message) {
          return _pendingRemoteClubMessageIds.contains(message.id) &&
              message.senderId == actorId &&
              isClubThread(message.threadId);
        })
        .toList(growable: false);
    for (final message in pending) {
      final clubId = clubIdOf(message.threadId);
      if (clubId == null || !canWriteThread(message.threadId, actorId)) {
        continue;
      }
      try {
        final remoteMessage = await _prepareMessageForRemote(client, message);
        if (remoteMessage == null) {
          _recordAttachmentUploadFailure(
            message,
            StateError('The local chat photo is no longer available.'),
            StackTrace.current,
          );
          failed = true;
          continue;
        }
        await client.from('club_channel_messages').insert({
          'id': remoteMessage.id,
          'club_id': clubId,
          'sender_auth_id': authId,
          'sender_profile_id': authService.currentUser == null ? null : authId,
          'sender_club_id': authService.currentAdmin == null ? null : clubId,
          'message_kind': _databaseKind(remoteMessage.kind),
          'content': remoteMessage.content,
          'payload': _remotePayload(remoteMessage),
          'created_at': remoteMessage.createdAt.toUtc().toIso8601String(),
        });
        _pendingRemoteClubMessageIds.remove(remoteMessage.id);
      } on PostgrestException catch (error, stackTrace) {
        if (error.code == '23505') {
          _pendingRemoteClubMessageIds.remove(message.id);
        } else {
          _recordAttachmentUploadFailure(message, error, stackTrace);
          failed = true;
        }
      } catch (error, stackTrace) {
        _recordAttachmentUploadFailure(message, error, stackTrace);
        failed = true;
        // The local outbox retains the message and retries on the next sync.
      }
    }
    await _flushRemoteDeletes();
    scheduleSave();
    if (failed) _scheduleSyncRetry();
  }

  Future<void> _flushClubInboxMessages() async {
    final client = _client;
    final authId = client?.auth.currentUser?.id ?? '';
    final actorId =
        authService.currentUser?.id ?? authService.currentAdmin?.id ?? '';
    if (client == null || authId.isEmpty || actorId.isEmpty) return;
    var failed = false;
    final pending = _messages
        .where((message) {
          return _pendingRemoteClubInboxMessageIds.contains(message.id) &&
              message.senderId == actorId &&
              isClubInboxThread(message.threadId);
        })
        .toList(growable: false);
    for (final message in pending) {
      final conversation = clubInboxForThread(message.threadId);
      if (conversation == null || !canWriteThread(message.threadId, actorId)) {
        continue;
      }
      try {
        final remoteMessage = await _prepareMessageForRemote(client, message);
        if (remoteMessage == null) {
          _recordAttachmentUploadFailure(
            message,
            StateError('The local chat photo is no longer available.'),
            StackTrace.current,
          );
          failed = true;
          continue;
        }
        final sendingAsClub =
            authService.currentAdmin != null ||
            (clubForId(conversation.clubId)?.boardMemberIds.contains(actorId) ??
                false);
        await client.from('club_inbox_messages').insert({
          'id': remoteMessage.id,
          'thread_id': conversation.id,
          'sender_auth_id': authId,
          'sender_profile_id': sendingAsClub ? null : authId,
          'sender_club_id': sendingAsClub ? conversation.clubId : null,
          'message_kind': _databaseKind(remoteMessage.kind),
          'content': remoteMessage.content,
          'payload': _remotePayload(remoteMessage),
          'created_at': remoteMessage.createdAt.toUtc().toIso8601String(),
          'delivered_at': remoteMessage.deliveredAt.toUtc().toIso8601String(),
        });
        await client
            .from('club_inbox_threads')
            .update({'updated_at': DateTime.now().toUtc().toIso8601String()})
            .eq('id', conversation.id);
        _pendingRemoteClubInboxMessageIds.remove(remoteMessage.id);
      } on PostgrestException catch (error, stackTrace) {
        if (error.code == '23505') {
          _pendingRemoteClubInboxMessageIds.remove(message.id);
        } else {
          _recordAttachmentUploadFailure(message, error, stackTrace);
          failed = true;
        }
      } catch (error, stackTrace) {
        _recordAttachmentUploadFailure(message, error, stackTrace);
        failed = true;
        // Retained for retry.
      }
    }
    await _flushRemoteDeletes();
    scheduleSave();
    if (failed) _scheduleSyncRetry();
  }

  static String _databaseKind(ChatMessageKind kind) => switch (kind) {
    ChatMessageKind.postShare => 'post_share',
    _ => kind.name,
  };

  static Map<String, dynamic> _remotePayload(ChatMessage message) {
    final payload = message.toMap();
    payload.remove('id');
    payload.remove('threadId');
    payload.remove('senderId');
    payload.remove('content');
    payload.remove('createdAt');
    payload.remove('deliveredAt');
    payload.remove('seenAt');
    payload.remove('receipts');
    return payload;
  }

  void _scheduleSyncRetry() {
    if (_syncRetry?.isActive ?? false) return;
    _syncRetry = Timer(const Duration(seconds: 5), () {
      final userId = _syncedUserId;
      if (userId != null) unawaited(startDirectMessageSync(userId));
      final clubActorId = _clubSyncedActorId;
      if (clubActorId != null) {
        unawaited(startClubMessageSync(clubActorId));
      }
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
  }

  // ── Access rule ──────────────────────────────────────────────────────────────

  /// Single enforcement point for who may read/write a thread.
  ///
  /// DM threads: only the two participants. Club threads: the club's members
  /// (current session's [UserState.followedClubIds]) or the club-admin account
  /// that manages that club. The super admin has no chat access.
  bool canAccessThread(String threadId, String userId) {
    if (userId.isEmpty) return false;
    if (isClubInboxThread(threadId)) {
      final conversation = clubInboxForThread(threadId);
      final club = conversation == null ? null : clubForId(conversation.clubId);
      if (conversation == null || club == null) return false;
      return conversation.profileId == userId ||
          club.boardMemberIds.contains(userId) ||
          managedClubForAdmin(userId)?.id == conversation.clubId;
    }
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

  /// Returns whether [userId] authored [message]. Club accounts may be stored
  /// remotely under the managed club ID even though the local session uses a
  /// board/admin ID, so those identities are normalized here.
  bool isMessageOwner(ChatMessage message, String userId) {
    if (userId.isEmpty || message.senderId == userId) return userId.isNotEmpty;
    final clubId = isClubThread(message.threadId)
        ? clubIdOf(message.threadId)
        : isClubInboxThread(message.threadId)
        ? clubInboxForThread(message.threadId)?.clubId
        : null;
    if (clubId == null || message.senderId != clubId) return false;
    final club = clubForId(clubId);
    return (club?.boardMemberIds.contains(userId) ?? false) ||
        managedClubForAdmin(userId)?.id == clubId;
  }

  /// Reading and talking are the same right in every conversation: a club room
  /// is a room, so each of its members may post in the Chat lane. Publishing a
  /// notice on the Board lane is the narrower right — see [canPostNotice].
  bool canWriteThread(String threadId, String userId) =>
      canAccessThread(threadId, userId);

  /// Who may publish a notice on a club Board: members holding a role in that
  /// club (President / VP / Officers), its admin ids, and the linked club
  /// account. Members without a role never see a disabled composer — the Board
  /// offers them the route into Chat instead.
  bool canPostNotice(String threadId, String userId) {
    if (!isClubThread(threadId) || !canAccessThread(threadId, userId)) {
      return false;
    }
    final clubId = clubIdOf(threadId);
    final club = clubId == null ? null : clubForId(clubId);
    if (club == null) return false;
    return club.boardMemberIds.contains(userId) ||
        club.adminUserIds.contains(userId) ||
        managedCommunityThreadId(userId) == threadId;
  }

  /// Role lookup shared by every messaging entry point. UI visibility is not
  /// treated as authorization.
  static bool isAdminAccountId(String userId) {
    if (userId.isEmpty) return false;

    // Supabase club sessions use the linked club id as their in-app admin id,
    // so production admins are not necessarily present in the local demo
    // [clubAdmins] list. Include the authenticated admin session here so the
    // same own-community-only rule applies to both real and mock accounts.
    return userId == authService.currentAdmin?.id ||
        userId == appAdmin.id ||
        clubAdmins.any((admin) => admin.id == userId);
  }

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
      result.add(_summarize(threadId, userId, byThread[threadId] ?? const []));
      _addClubInboxSummaries(result, userId, byThread);
      return _sortThreadSummaries(result, userId);
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
    _addClubInboxSummaries(result, userId, byThread);
    return _sortThreadSummaries(result, userId);
  }

  void _addClubInboxSummaries(
    List<ChatThreadSummary> result,
    String userId,
    Map<String, List<ChatMessage>> byThread,
  ) {
    for (final conversation in _clubInboxes.values) {
      final threadId = conversation.threadId;
      if (!canAccessThread(threadId, userId)) continue;
      result.add(
        _summarize(
          threadId,
          userId,
          byThread[threadId] ?? const [],
          clubId: conversation.clubId,
          clubInboxId: conversation.id,
          peerId: conversation.profileId == userId
              ? null
              : conversation.profileId,
        ),
      );
    }
  }

  List<ChatThreadSummary> _sortThreadSummaries(
    List<ChatThreadSummary> result,
    String userId,
  ) {
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
    List<ChatMessage> messages, {
    String? clubId,
    String? clubInboxId,
    String? peerId,
  }) {
    ChatMessage? last;
    for (final m in messages) {
      if (last == null || m.createdAt.isAfter(last.createdAt)) last = m;
    }
    return ChatThreadSummary(
      threadId: threadId,
      clubId: clubId ?? clubIdOf(threadId),
      clubInboxId: clubInboxId,
      groupId: groupIdOf(threadId),
      peerId: peerId ?? dmPeerOf(threadId, userId),
      lastMessage: last,
      // [messages] is already this thread's bucket, so hand it over instead of
      // letting unreadCountFor rescan every message in the store again — that
      // rescan made threadsFor (and the nav badge behind it) quadratic.
      unread: unreadCountFor(threadId, userId, within: messages),
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

  /// Pass [within] when the caller already holds exactly this thread's
  /// messages; otherwise the whole store is scanned to find them.
  int unreadCountFor(
    String threadId,
    String userId, {
    Iterable<ChatMessage>? within,
  }) {
    if (_box == null || userId.isEmpty) return 0;
    if (!canAccessThread(threadId, userId)) return 0;
    final candidates = within ?? _messages.where((m) => m.threadId == threadId);
    if (isDirectThread(threadId)) {
      return candidates
          .where((m) => m.senderId != userId && m.seenAt == null)
          .length;
    }
    // A club room carries two counts, one per segment; the inbox row shows the
    // sum, so the two lanes are added here rather than measured separately.
    if (isClubThread(threadId)) {
      return _unreadInLane(
            threadId,
            userId,
            ClubChatLane.board,
            within: candidates,
          ) +
          _unreadInLane(
            threadId,
            userId,
            ClubChatLane.chat,
            within: candidates,
          );
    }
    final lastRead = _lastRead[userId]?[threadId];
    return candidates.where((m) {
      if (m.senderId == userId) return false;
      return lastRead == null || m.createdAt.isAfter(lastRead);
    }).length;
  }

  /// Unread notices on a club Board (`board`) or unread messages in its Chat
  /// lane (`chat`). Returns 0 for anything that is not a club room.
  int unreadInClubLane(String threadId, String userId, ClubChatLane lane) {
    if (_box == null || userId.isEmpty || !isClubThread(threadId)) return 0;
    if (!canAccessThread(threadId, userId)) return 0;
    return _unreadInLane(threadId, userId, lane);
  }

  int _unreadInLane(
    String threadId,
    String userId,
    ClubChatLane lane, {
    Iterable<ChatMessage>? within,
  }) => _unreadMessagesInLane(threadId, userId, lane, within: within).length;

  /// Ids of the messages still unread in one lane of a club room, oldest first.
  /// The screen snapshots these when it opens so the Board's dots and the Chat
  /// divider survive the lane being marked read a frame later.
  List<String> unreadIdsInClubLane(
    String threadId,
    String userId,
    ClubChatLane lane,
  ) {
    if (_box == null || userId.isEmpty || !isClubThread(threadId)) {
      return const [];
    }
    if (!canAccessThread(threadId, userId)) return const [];
    final unread = _unreadMessagesInLane(threadId, userId, lane).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return unread.map((message) => message.id).toList(growable: false);
  }

  Iterable<ChatMessage> _unreadMessagesInLane(
    String threadId,
    String userId,
    ClubChatLane lane, {
    Iterable<ChatMessage>? within,
  }) {
    final cutoff = _laneCutoff(threadId, userId, lane);
    final candidates = within ?? _messages.where((m) => m.threadId == threadId);
    return candidates.where((message) {
      if (message.threadId != threadId) return false;
      if (message.senderId == userId) return false;
      if (laneOf(message) != lane) return false;
      return cutoff == null || message.createdAt.isAfter(cutoff);
    });
  }

  /// The last moment [userId] saw [lane] — whichever is later, the whole-thread
  /// receipt or this lane's own one. Marking the thread read (a notification
  /// tap, a legacy call site) therefore still clears both lanes.
  DateTime? _laneCutoff(String threadId, String userId, ClubChatLane lane) {
    final thread = _lastRead[userId]?[threadId];
    final laneRead = _lastReadLanes[userId]?[_laneKey(threadId, lane)];
    if (thread == null) return laneRead;
    if (laneRead == null) return thread;
    return laneRead.isAfter(thread) ? laneRead : thread;
  }

  static String _laneKey(String threadId, ClubChatLane lane) =>
      '$threadId|${lane.name}';

  /// Which lane a club-room message belongs to: notices are the Board's own
  /// object, everything else — chat, polls, photos, system lines — is the room.
  static ClubChatLane laneOf(ChatMessage message) =>
      message.kind == ChatMessageKind.announcement
      ? ClubChatLane.board
      : ClubChatLane.chat;

  /// Notices on a club Board: pinned first ("Always here"), then newest first.
  List<ChatMessage> noticesIn(String threadId) {
    final list = announcementsIn(threadId).toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    return List.unmodifiable(list);
  }

  /// How many messages in the Chat lane quote [messageId] — the reply count a
  /// notice shows instead of a seen count.
  int replyCountFor(String messageId) {
    if (messageId.isEmpty) return 0;
    return _messages
        .where((message) => message.replyToMessageId == messageId)
        .length;
  }

  /// The newest message in a club room's Chat lane. The Messages inbox previews
  /// Chat, so a notice on the Board never becomes the row's preview line.
  ChatMessage? lastChatLaneMessageIn(String threadId) {
    ChatMessage? last;
    for (final message in _messages) {
      if (message.threadId != threadId) continue;
      if (laneOf(message) != ClubChatLane.chat) continue;
      if (last == null || message.createdAt.isAfter(last.createdAt)) {
        last = message;
      }
    }
    return last;
  }

  /// Records that [userId] has seen one lane of a club room. The other lane
  /// keeps its count, which is what gives the segments their own badges.
  void markClubLaneRead(String threadId, String userId, ClubChatLane lane) {
    if (_box == null || userId.isEmpty || !isClubThread(threadId)) return;
    if (!canAccessThread(threadId, userId)) return;
    if (_unreadInLane(threadId, userId, lane) == 0) return;
    (_lastReadLanes[userId] ??= {})[_laneKey(threadId, lane)] = DateTime.now();
    // Written straight through: a debounced save can be lost when the app is
    // closed right after the room is opened, which would resurrect the badge.
    unawaited(saveAll());
    notifyListeners();
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
      adminIds: [creatorId],
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

  bool _updateGroupMembers(
    String threadId,
    Iterable<String> memberIds, {
    int minimumMembers = 2,
    bool flushRemoteChanges = true,
  }) {
    final group = groupForThread(threadId);
    if (group == null) return false;
    final members = {
      group.creatorId,
      ...memberIds.where((id) => id.isNotEmpty && !isAdminAccountId(id)),
    };
    if (members.length < minimumMembers) return false;
    if (setEquals(group.memberIds.toSet(), members)) return false;
    _groups[group.id] = group.withMembers(members);
    _pendingRemoteGroupIds.add(group.id);
    scheduleSave();
    notifyListeners();
    if (flushRemoteChanges) unawaited(_flushRemoteChanges());
    return true;
  }

  bool addGroupMembers(
    String threadId,
    Iterable<String> memberIds, {
    required String actorId,
  }) {
    final group = groupForThread(threadId);
    if (group == null || !group.isAdmin(actorId)) return false;
    return _updateGroupMembers(threadId, {...group.memberIds, ...memberIds});
  }

  bool removeGroupMember(
    String threadId, {
    required String actorId,
    required String memberId,
  }) {
    final group = groupForThread(threadId);
    if (group == null ||
        !group.isAdmin(actorId) ||
        memberId == group.creatorId ||
        memberId == actorId) {
      return false;
    }
    return _updateGroupMembers(
      threadId,
      group.memberIds.where((id) => id != memberId),
    );
  }

  /// Lets a non-admin member leave a group without granting them the ability
  /// to remove anybody else. The creator remains the group owner and cannot
  /// leave, so every group always retains its creator.
  bool leaveGroup(String threadId, {required String userId}) {
    final group = groupForThread(threadId);
    if (group == null ||
        userId.isEmpty ||
        !group.memberIds.contains(userId) ||
        userId == group.creatorId ||
        group.isAdmin(userId)) {
      return false;
    }
    final changed = _updateGroupMembers(
      threadId,
      group.memberIds.where((id) => id != userId),
      minimumMembers: 1,
      flushRemoteChanges: false,
    );
    if (!changed) return false;
    _pendingRemoteGroupIds.remove(group.id);
    _pendingRemoteGroupLeaveUserIds[group.id] = userId;
    scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return true;
  }

  /// Deletes a group for every member. Only a group admin may do this; regular
  /// members must use [leaveGroup] instead.
  bool deleteGroup(String threadId, {required String actorId}) {
    final group = groupForThread(threadId);
    if (group == null || actorId.isEmpty || !group.isAdmin(actorId)) {
      return false;
    }
    final groupId = group.id;
    final groupThread = group.threadId;
    _groups.remove(groupId);
    _pendingRemoteGroupIds.remove(groupId);
    _pendingRemoteGroupLeaveUserIds.remove(groupId);
    _pendingRemoteGroupDeleteActorIds[groupId] = actorId;
    _messages.removeWhere((message) => message.threadId == groupThread);
    for (final reads in _lastRead.values) {
      reads.remove(groupThread);
    }
    scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return true;
  }

  bool setGroupMemberAdmin(
    String threadId, {
    required String actorId,
    required String memberId,
    required bool isAdmin,
  }) {
    final group = groupForThread(threadId);
    if (group == null ||
        !group.isAdmin(actorId) ||
        !group.memberIds.contains(memberId) ||
        memberId == group.creatorId ||
        memberId == actorId) {
      return false;
    }
    final admins = group.adminIds.toSet();
    final changed = isAdmin ? admins.add(memberId) : admins.remove(memberId);
    if (!changed) return false;
    _groups[group.id] = group.withAdmins(admins);
    _pendingRemoteGroupIds.add(group.id);
    scheduleSave();
    notifyListeners();
    unawaited(_flushRemoteChanges());
    return true;
  }

  /// Appends a message and returns it, or returns null (no mutation) when the
  /// content is empty or [senderId] has no access to the thread.
  ChatMessage? sendMessage({
    required String threadId,
    required String senderId,
    required String content,
    ChatMessageKind kind = ChatMessageKind.text,
    String? title,
    Iterable<String> mentions = const [],
    String? attachmentPath,
    String? attachmentName,
    int? attachmentSize,
    List<String> pollOptions = const [],
    DateTime? pollClosesAt,
    String? eventId,
    String? sharedPostId,
    bool pinned = false,
    String? replyToMessageId,
  }) {
    if (_box == null) return null;
    final text = content.trim();
    // Structured community messages (a poll, an event card, an attachment)
    // carry their payload outside `content`, so only plain text must be
    // non-empty.
    final carriesPayload =
        kind != ChatMessageKind.text &&
        (title != null ||
            attachmentPath != null ||
            eventId != null ||
            sharedPostId != null ||
            pollOptions.isNotEmpty);
    if (text.isEmpty && !carriesPayload) return null;
    if (!canWriteThread(threadId, senderId)) return null;
    // A notice — and the pin that goes with it — is the Board's own object, so
    // the narrower authority is enforced here and not only in the UI.
    if ((kind == ChatMessageKind.announcement || pinned) &&
        isClubThread(threadId) &&
        !canPostNotice(threadId, senderId)) {
      return null;
    }

    ChatMessage? repliedMessage;
    if (replyToMessageId != null) {
      final replyIndex = _messages.indexWhere(
        (message) =>
            message.id == replyToMessageId && message.threadId == threadId,
      );
      if (replyIndex == -1) return null;
      repliedMessage = _messages[replyIndex];
    }

    if (isDirectThread(threadId)) _directThreadIds.add(threadId);

    final now = DateTime.now();
    final message = ChatMessage(
      id: const Uuid().v4(),
      threadId: threadId,
      senderId: senderId,
      content: text,
      createdAt: now,
      deliveredAt: now,
      replyToMessageId: repliedMessage?.id,
      replyToSenderId: repliedMessage?.senderId,
      replyToPreview: repliedMessage == null
          ? null
          : replyPreviewFor(repliedMessage),
      kind: kind,
      title: title,
      mentions: mentions.where((id) => id.isNotEmpty).toSet().toList(),
      attachmentPath: attachmentPath,
      attachmentName: attachmentName,
      attachmentSize: attachmentSize,
      pollOptions: pollOptions,
      pollClosesAt: pollClosesAt,
      eventId: eventId,
      sharedPostId: sharedPostId,
      pinned: pinned,
    );
    if (pinned) _unpinAllIn(threadId);
    clearTyping(threadId, senderId);
    _messages.add(message);
    if (isDirectThread(threadId)) {
      _pendingRemoteMessageIds.add(message.id);
    } else if (isGroupThread(threadId)) {
      _pendingRemoteGroupMessageIds.add(message.id);
    } else if (isClubThread(threadId)) {
      _pendingRemoteClubMessageIds.add(message.id);
    } else if (isClubInboxThread(threadId)) {
      _pendingRemoteClubInboxMessageIds.add(message.id);
    }
    scheduleSave();
    notifyListeners();
    if (isDirectThread(threadId) || isGroupThread(threadId)) {
      // The composer can be used before the route's post-frame sync startup
      // has completed. Starting sync here guarantees the outbox gets a real
      // authenticated client instead of returning early with no upload.
      unawaited(startDirectMessageSync(senderId));
    } else if (isClubThread(threadId)) {
      unawaited(startClubMessageSync(senderId));
    } else if (isClubInboxThread(threadId)) {
      unawaited(startClubMessageSync(senderId));
    }
    if (isGroupThread(threadId)) _createGroupMessageNotifications(message);
    return message;
  }

  static String replyPreviewFor(ChatMessage message) {
    final content = message.content.trim();
    if (content.isNotEmpty) return content;
    final title = message.title?.trim() ?? '';
    if (title.isNotEmpty) return title;
    final attachmentName = message.attachmentName?.trim() ?? '';
    if (attachmentName.isNotEmpty) return attachmentName;
    return switch (message.kind) {
      ChatMessageKind.photo => 'Photo',
      ChatMessageKind.file => 'File',
      ChatMessageKind.poll => 'Poll',
      ChatMessageKind.event => 'Event',
      ChatMessageKind.postShare => 'Shared post',
      ChatMessageKind.announcement => 'Announcement',
      ChatMessageKind.system || ChatMessageKind.text => 'Message',
    };
  }

  // ── Community stream (announcements, polls, reactions, pins, typing) ─────────

  ChatMessage? messageById(String messageId) {
    final index = _messages.indexWhere((message) => message.id == messageId);
    return index == -1 ? null : _messages[index];
  }

  MessageDeliveryStatus deliveryStatusFor(ChatMessage message) {
    if (_pendingRemoteMessageIds.contains(message.id) ||
        _pendingRemoteGroupMessageIds.contains(message.id)) {
      return MessageDeliveryStatus.sent;
    }
    if (isGroupThread(message.threadId)) {
      return message.groupStatusForMembers(groupParticipants(message.threadId));
    }
    // Preserve the existing direct-message delivered/seen calculation.
    return message.status;
  }

  /// Removes one message locally and queues the same deletion for Supabase.
  /// Ownership is checked here as well as by the database policy so an
  /// optimistic UI action cannot remove somebody else's message.
  bool deleteMessage({required String messageId, required String userId}) {
    if (messageId.isEmpty || userId.isEmpty) return false;
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) return false;
    final message = _messages[index];
    if (!isMessageOwner(message, userId) ||
        !canAccessThread(message.threadId, userId)) {
      return false;
    }

    _messages.removeAt(index);
    _pendingRemoteDeleteThreadIds[message.id] = message.threadId;
    _pendingRemoteMessageIds.remove(message.id);
    _pendingRemoteGroupMessageIds.remove(message.id);
    _pendingRemoteClubMessageIds.remove(message.id);
    _pendingRemoteClubInboxMessageIds.remove(message.id);
    scheduleSave();
    notifyListeners();

    if (isDirectThread(message.threadId) || isGroupThread(message.threadId)) {
      unawaited(_flushRemoteChanges());
    } else if (isClubThread(message.threadId)) {
      unawaited(_flushClubMessages());
    } else if (isClubInboxThread(message.threadId)) {
      unawaited(_flushClubInboxMessages());
    }
    return true;
  }

  bool _replaceMessage(String messageId, ChatMessage Function(ChatMessage) f) {
    final index = _messages.indexWhere((message) => message.id == messageId);
    if (index == -1) return false;
    _messages[index] = f(_messages[index]);
    scheduleSave();
    notifyListeners();
    return true;
  }

  /// Adds or removes [emoji] for [userId] on one message.
  bool toggleReaction({
    required String messageId,
    required String userId,
    required String emoji,
  }) {
    if (userId.isEmpty || emoji.isEmpty) return false;
    final current = messageById(messageId);
    if (current == null) return false;
    if (!canAccessThread(current.threadId, userId)) return false;
    final reactions = {
      for (final entry in current.reactions.entries)
        entry.key: List<String>.from(entry.value),
    };
    final users = reactions.putIfAbsent(emoji, () => <String>[]);
    if (!users.remove(userId)) users.add(userId);
    if (users.isEmpty) reactions.remove(emoji);
    return _replaceMessage(
      messageId,
      (message) => message.copyWith(reactions: reactions),
    );
  }

  /// Casts (or retracts, when re-selecting the same option) a poll vote.
  bool votePoll({
    required String messageId,
    required String userId,
    required int optionIndex,
  }) {
    if (userId.isEmpty) return false;
    final current = messageById(messageId);
    if (current == null || current.kind != ChatMessageKind.poll) return false;
    if (!canAccessThread(current.threadId, userId)) return false;
    if (current.pollIsClosed) return false;
    if (optionIndex < 0 || optionIndex >= current.pollOptions.length) {
      return false;
    }
    final votes = Map<String, int>.from(current.pollVotes);
    final retracting = votes[userId] == optionIndex;
    if (retracting) {
      votes.remove(userId);
    } else {
      votes[userId] = optionIndex;
    }
    final changed = _replaceMessage(
      messageId,
      (message) => message.copyWith(pollVotes: votes),
    );
    if (changed && isClubThread(current.threadId)) {
      unawaited(
        _persistClubPollVote(
          messageId: messageId,
          optionIndex: retracting ? null : optionIndex,
        ),
      );
    }
    return changed;
  }

  Future<void> _persistClubPollVote({
    required String messageId,
    required int? optionIndex,
  }) async {
    final client = _client;
    final authId = client?.auth.currentUser?.id ?? '';
    if (client == null || authId.isEmpty) return;
    try {
      if (optionIndex == null) {
        await client
            .from('club_channel_poll_votes')
            .delete()
            .eq('message_id', messageId)
            .eq('voter_auth_id', authId);
      } else {
        await client.from('club_channel_poll_votes').upsert({
          'message_id': messageId,
          'voter_auth_id': authId,
          'option_index': optionIndex,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        }, onConflict: 'message_id,voter_auth_id');
      }
    } catch (_) {
      final actorId = _clubSyncedActorId;
      if (actorId != null) {
        await _reconcileRemoteClubMessages(client, actorId);
      }
    }
  }

  void _unpinAllIn(String threadId) {
    for (var i = 0; i < _messages.length; i++) {
      final message = _messages[i];
      if (message.threadId == threadId && message.pinned) {
        _messages[i] = message.copyWith(pinned: false);
      }
    }
  }

  /// Pins one message to the top of its thread; only one pin per thread.
  bool setPinned(String messageId, bool pinned) {
    final current = messageById(messageId);
    if (current == null || current.pinned == pinned) return false;
    if (pinned) _unpinAllIn(current.threadId);
    return _replaceMessage(
      messageId,
      (message) => message.copyWith(pinned: pinned),
    );
  }

  ChatMessage? pinnedMessageIn(String threadId) {
    for (final message in _messages.reversed) {
      if (message.threadId == threadId && message.pinned) return message;
    }
    return null;
  }

  /// Announcements in [threadId], newest first — the "Notices" archive.
  List<ChatMessage> announcementsIn(String threadId) {
    final list =
        _messages
            .where(
              (message) =>
                  message.threadId == threadId &&
                  message.kind == ChatMessageKind.announcement,
            )
            .toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(list);
  }

  /// How many people have opened the thread since [message] was posted — the
  /// "N seen" figure on an announcement. The author always counts.
  int seenCountFor(ChatMessage message) {
    var count = 1;
    // A club room is read one lane at a time, so a reader counts when either
    // their whole-thread receipt or the lane this message lives in is current.
    final laneKey = isClubThread(message.threadId)
        ? _laneKey(message.threadId, laneOf(message))
        : null;
    final readerIds = {..._lastRead.keys, ..._lastReadLanes.keys};
    for (final readerId in readerIds) {
      if (readerId == message.senderId) continue;
      final thread = _lastRead[readerId]?[message.threadId];
      final lane = laneKey == null ? null : _lastReadLanes[readerId]?[laneKey];
      final seen =
          (thread != null && !thread.isBefore(message.createdAt)) ||
          (lane != null && !lane.isBefore(message.createdAt));
      if (seen) count++;
    }
    return count;
  }

  // ── Typing ───────────────────────────────────────────────────────────────────

  /// threadId → userId → the moment their typing signal expires.
  final Map<String, Map<String, DateTime>> _typing = {};
  static const Duration _typingWindow = Duration(seconds: 5);
  Timer? _typingSweep;

  /// Marks [userId] as composing in [threadId]. The signal lapses on its own
  /// a few seconds later, so a dropped "stopped typing" never sticks.
  void setTyping(String threadId, String userId) {
    if (userId.isEmpty || !canAccessThread(threadId, userId)) return;
    final wasTyping = typingUserIds(threadId).contains(userId);
    (_typing[threadId] ??= {})[userId] = DateTime.now().add(_typingWindow);
    _typingSweep ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (_pruneTyping()) notifyListeners();
    });
    if (!wasTyping) notifyListeners();
  }

  void clearTyping(String threadId, String userId) {
    final removed = _typing[threadId]?.remove(userId) != null;
    if (_typing[threadId]?.isEmpty ?? false) _typing.remove(threadId);
    if (removed) notifyListeners();
  }

  bool _pruneTyping() {
    final now = DateTime.now();
    var changed = false;
    _typing.removeWhere((threadId, users) {
      users.removeWhere((userId, expiry) {
        final expired = expiry.isBefore(now);
        if (expired) changed = true;
        return expired;
      });
      return users.isEmpty;
    });
    if (_typing.isEmpty) {
      _typingSweep?.cancel();
      _typingSweep = null;
    }
    return changed;
  }

  List<String> typingUserIds(String threadId, {String? excluding}) {
    final now = DateTime.now();
    final users = _typing[threadId];
    if (users == null) return const [];
    return users.entries
        .where(
          (entry) => entry.value.isAfter(now) && entry.key != (excluding ?? ''),
        )
        .map((entry) => entry.key)
        .toList(growable: false);
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
    } else if (isGroupThread(threadId)) {
      for (var i = 0; i < _messages.length; i++) {
        final message = _messages[i];
        if (message.threadId != threadId || message.senderId == userId) {
          continue;
        }
        final receipt = _receiptFor(message.receipts, userId);
        if (receipt?.seenAt != null) continue;
        _messages[i] = message.copyWith(
          receipts: _withLocalReceipt(
            message.receipts,
            userId: userId,
            deliveredAt: receipt?.deliveredAt ?? now,
            seenAt: now,
          ),
        );
        markedSeen = true;
      }
      if (markedSeen) _pendingSeenThreadIds.add(threadId);
    }
    if (unread == 0 && !markedSeen) return;
    (_lastRead[userId] ??= {})[threadId] = now;
    // Persist the receipt immediately. A debounced write can be lost when the
    // app is closed right after the conversation is opened, which would make
    // this same chat appear unread on the next launch.
    unawaited(saveAll());
    notifyListeners();
    if (markedSeen) unawaited(_flushRemoteChanges());
  }

  // ── Demo presence ────────────────────────────────────────────────────────────

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
      box.put('lastReadLanes', {
        for (final entry in _lastReadLanes.entries)
          entry.key: {
            for (final inner in entry.value.entries)
              inner.key: inner.value.toIso8601String(),
          },
      }),
      box.put('directThreadIds', _directThreadIds.toList()),
      box.put('groups', _groups.values.map((group) => group.toMap()).toList()),
      box.put('pendingRemoteMessageIds', _pendingRemoteMessageIds.toList()),
      box.put('pendingSeenThreadIds', _pendingSeenThreadIds.toList()),
      box.put('pendingRemoteGroupIds', _pendingRemoteGroupIds.toList()),
      box.put(
        'pendingRemoteGroupMessageIds',
        _pendingRemoteGroupMessageIds.toList(),
      ),
      box.put(
        'pendingRemoteClubMessageIds',
        _pendingRemoteClubMessageIds.toList(),
      ),
      box.put(
        'pendingRemoteClubInboxMessageIds',
        _pendingRemoteClubInboxMessageIds.toList(),
      ),
      box.put(
        'pendingRemoteDeleteThreadIds',
        Map<String, String>.from(_pendingRemoteDeleteThreadIds),
      ),
      box.put(
        'pendingRemoteGroupLeaveUserIds',
        Map<String, String>.from(_pendingRemoteGroupLeaveUserIds),
      ),
      box.put(
        'pendingRemoteGroupDeleteActorIds',
        Map<String, String>.from(_pendingRemoteGroupDeleteActorIds),
      ),
    ]);
  }

  // ── Seed content ─────────────────────────────────────────────────────────────
}

final chatStore = ChatStore();

/// Lightweight view model for the inbox list; derived, never persisted.
class ChatThreadSummary {
  final String threadId;
  final String? clubId; // set for club rooms
  final String? clubInboxId; // set for private student ↔ club inboxes
  final String? groupId; // set for student-created groups
  final String? peerId; // set for DM threads
  final ChatMessage? lastMessage;
  final int unread;

  ChatThreadSummary({
    required this.threadId,
    required this.clubId,
    this.clubInboxId,
    required this.groupId,
    required this.peerId,
    required this.lastMessage,
    required this.unread,
  });

  bool get isClub => clubId != null;
  bool get isClubInbox => clubInboxId != null;
  bool get isGroup => groupId != null;
}

/// A private support-style conversation between one student profile and one
/// club. Access is enforced remotely through authenticated RLS policies.
class ClubInboxConversation {
  const ClubInboxConversation({
    required this.id,
    required this.clubId,
    required this.profileId,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String clubId;
  final String profileId;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get threadId => ChatStore.clubInboxThreadId(id);

  factory ClubInboxConversation.fromRemoteRow(Map<String, dynamic> row) {
    final now = DateTime.now();
    return ClubInboxConversation(
      id: row['id']?.toString() ?? '',
      clubId: row['club_id']?.toString() ?? '',
      profileId: row['profile_id']?.toString() ?? '',
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '')?.toLocal() ??
          now,
      updatedAt:
          DateTime.tryParse(row['updated_at']?.toString() ?? '')?.toLocal() ??
          now,
    );
  }
}
