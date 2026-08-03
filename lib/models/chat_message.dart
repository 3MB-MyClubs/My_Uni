enum MessageDeliveryStatus { sent, delivered, seen }

class MessageReceipt {
  final String userId;
  final DateTime? deliveredAt;
  final DateTime? seenAt;

  const MessageReceipt({required this.userId, this.deliveredAt, this.seenAt});

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'deliveredAt': deliveredAt?.toIso8601String(),
    'seenAt': seenAt?.toIso8601String(),
  };

  factory MessageReceipt.fromMap(Map<String, dynamic> map) => MessageReceipt(
    userId: map['userId']?.toString() ?? '',
    deliveredAt: DateTime.tryParse(map['deliveredAt']?.toString() ?? ''),
    seenAt: DateTime.tryParse(map['seenAt']?.toString() ?? ''),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageReceipt &&
          userId == other.userId &&
          deliveredAt == other.deliveredAt &&
          seenAt == other.seenAt;

  @override
  int get hashCode => Object.hash(userId, deliveredAt, seenAt);
}

/// What a message renders as in a community stream. Plain [text] is the
/// default and keeps every existing (direct / group) message unchanged.
enum ChatMessageKind {
  text,
  announcement,
  poll,
  event,
  postShare,
  photo,
  file,
  system,
}

ChatMessageKind _kindFromName(Object? raw) {
  final name = raw?.toString() ?? '';
  for (final kind in ChatMessageKind.values) {
    if (kind.name == name) return kind;
  }
  return ChatMessageKind.text;
}

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime deliveredAt;
  final DateTime? seenAt;
  final List<MessageReceipt> receipts;

  /// Stable snapshot of the message this one replies to. Keeping the sender
  /// and preview beside the id lets the quote remain useful if the original
  /// message is later deleted or is not present in the local cache yet.
  final String? replyToMessageId;
  final String? replyToSenderId;
  final String? replyToPreview;

  // ── Community extras ───────────────────────────────────────────────────────
  // All optional and defaulted, so messages stored before these existed (and
  // messages arriving from the direct/group Supabase sync, which only carries
  // `content`) keep loading as plain text.

  final ChatMessageKind kind;

  /// Announcement headline, or the question of a poll.
  final String? title;

  /// User ids mentioned in [content]; `everyone` is the broadcast mention.
  final List<String> mentions;

  /// emoji → the user ids that reacted with it.
  final Map<String, List<String>> reactions;

  final String? attachmentPath;
  final String? attachmentName;
  final int? attachmentSize;

  final List<String> pollOptions;

  /// voter id → chosen option index.
  final Map<String, int> pollVotes;
  final DateTime? pollClosesAt;

  /// Event this message links to (for the inline event card).
  final String? eventId;

  /// Post shared into a DM, user-created group, or club conversation.
  final String? sharedPostId;

  /// Pinned to the top of the community stream.
  final bool pinned;

  static const String everyoneMention = 'everyone';

  MessageDeliveryStatus get status => seenAt == null
      ? MessageDeliveryStatus.delivered
      : MessageDeliveryStatus.seen;

  /// Group delivery is aggregated across every current recipient. The sender
  /// is excluded because receipt rows represent devices that received the
  /// message, matching WhatsApp-style group status semantics.
  MessageDeliveryStatus groupStatusForMembers(Iterable<String> memberIds) {
    final recipientIds = memberIds
        .where((userId) => userId.isNotEmpty && userId != senderId)
        .toSet();
    if (recipientIds.isEmpty) return MessageDeliveryStatus.sent;
    final byUser = {for (final receipt in receipts) receipt.userId: receipt};
    if (recipientIds.every((userId) => byUser[userId]?.seenAt != null)) {
      return MessageDeliveryStatus.seen;
    }
    if (recipientIds.every((userId) => byUser[userId]?.deliveredAt != null)) {
      return MessageDeliveryStatus.delivered;
    }
    return MessageDeliveryStatus.sent;
  }

  bool get mentionsEveryone => mentions.contains(everyoneMention);

  bool mentionsUser(String userId) =>
      userId.isNotEmpty && mentions.contains(userId);

  int votesForOption(int optionIndex) =>
      pollVotes.values.where((choice) => choice == optionIndex).length;

  int get totalPollVotes => pollVotes.length;

  bool get pollIsClosed =>
      pollClosesAt != null && DateTime.now().isAfter(pollClosesAt!);

  int get totalReactions =>
      reactions.values.fold(0, (sum, users) => sum + users.length);

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    DateTime? deliveredAt,
    this.seenAt,
    List<MessageReceipt>? receipts,
    this.replyToMessageId,
    this.replyToSenderId,
    this.replyToPreview,
    this.kind = ChatMessageKind.text,
    this.title,
    List<String>? mentions,
    Map<String, List<String>>? reactions,
    this.attachmentPath,
    this.attachmentName,
    this.attachmentSize,
    List<String>? pollOptions,
    Map<String, int>? pollVotes,
    this.pollClosesAt,
    this.eventId,
    this.sharedPostId,
    this.pinned = false,
  }) : deliveredAt = deliveredAt ?? createdAt,
       receipts = List.unmodifiable(receipts ?? const []),
       mentions = List.unmodifiable(mentions ?? const []),
       reactions = Map.unmodifiable({
         for (final entry
             in (reactions ?? const <String, List<String>>{}).entries)
           if (entry.value.isNotEmpty)
             entry.key: List<String>.unmodifiable(entry.value),
       }),
       pollOptions = List.unmodifiable(pollOptions ?? const []),
       pollVotes = Map.unmodifiable(pollVotes ?? const {});

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? seenAt,
    List<MessageReceipt>? receipts,
    String? replyToMessageId,
    String? replyToSenderId,
    String? replyToPreview,
    ChatMessageKind? kind,
    String? title,
    List<String>? mentions,
    Map<String, List<String>>? reactions,
    String? attachmentPath,
    String? attachmentName,
    int? attachmentSize,
    List<String>? pollOptions,
    Map<String, int>? pollVotes,
    DateTime? pollClosesAt,
    String? eventId,
    String? sharedPostId,
    bool? pinned,
  }) => ChatMessage(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    senderId: senderId ?? this.senderId,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    seenAt: seenAt ?? this.seenAt,
    receipts: receipts ?? this.receipts,
    replyToMessageId: replyToMessageId ?? this.replyToMessageId,
    replyToSenderId: replyToSenderId ?? this.replyToSenderId,
    replyToPreview: replyToPreview ?? this.replyToPreview,
    kind: kind ?? this.kind,
    title: title ?? this.title,
    mentions: mentions ?? this.mentions,
    reactions: reactions ?? this.reactions,
    attachmentPath: attachmentPath ?? this.attachmentPath,
    attachmentName: attachmentName ?? this.attachmentName,
    attachmentSize: attachmentSize ?? this.attachmentSize,
    pollOptions: pollOptions ?? this.pollOptions,
    pollVotes: pollVotes ?? this.pollVotes,
    pollClosesAt: pollClosesAt ?? this.pollClosesAt,
    eventId: eventId ?? this.eventId,
    sharedPostId: sharedPostId ?? this.sharedPostId,
    pinned: pinned ?? this.pinned,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'threadId': threadId,
    'senderId': senderId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'deliveredAt': deliveredAt.toIso8601String(),
    'seenAt': seenAt?.toIso8601String(),
    if (receipts.isNotEmpty)
      'receipts': receipts.map((receipt) => receipt.toMap()).toList(),
    if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    if (replyToSenderId != null) 'replyToSenderId': replyToSenderId,
    if (replyToPreview != null) 'replyToPreview': replyToPreview,
    if (kind != ChatMessageKind.text) 'kind': kind.name,
    if (title != null) 'title': title,
    if (mentions.isNotEmpty) 'mentions': mentions,
    if (reactions.isNotEmpty)
      'reactions': {
        for (final entry in reactions.entries) entry.key: entry.value,
      },
    if (attachmentPath != null) 'attachmentPath': attachmentPath,
    if (attachmentName != null) 'attachmentName': attachmentName,
    if (attachmentSize != null) 'attachmentSize': attachmentSize,
    if (pollOptions.isNotEmpty) 'pollOptions': pollOptions,
    if (pollVotes.isNotEmpty) 'pollVotes': pollVotes,
    if (pollClosesAt != null) 'pollClosesAt': pollClosesAt!.toIso8601String(),
    if (eventId != null) 'eventId': eventId,
    if (sharedPostId != null) 'sharedPostId': sharedPostId,
    if (pinned) 'pinned': true,
  };

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
    id: m['id'] as String,
    threadId: m['threadId'] as String,
    senderId: m['senderId'] as String,
    content: m['content'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    deliveredAt: m['deliveredAt'] == null
        ? null
        : DateTime.parse(m['deliveredAt'] as String),
    seenAt: m['seenAt'] == null ? null : DateTime.parse(m['seenAt'] as String),
    receipts: (m['receipts'] as List? ?? const [])
        .map(
          (receipt) =>
              MessageReceipt.fromMap(Map<String, dynamic>.from(receipt as Map)),
        )
        .where((receipt) => receipt.userId.isNotEmpty)
        .toList(growable: false),
    replyToMessageId: m['replyToMessageId']?.toString(),
    replyToSenderId: m['replyToSenderId']?.toString(),
    replyToPreview: m['replyToPreview']?.toString(),
    kind: _kindFromName(m['kind']),
    title: m['title']?.toString(),
    mentions: (m['mentions'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    reactions: {
      for (final entry in (m['reactions'] as Map? ?? const {}).entries)
        entry.key.toString(): (entry.value as List? ?? const [])
            .map((value) => value.toString())
            .toList(growable: false),
    },
    attachmentPath: m['attachmentPath']?.toString(),
    attachmentName: m['attachmentName']?.toString(),
    attachmentSize: m['attachmentSize'] as int?,
    pollOptions: (m['pollOptions'] as List? ?? const [])
        .map((value) => value.toString())
        .toList(growable: false),
    pollVotes: {
      for (final entry in (m['pollVotes'] as Map? ?? const {}).entries)
        entry.key.toString(): entry.value as int,
    },
    pollClosesAt: m['pollClosesAt'] == null
        ? null
        : DateTime.tryParse(m['pollClosesAt'].toString()),
    eventId: m['eventId']?.toString(),
    sharedPostId: m['sharedPostId']?.toString(),
    pinned: m['pinned'] == true,
  );
}
