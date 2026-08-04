import 'package:flutter/material.dart';

import '../models/notification.dart';
import '../models/user.dart';
import '../navigation/chat_page_route.dart';
import '../screens/chat_thread_screen.dart';
import '../screens/club_profile_screen.dart';
import '../screens/event_detail_screen.dart';
import '../screens/post_detail_screen.dart';
import '../screens/user_profile_screen.dart';
import 'chat_store.dart';
import 'mock_data.dart';
import 'people_service.dart';
import 'push_notification_service.dart';

const List<Color> _notificationClubColors = [
  Color(0xFFB41C18),
  Color(0xFF1565C0),
  Color(0xFF2E7D32),
  Color(0xFF6A1B9A),
  Color(0xFFE65100),
  Color(0xFF00838F),
];

Color _clubColor(String clubId) {
  final index = clubOrdinal(clubId);
  return _notificationClubColors[(index < 0 ? 0 : index) %
      _notificationClubColors.length];
}

PushNotificationTarget notificationTargetFor(AppNotification notification) =>
    PushNotificationTarget.fromData({
      if (notification.notificationType != null)
        'type': notification.notificationType,
      if (notification.targetType != null)
        'target_type': notification.targetType,
      if (notification.targetId != null) 'target_id': notification.targetId,
      if (notification.fromId != null) 'actor_user_id': notification.fromId,
      'notification_id': notification.id,
    });

/// Returns whether [currentUserId] is allowed to see this notification now.
///
/// The recipient id is the first boundary. Chat alerts also have to resolve to
/// a conversation the recipient currently belongs to, so stale or malformed
/// rows cannot expose another conversation through the bell or inbox UI.
bool canViewNotification(
  AppNotification notification, {
  required String currentUserId,
}) {
  if (currentUserId.isEmpty || notification.userId != currentUserId) {
    return false;
  }
  if (notification.targetType != 'message') return true;

  final target = notificationTargetFor(notification);
  if (!target.isChat) return false;
  if (ChatStore.isAdminAccountId(currentUserId) &&
      target.type != 'club_chat' &&
      target.type != 'club_inbox') {
    return false;
  }
  final threadId = target.chatThreadIdFor(currentUserId);
  return threadId != null && chatStore.canAccessThread(threadId, currentUserId);
}

User? _knownUser(String id) {
  for (final user in peopleService.cachedPeople) {
    if (user.id == id) return user;
  }
  for (final user in users) {
    if (user.id == id) return user;
  }
  return null;
}

/// Opens a notification destination using the same rules for push taps and
/// rows in the notification center. Returns false for stale/malformed targets
/// instead of silently opening the first unrelated post, event, club, or user.
Future<bool> openNotificationTarget(
  BuildContext context,
  PushNotificationTarget target, {
  required String currentUserId,
}) async {
  final id = target.targetId;
  switch (target.type) {
    case 'notification':
      return false;
    case 'post':
      if (id == null) return false;
      final index = newsPosts.indexWhere((post) => post.id == id);
      if (index < 0 || !context.mounted) return false;
      final post = newsPosts[index];
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              PostDetailScreen(post: post, clubColor: _clubColor(post.clubId)),
        ),
      );
      return true;
    case 'event':
      if (id == null) return false;
      final index = events.indexWhere((event) => event.id == id);
      if (index < 0 || !context.mounted) return false;
      final event = events[index];
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              EventDetailScreen(event: event, color: _clubColor(event.clubId)),
        ),
      );
      return true;
    case 'club':
      if (id == null) return false;
      final club = clubForId(id);
      if (club == null || !context.mounted) return false;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ClubProfileScreen(club: club, color: _clubColor(id)),
        ),
      );
      return true;
    case 'user':
      if (id == null) return false;
      await peopleService.hydrateProfilesByIds([id]);
      if (!context.mounted) return false;
      final user = _knownUser(id);
      if (user == null) return false;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => UserProfileScreen(user: user)),
      );
      return true;
    case 'direct_message':
    case 'group_chat':
    case 'club_chat':
    case 'club_inbox':
      if (currentUserId.isEmpty ||
          (ChatStore.isAdminAccountId(currentUserId) &&
              target.type != 'club_chat' &&
              target.type != 'club_inbox')) {
        return false;
      }
      final threadId = target.chatThreadIdFor(currentUserId);
      if (threadId == null) return false;
      User? recipient;
      if (ChatStore.isDirectThread(threadId)) {
        final peerId = ChatStore.dmPeerOf(threadId, currentUserId);
        if (peerId == null ||
            chatStore.ensureDirectThread(currentUserId, peerId) == null) {
          return false;
        }
        await peopleService.hydrateProfilesByIds([peerId]);
        recipient = _knownUser(peerId);
      } else if (ChatStore.isGroupThread(threadId)) {
        await chatStore.startDirectMessageSync(currentUserId);
      } else if (ChatStore.isClubThread(threadId) ||
          ChatStore.isClubInboxThread(threadId)) {
        await chatStore.startClubMessageSync(currentUserId);
      }
      if (!context.mounted ||
          !chatStore.canAccessThread(threadId, currentUserId)) {
        return false;
      }
      await Navigator.of(context).push(
        ChatPageRoute<void>(
          builder: (_) =>
              ChatThreadScreen(threadId: threadId, recipient: recipient),
        ),
      );
      return true;
  }
  return false;
}
