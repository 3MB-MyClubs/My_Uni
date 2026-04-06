class AppNotification {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;
  final bool read;
  // 'post' | 'club' | 'event' | 'user' | 'message' | 'follow_request' | 'follow_accepted'
  final String? targetType;
  final String? targetId;
  // For follow_request: the ID of the user who sent the request.
  final String? fromId;

  AppNotification({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.read = false,
    this.targetType,
    this.targetId,
    this.fromId,
  });
}
