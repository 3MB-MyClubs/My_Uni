enum MessageDeliveryStatus { delivered, seen }

class ChatMessage {
  final String id;
  final String threadId;
  final String senderId;
  final String content;
  final DateTime createdAt;
  final DateTime deliveredAt;
  final DateTime? seenAt;

  MessageDeliveryStatus get status => seenAt == null
      ? MessageDeliveryStatus.delivered
      : MessageDeliveryStatus.seen;

  ChatMessage({
    required this.id,
    required this.threadId,
    required this.senderId,
    required this.content,
    required this.createdAt,
    DateTime? deliveredAt,
    this.seenAt,
  }) : deliveredAt = deliveredAt ?? createdAt;

  ChatMessage copyWith({
    String? id,
    String? threadId,
    String? senderId,
    String? content,
    DateTime? createdAt,
    DateTime? deliveredAt,
    DateTime? seenAt,
  }) => ChatMessage(
    id: id ?? this.id,
    threadId: threadId ?? this.threadId,
    senderId: senderId ?? this.senderId,
    content: content ?? this.content,
    createdAt: createdAt ?? this.createdAt,
    deliveredAt: deliveredAt ?? this.deliveredAt,
    seenAt: seenAt ?? this.seenAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'threadId': threadId,
    'senderId': senderId,
    'content': content,
    'createdAt': createdAt.toIso8601String(),
    'deliveredAt': deliveredAt.toIso8601String(),
    'seenAt': seenAt?.toIso8601String(),
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
  );
}
