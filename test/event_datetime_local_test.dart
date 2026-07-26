import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('backend UTC event timestamps normalize to device-local time', () {
    final parsed = tryParseEventDateTime('2030-04-15T14:30:00.000Z');

    expect(parsed, DateTime.utc(2030, 4, 15, 14, 30).toLocal());
    expect(parsed?.isUtc, isFalse);
  });

  test('persisted events restore start and end as local times', () {
    final event = Event.fromMap({
      'id': 'timezone-event',
      'clubId': 'c1',
      'title': 'Timezone event',
      'description': '',
      'dateTime': '2030-04-15T14:30:00.000Z',
      'endTime': '2030-04-15T16:00:00.000Z',
      'location': 'Campus',
      'attendeeUserIds': <String>[],
    });

    expect(event.dateTime, DateTime.utc(2030, 4, 15, 14, 30).toLocal());
    expect(event.endTime, DateTime.utc(2030, 4, 15, 16).toLocal());
    expect(event.dateTime.isUtc, isFalse);
    expect(event.endTime.isUtc, isFalse);
  });
}
