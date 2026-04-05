class AppNotification {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;
  final bool read;
  // 'post' | 'club' | 'event' | 'user' — null means no navigation
  final String? targetType;
  final String? targetId;

  AppNotification({
    required this.id,
    required this.userId,
    required this.message,
    required this.createdAt,
    this.read = false,
    this.targetType,
    this.targetId,
  });
}
