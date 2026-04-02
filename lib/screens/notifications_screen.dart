import 'package:flutter/material.dart';
import '../services/app_colors.dart';
import '../services/mock_data.dart';
import '../services/user_state.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final Set<String> _read = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        title: const Text('Notifications', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22)),
        actions: [
          TextButton(
            onPressed: () => setState(() {
              _read.addAll(notifications.map((n) => n.id));
              userState.unreadNotifications = 0;
            }),
            child: const Text('Mark all read', style: TextStyle(color: AppColors.primaryRed, fontSize: 13)),
          ),
        ],
      ),
      body: notifications.isEmpty
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_none, size: 64, color: AppColors.secondaryText),
                  SizedBox(height: 12),
                  Text('No notifications yet', style: TextStyle(color: AppColors.secondaryText, fontSize: 16)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (context, i) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, i) {
                final n = notifications[i];
                final isRead = _read.contains(n.id);
                return _NotificationTile(
                  notificationId: n.id,
                  message: n.message,
                  time: _timeAgo(n.createdAt),
                  isRead: isRead,
                  onTap: () => setState(() {
                    _read.add(n.id);
                    if (userState.unreadNotifications > 0) {
                      userState.unreadNotifications--;
                    }
                  }),
                );
              },
            ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _NotificationTile extends StatelessWidget {
  final String notificationId;
  final String message;
  final String time;
  final bool isRead;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notificationId,
    required this.message,
    required this.time,
    required this.isRead,
    required this.onTap,
  });

  // Pick an icon based on message keywords
  IconData get _icon {
    if (message.toLowerCase().contains('liked')) return Icons.favorite;
    if (message.toLowerCase().contains('comment')) return Icons.comment;
    if (message.toLowerCase().contains('event') || message.toLowerCase().contains('workshop') || message.toLowerCase().contains('tomorrow')) return Icons.event;
    if (message.toLowerCase().contains('posted') || message.toLowerCase().contains('update')) return Icons.article;
    return Icons.notifications;
  }

  Color get _iconColor {
    if (message.toLowerCase().contains('liked')) return Colors.pink;
    if (message.toLowerCase().contains('comment')) return Colors.blue;
    if (message.toLowerCase().contains('event') || message.toLowerCase().contains('tomorrow')) return AppColors.accentGold;
    return AppColors.primaryRed;
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        color: isRead ? Colors.transparent : AppColors.lightRed,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: _iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, color: _iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.text,
                      fontWeight: isRead ? FontWeight.normal : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    time,
                    style: const TextStyle(fontSize: 12, color: AppColors.secondaryText),
                  ),
                ],
              ),
            ),
            if (!isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 4),
                decoration: const BoxDecoration(
                  color: AppColors.primaryRed,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
