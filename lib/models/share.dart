class Share {
  final String id;
  final String targetId; // postId or eventId
  final String userId;
  final DateTime createdAt;

  Share({
    required this.id,
    required this.targetId,
    required this.userId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'targetId': targetId,
    'userId': userId,
    'createdAt': createdAt.toIso8601String(),
  };

  factory Share.fromMap(Map<String, dynamic> m) => Share(
    id: m['id'] as String,
    targetId: m['targetId'] as String,
    userId: m['userId'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
  );
}
