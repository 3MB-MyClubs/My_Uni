import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/event_access.dart';

void main() {
  final event = Event(
    id: 'privacy-event',
    clubId: 'c1',
    title: 'Private attendance event',
    description: '',
    dateTime: DateTime(2030, 1, 1),
    endTime: DateTime(2030, 1, 1, 1),
    location: 'Campus',
    attendeeUserIds: const ['u1', 'u2'],
    createdByUserId: 'cadmin2',
  );

  tearDown(authService.logout);

  test('only the exact event creator can view attendance', () {
    expect(canViewEventAttendance(event), isFalse);

    authService.login('kuadk@ku.edu.tr', '11111111');
    expect(canViewEventAttendance(event), isFalse);

    authService.logout();
    authService.login('kuarha@ku.edu.tr', '11111111');
    expect(canViewEventAttendance(event), isTrue);
  });

  test('legacy events without a recorded creator expose no attendance', () {
    authService.login('kuarha@ku.edu.tr', '11111111');
    final legacyEvent = Event(
      id: 'legacy-event',
      clubId: 'c1',
      title: 'Legacy event',
      description: '',
      dateTime: DateTime(2030, 1, 1),
      endTime: DateTime(2030, 1, 1, 1),
      location: 'Campus',
      attendeeUserIds: const ['u1'],
    );

    expect(canViewEventAttendance(legacyEvent), isFalse);
  });
}
