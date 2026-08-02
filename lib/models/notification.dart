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

/// Returns the stable conversation key used to group chat notifications.
///
/// Direct-message rows from Supabase store the sender as [targetId], while
/// local chat rows store the canonical `dm:userA|userB` thread id. Both forms
/// are normalized to the same key so a conversation cannot appear twice in
/// the notification center.
String? notificationConversationKey(AppNotification notification) {
  if (notification.targetType != 'message') return null;

  final targetId = notification.targetId?.trim();
  if (targetId == null || targetId.isEmpty) return null;

  final type = notification.notificationType
      ?.trim()
      .toLowerCase()
      .replaceAll('-', '_')
      .replaceAll(' ', '_');

  if (type == 'direct_message' || targetId.startsWith('dm:')) {
    final participants = <String>{notification.userId};
    if (targetId.startsWith('dm:')) {
      participants.addAll(
        targetId
            .substring('dm:'.length)
            .split('|')
            .map((id) => id.trim())
            .where((id) => id.isNotEmpty),
      );
    } else {
      final peerId = notification.fromId?.trim();
      participants.add(peerId == null || peerId.isEmpty ? targetId : peerId);
    }
    final sorted = participants.toList()..sort();
    return 'direct:${notification.userId}:${sorted.join('|')}';
  }

  if (type == 'group_message' || targetId.startsWith('group:')) {
    return 'group:${notification.userId}:${_withoutPrefix(targetId, 'group:')}';
  }

  if (type == 'club_channel_message' || targetId.startsWith('club:')) {
    return 'club:${notification.userId}:${_withoutPrefix(targetId, 'club:')}';
  }

  if (type == 'club_inbox_message' || targetId.startsWith('clubdm:')) {
    return 'club_inbox:${notification.userId}:${_withoutPrefix(targetId, 'clubdm:')}';
  }

  // Keep unknown/legacy message notifications isolated instead of merging
  // them with a different chat that happens to use the same target id.
  return 'message:${notification.userId}:${type ?? 'unknown'}:$targetId';
}

String _withoutPrefix(String value, String prefix) =>
    value.startsWith(prefix) ? value.substring(prefix.length) : value;
