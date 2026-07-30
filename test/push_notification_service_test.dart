import 'package:flutter_test/flutter_test.dart';
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

  test('prefers navigation target_type over notification event type', () {
    final target = PushNotificationTarget.fromData({
      'type': 'group_message',
      'target_type': 'message',
      'target_id': 'group-123',
    });

    expect(target.type, 'message');
    expect(target.notificationType, 'group_message');
    expect(target.targetId, 'group-123');
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
}
