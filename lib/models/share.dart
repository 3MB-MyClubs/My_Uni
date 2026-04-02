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
}
