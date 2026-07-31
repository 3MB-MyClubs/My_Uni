enum MessageDeliveryStatus { delivered, seen }

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
