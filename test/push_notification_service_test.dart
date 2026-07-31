import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/notification.dart';
import 'package:flutter_application_1/services/notification_navigation.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/services/push_notification_service.dart';
import 'package:flutter_application_1/services/push_notification_copy.dart';

void main() {
  test('parses notification navigation data', () {
    final target = PushNotificationTarget.fromData({
      'type': 'event',
      'target_id': 'event-123',
      'notification_id': 'notification-456',
    });

    expect(target.type, 'event');
    expect(target.targetId, 'event-123');
    expect(target.notificationId, 'notification-456');
  });

  test('supports target_type and safe defaults', () {
    expect(
      PushNotificationTarget.fromData({'target_type': 'post'}).type,
      'post',
    );
    expect(PushNotificationTarget.fromData(const {}).type, 'notification');
  });

  test('uses target_type for navigation instead of the copy type', () {
    final target = PushNotificationTarget.fromData({
      'type': 'club_post',
      'target_type': 'post',
      'target_id': 'post-123',
    });

    expect(target.type, 'post');
    expect(target.notificationType, 'club_post');
    expect(target.targetId, 'post-123');
  });

  test('normalizes direct-message payload to the canonical DM thread', () {
    final target = PushNotificationTarget.fromData({
      'type': 'direct_message',
      'target_type': 'message',
      'target_id': 'user-b',
    });

    expect(target.type, 'direct_message');
    expect(target.isChat, isTrue);
    expect(target.chatThreadIdFor('user-a'), 'dm:user-a|user-b');
  });

  test('normalizes raw group UUID to the canonical group thread', () {
    final target = PushNotificationTarget.fromData({
      'type': 'group_message',
      'target_type': 'message',
      'target_id': 'group-123',
      'actor_user_id': 'sender-456',
    });

    expect(target.type, 'group_chat');
    expect(target.actorId, 'sender-456');
    expect(target.chatThreadIdFor('user-a'), 'group:group-123');
  });

  test('keeps legacy prefixed chat targets intact', () {
    final group = PushNotificationTarget.fromData({
      'target_type': 'message',
      'target_id': 'group:legacy-group',
    });
    final club = PushNotificationTarget.fromData({
      'target_type': 'chat',
      'target_id': 'club:club-1',
    });

    expect(group.type, 'group_chat');
    expect(group.chatThreadIdFor('user-a'), 'group:legacy-group');
    expect(club.type, 'club_chat');
    expect(club.chatThreadIdFor('user-a'), 'club:club-1');
  });

  test('derives content destinations from notification type as fallback', () {
    expect(
      PushNotificationTarget.fromData({
        'type': 'post_comment',
        'target_id': 'post-1',
      }).type,
      'post',
    );
    expect(
      PushNotificationTarget.fromData({
        'type': 'club_event',
        'target_id': 'event-1',
      }).type,
      'event',
    );
    expect(
      PushNotificationTarget.fromData({
        'type': 'profile_follow',
        'target_id': 'user-1',
      }).type,
      'user',
    );
  });

  test('notification-center rows preserve the group-message subtype', () {
    final target = notificationTargetFor(
      AppNotification(
        id: 'notification-1',
        userId: 'user-a',
        message: 'A new message',
        createdAt: DateTime(2026),
        notificationType: 'group_message',
        targetType: 'message',
        targetId: 'group-123',
        fromId: 'user-b',
      ),
    );

    expect(target.type, 'group_chat');
    expect(target.chatThreadIdFor('user-a'), 'group:group-123');
  });

  test('legacy notification-center DM rows build a canonical DM thread', () {
    final target = notificationTargetFor(
      AppNotification(
        id: 'notification-2',
        userId: 'user-b',
        message: 'A new message',
        createdAt: DateTime(2026),
        targetType: 'message',
        targetId: 'user-a',
        fromId: 'user-a',
      ),
    );

    expect(target.type, 'direct_message');
    expect(target.chatThreadIdFor('user-b'), 'dm:user-a|user-b');
  });

  test('preserves club channel and club inbox messaging targets', () {
    final channel = PushNotificationTarget.fromData({
      'type': 'club_channel_message',
      'target_type': 'message',
      'target_id': 'club-1',
    });
    final inbox = PushNotificationTarget.fromData({
      'type': 'club_inbox_message',
      'target_type': 'message',
      'target_id': 'inbox-1',
    });

    expect(channel.type, 'club_chat');
    expect(channel.chatThreadIdFor('user-a'), 'club:club-1');
    expect(inbox.type, 'club_inbox');
    expect(inbox.chatThreadIdFor('club-admin'), 'clubdm:inbox-1');
  });

  test('localizes club post copy in English and Turkish', () {
    final args = {'clubName': 'KU Music', 'content': 'Concert tonight'};
    final english = localizedPushNotificationCopy(
      type: 'club_post',
      args: args,
      languageCode: 'en',
      fallbackTitle: '',
      fallbackBody: '',
    );
    final turkish = localizedPushNotificationCopy(
      type: 'club_post',
      args: args,
      languageCode: 'tr',
      fallbackTitle: '',
      fallbackBody: '',
    );

    expect(english.title, 'KU Music posted something new');
    expect(english.body, contains('Tap to view the post'));
    expect(turkish.title, 'KU Music yeni bir gönderi paylaştı');
    expect(turkish.body, contains('Gönderiyi görmek için dokun'));
  });

  test('localizes social activity copy', () {
    final copy = localizedPushNotificationCopy(
      type: 'post_comment',
      args: {'actorName': 'Ece', 'comment': 'Harika!'},
      languageCode: 'tr',
      fallbackTitle: '',
      fallbackBody: '',
    );

    expect(copy.title, 'Ece gönderine yorum yaptı');
    expect(copy.body, 'Ece: “Harika!” Yanıtlamak için dokun.');
  });

  test('message notifications include the stored message preview', () {
    final copy = localizedPushNotificationCopy(
      type: 'direct_message',
      args: {'actorName': 'Ece', 'content': 'See you at the library'},
      languageCode: 'en',
      fallbackTitle: '',
      fallbackBody: '',
    );

    expect(copy.body, 'Ece: See you at the library');
  });

  test(
    'normalizes local and remote direct-message rows to one conversation',
    () {
      final remote = AppNotification(
        id: 'remote-message',
        userId: 'user-a',
        fromId: 'user-b',
        message: 'Ece: Hello',
        createdAt: DateTime(2026),
        notificationType: 'direct_message',
        targetType: 'message',
        targetId: 'user-b',
      );
      final local = AppNotification(
        id: 'local-message',
        userId: 'user-a',
        fromId: 'user-b',
        message: 'Ece: Later',
        createdAt: DateTime(2026, 1, 1, 0, 1),
        targetType: 'message',
        targetId: 'dm:user-a|user-b',
      );

      expect(
        notificationConversationKey(remote),
        notificationConversationKey(local),
      );
    },
  );

  test('groups push data by the chat conversation', () {
    expect(
      notificationGroupKeyFromPushData({
        'type': 'group_message',
        'target_type': 'message',
        'target_id': 'group-123',
      }),
      'group:group-123',
    );
    expect(
      notificationGroupKeyFromPushData({
        'type': 'direct_message',
        'target_type': 'message',
        'target_id': 'user-b',
        'actor_user_id': 'user-b',
      }),
      'direct:user-b',
    );
  });

  test('uses one deterministic local notification id per chat key', () {
    final first = notificationService.notificationIdFor('group:group-123');
    final second = notificationService.notificationIdFor('group:group-123');
    final other = notificationService.notificationIdFor('group:group-456');

    expect(first, greaterThan(0));
    expect(second, first);
    expect(other, isNot(first));
  });

  test('renders a grouped message count instead of another alert preview', () {
    final copy = localizedPushNotificationCopy(
      type: 'group_message',
      args: {'groupName': 'Study group', 'actorName': 'Ece', 'messageCount': 3},
      languageCode: 'en',
      fallbackTitle: '',
      fallbackBody: '',
    );

    expect(copy.title, 'Study group');
    expect(copy.body, '3 new messages');
  });
}
