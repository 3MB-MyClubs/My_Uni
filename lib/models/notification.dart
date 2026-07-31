class AppNotification {
  final String id;
  final String userId;
  final String message;
  final DateTime createdAt;
  final bool read;
  // Backend copy/category type, e.g. direct_message or group_message.
  final String? notificationType;
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
    this.notificationType,
    this.targetType,
    this.targetId,
    this.fromId,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'userId': userId,
    'message': message,
    'createdAt': createdAt.toIso8601String(),
    'read': read,
    'notificationType': notificationType,
    'targetType': targetType,
    'targetId': targetId,
    'fromId': fromId,
  };

  factory AppNotification.fromMap(Map<String, dynamic> m) => AppNotification(
    id: m['id'] as String,
    userId: m['userId'] as String,
    message: m['message'] as String,
    createdAt: DateTime.parse(m['createdAt'] as String),
    read: m['read'] as bool? ?? false,
    notificationType: m['notificationType'] as String?,
    targetType: m['targetType'] as String?,
    targetId: m['targetId'] as String?,
    fromId: m['fromId'] as String?,
  );
}
