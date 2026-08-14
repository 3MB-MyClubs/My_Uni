import 'chat_message.dart';

class ChatHistoryCursorV2 {
  const ChatHistoryCursorV2({required this.createdAt, required this.id});

  final DateTime createdAt;
  final String id;

  factory ChatHistoryCursorV2.fromJson(Map<String, dynamic> json) =>
      ChatHistoryCursorV2(
        createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
        id: json['id'].toString(),
      );
}

class ChatSummaryCursorV2 {
  const ChatSummaryCursorV2({required this.activityAt, required this.threadId});

  final DateTime activityAt;
  final String threadId;

  factory ChatSummaryCursorV2.fromJson(Map<String, dynamic> json) =>
      ChatSummaryCursorV2(
        activityAt: DateTime.parse(json['activity_at'].toString()).toLocal(),
        threadId: json['thread_id'].toString(),
      );
}

class ChatProfileSummaryV2 {
  const ChatProfileSummaryV2({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String? avatarUrl;

  factory ChatProfileSummaryV2.fromJson(Map<String, dynamic> json) =>
      ChatProfileSummaryV2(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        avatarUrl:
            _nullableString(json['avatar_url']) ??
            _nullableString(json['logo_url']),
      );
}

class ChatGroupMemberV2 extends ChatProfileSummaryV2 {
  const ChatGroupMemberV2({
    required super.id,
    required super.name,
    super.avatarUrl,
    required this.position,
  });

  final int position;

  factory ChatGroupMemberV2.fromJson(Map<String, dynamic> json) =>
      ChatGroupMemberV2(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        avatarUrl: _nullableString(json['avatar_url']),
        position: _integer(json['position']),
      );
}

class ChatGroupSummaryV2 {
  const ChatGroupSummaryV2({
    required this.id,
    required this.creatorId,
    required this.adminIds,
    required this.members,
    required this.createdAt,
    this.customName,
    this.photoUrl,
  });

  final String id;
  final String creatorId;
  final List<String> adminIds;
  final List<ChatGroupMemberV2> members;
  final DateTime createdAt;
  final String? customName;
  final String? photoUrl;

  factory ChatGroupSummaryV2.fromJson(Map<String, dynamic> json) =>
      ChatGroupSummaryV2(
        id: json['id']?.toString() ?? '',
        creatorId: json['creator_id']?.toString() ?? '',
        adminIds: _list(json['admin_ids'])
            .map((value) => value.toString())
            .where((value) => value.isNotEmpty)
            .toList(growable: false),
        members: _mapList(
          json['members'],
        ).map(ChatGroupMemberV2.fromJson).toList(growable: false),
        createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
        customName: _nullableString(json['custom_name']),
        photoUrl: _nullableString(json['photo_url']),
      );
}

class ChatReadBoundaryV2 {
  const ChatReadBoundaryV2({required this.messageId, required this.createdAt});

  final String messageId;
  final DateTime createdAt;

  factory ChatReadBoundaryV2.fromJson(Map<String, dynamic> json) =>
      ChatReadBoundaryV2(
        messageId: json['id']?.toString() ?? '',
        createdAt: DateTime.parse(json['created_at'].toString()).toLocal(),
      );
}

class ChatWireMessageV2 {
  const ChatWireMessageV2(this.json);

  final Map<String, dynamic> json;

  String get id => json['id']?.toString() ?? '';
  String get threadId => json['thread_id']?.toString() ?? '';

  ChatMessage? toChatMessage() {
    if (json['crypto_version'] != null) return null;
    final id = this.id;
    final threadId = this.threadId;
    final senderProfileId = _nullableString(json['sender_profile_id']);
    final senderClubId = _nullableString(json['sender_club_id']);
    final senderId =
        _nullableString(json['sender_id']) ??
        senderProfileId ??
        senderClubId ??
        '';
    final createdAt = DateTime.tryParse(json['created_at']?.toString() ?? '');
    if (id.isEmpty ||
        threadId.isEmpty ||
        senderId.isEmpty ||
        createdAt == null) {
      return null;
    }
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    final kind = json['message_kind']?.toString() ?? 'text';
    final content = json['content']?.toString() ?? '';
    if (content.isEmpty && (kind == 'text' || payload.isEmpty)) return null;

    payload
      ..['id'] = id
      ..['threadId'] = threadId
      ..['senderId'] = senderId
      ..['content'] = content
      ..['kind'] = kind == 'post_share' ? 'postShare' : kind
      ..['createdAt'] = createdAt.toLocal().toIso8601String()
      ..['deliveredAt'] =
          (DateTime.tryParse(json['delivered_at']?.toString() ?? '') ??
                  createdAt)
              .toLocal()
              .toIso8601String()
      ..['seenAt'] = DateTime.tryParse(
        (json['seen_at'] ?? json['read_at'])?.toString() ?? '',
      )?.toLocal().toIso8601String();
    if (json['sender_auth_id'] != null) {
      payload['senderAuthId'] = json['sender_auth_id'].toString();
    }
    if (senderClubId != null) payload['senderClubId'] = senderClubId;
    if (json['poll_votes'] is Map) {
      payload['pollVotes'] = Map<String, dynamic>.from(
        json['poll_votes'] as Map,
      );
    }
    if (json['poll_totals'] is List) {
      payload['pollVoteCounts'] = (json['poll_totals'] as List)
          .whereType<num>()
          .map((value) => value.toInt())
          .toList(growable: false);
    }
    if (json['viewer_option_index'] is num) {
      payload['pollViewerOption'] = (json['viewer_option_index'] as num)
          .toInt();
    }
    final receipts = _mapList(json['receipts']);
    if (receipts.isNotEmpty) {
      payload['receipts'] = [
        for (final receipt in receipts)
          {
            'userId': receipt['user_id']?.toString() ?? '',
            'deliveredAt': receipt['delivered_at']?.toString(),
            'seenAt': receipt['seen_at']?.toString(),
          },
      ];
    }
    return ChatMessage.fromMap(payload);
  }
}

class ChatConversationSummaryV2 {
  const ChatConversationSummaryV2({
    required this.threadId,
    required this.threadType,
    required this.activityAt,
    required this.unreadCount,
    required this.syncCursor,
    this.unreadBoardCount,
    this.unreadChatCount,
    this.latestBoardBoundary,
    this.latestChatBoundary,
    this.peer,
    this.group,
    this.club,
    this.inboxProfile,
    this.latestMessage,
  });

  final String threadId;
  final String threadType;
  final DateTime activityAt;
  final int unreadCount;
  final int syncCursor;
  final int? unreadBoardCount;
  final int? unreadChatCount;
  final ChatReadBoundaryV2? latestBoardBoundary;
  final ChatReadBoundaryV2? latestChatBoundary;
  final ChatProfileSummaryV2? peer;
  final ChatGroupSummaryV2? group;
  final ChatProfileSummaryV2? club;
  final ChatProfileSummaryV2? inboxProfile;
  final ChatMessage? latestMessage;

  ChatConversationSummaryV2 copyWith({
    int? unreadCount,
    int? syncCursor,
    int? unreadBoardCount,
    int? unreadChatCount,
    ChatMessage? latestMessage,
    DateTime? activityAt,
  }) => ChatConversationSummaryV2(
    threadId: threadId,
    threadType: threadType,
    activityAt: activityAt ?? this.activityAt,
    unreadCount: unreadCount ?? this.unreadCount,
    syncCursor: syncCursor ?? this.syncCursor,
    unreadBoardCount: unreadBoardCount ?? this.unreadBoardCount,
    unreadChatCount: unreadChatCount ?? this.unreadChatCount,
    latestBoardBoundary: latestBoardBoundary,
    latestChatBoundary: latestChatBoundary,
    peer: peer,
    group: group,
    club: club,
    inboxProfile: inboxProfile,
    latestMessage: latestMessage ?? this.latestMessage,
  );

  factory ChatConversationSummaryV2.fromJson(Map<String, dynamic> json) {
    final latest = json['latest_message'];
    final readBoundaries = _map(json['read_boundaries']);
    final boardBoundary = readBoundaries['board'];
    final chatBoundary = readBoundaries['chat'];
    return ChatConversationSummaryV2(
      threadId: json['thread_id']?.toString() ?? '',
      threadType: json['thread_type']?.toString() ?? '',
      activityAt: DateTime.parse(json['activity_at'].toString()).toLocal(),
      unreadCount: _integer(json['unread_count']),
      syncCursor: _integer(json['sync_cursor']),
      unreadBoardCount: json['unread_board_count'] == null
          ? null
          : _integer(json['unread_board_count']),
      unreadChatCount: json['unread_chat_count'] == null
          ? null
          : _integer(json['unread_chat_count']),
      latestBoardBoundary: boardBoundary is Map
          ? ChatReadBoundaryV2.fromJson(_map(boardBoundary))
          : null,
      latestChatBoundary: chatBoundary is Map
          ? ChatReadBoundaryV2.fromJson(_map(chatBoundary))
          : null,
      peer: json['peer'] is Map
          ? ChatProfileSummaryV2.fromJson(_map(json['peer']))
          : null,
      group: json['group'] is Map
          ? ChatGroupSummaryV2.fromJson(_map(json['group']))
          : null,
      club: json['club'] is Map
          ? ChatProfileSummaryV2.fromJson(_map(json['club']))
          : null,
      inboxProfile: json['inbox_profile'] is Map
          ? ChatProfileSummaryV2.fromJson(_map(json['inbox_profile']))
          : null,
      latestMessage: latest is Map
          ? ChatWireMessageV2(_map(latest)).toChatMessage()
          : null,
    );
  }
}

class ChatSummaryPageV2 {
  const ChatSummaryPageV2({
    required this.items,
    required this.hasMore,
    required this.pageSize,
    this.nextCursor,
  });

  final List<ChatConversationSummaryV2> items;
  final bool hasMore;
  final int pageSize;
  final ChatSummaryCursorV2? nextCursor;

  factory ChatSummaryPageV2.fromJson(Map<String, dynamic> json) =>
      ChatSummaryPageV2(
        items: _mapList(
          json['items'],
        ).map(ChatConversationSummaryV2.fromJson).toList(growable: false),
        hasMore: json['has_more'] == true,
        pageSize: _integer(json['page_size'], fallback: 40),
        nextCursor: json['next_cursor'] is Map
            ? ChatSummaryCursorV2.fromJson(_map(json['next_cursor']))
            : null,
      );
}

class ChatMessagePageV2 {
  const ChatMessagePageV2({
    required this.threadId,
    required this.items,
    required this.hasMore,
    required this.pageSize,
    required this.syncCursor,
    this.nextCursor,
  });

  final String threadId;
  final List<ChatMessage> items;
  final bool hasMore;
  final int pageSize;
  final int syncCursor;
  final ChatHistoryCursorV2? nextCursor;
}

class ChatChangeV2 {
  const ChatChangeV2({
    required this.changeId,
    required this.recordType,
    required this.operation,
    required this.messageId,
    required this.record,
    this.message,
  });

  final int changeId;
  final String recordType;
  final String operation;
  final String messageId;
  final Map<String, dynamic> record;
  final ChatMessage? message;

  ChatChangeV2 copyWith({ChatMessage? message}) => ChatChangeV2(
    changeId: changeId,
    recordType: recordType,
    operation: operation,
    messageId: messageId,
    record: record,
    message: message ?? this.message,
  );

  factory ChatChangeV2.fromJson(Map<String, dynamic> json) => ChatChangeV2(
    changeId: _integer(json['change_id']),
    recordType: json['record_type']?.toString() ?? 'message',
    operation: json['operation']?.toString() ?? '',
    messageId: json['message_id']?.toString() ?? '',
    record: _map(json['record']),
  );
}

class ChatDeltaPageV2 {
  const ChatDeltaPageV2({
    required this.threadId,
    required this.changes,
    required this.hasMore,
    required this.nextChangeId,
    this.cursorExpired = false,
  });

  final String threadId;
  final List<ChatChangeV2> changes;
  final bool hasMore;
  final int nextChangeId;
  final bool cursorExpired;

  ChatDeltaPageV2 copyWith({List<ChatChangeV2>? changes}) => ChatDeltaPageV2(
    threadId: threadId,
    changes: changes ?? this.changes,
    hasMore: hasMore,
    nextChangeId: nextChangeId,
    cursorExpired: cursorExpired,
  );

  factory ChatDeltaPageV2.fromJson(Map<String, dynamic> json) =>
      ChatDeltaPageV2(
        threadId: json['thread_id']?.toString() ?? '',
        changes: _mapList(
          json['changes'],
        ).map(ChatChangeV2.fromJson).toList(growable: false),
        hasMore: json['has_more'] == true,
        nextChangeId: _integer(json['next_change_id']),
        cursorExpired: json['cursor_expired'] == true,
      );
}

Map<String, dynamic> _map(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> _mapList(Object? value) => _list(
  value,
).whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();

List<dynamic> _list(Object? value) => value is List ? value : const [];

int _integer(Object? value, {int fallback = 0}) => switch (value) {
  int number => number,
  num number => number.toInt(),
  _ => int.tryParse(value?.toString() ?? '') ?? fallback,
};

String? _nullableString(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
