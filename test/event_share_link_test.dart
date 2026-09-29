import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/screens/event_shared_link_screen.dart';
import 'package:flutter_application_1/services/event_share_link.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('event QR link is parsed and queued until the app is ready', () {
    const eventId = '90ef4f3a-40d3-4aa4-8edc-d319a2e82087';
    final link = EventShareLink.forEvent(eventId);
    expect(link, 'https://myclub.bar/event/$eventId');
    expect(EventShareLink.eventIdFrom(Uri.parse(link)), eventId);

    final coordinator = EventLinkCoordinator();
    addTearDown(coordinator.dispose);
    coordinator.receive(Uri.parse(link));
    expect(coordinator.pendingEventId, eventId);
    coordinator.receive(Uri.parse('kuclubs://user/someone'));
    expect(coordinator.pendingEventId, eventId);
    expect(coordinator.takePendingEventId(), eventId);
    expect(coordinator.pendingEventId, isNull);
  });

  test('unrelated and malformed links never route to an event', () {
    for (final link in [
      'kuclubs://user/90ef4f3a-40d3-4aa4-8edc-d319a2e82087',
      'kuclubs://event/',
      'kuclubs://event/one/two',
      'kuclubs://event/one?extra=two',
      'kuclubs://event/one#fragment',
      'https://other.example/event/one',
      'http://myclub.bar/event/one',
      'https://myclub.bar/events/one',
      'https://myclub.bar/event/',
      'https://myclub.bar/event/one/two',
      'https://myclub.bar/event/one?extra=two',
      'https://myclub.bar/event/one#fragment',
      'kuclubs://event/one%2Ftwo',
    ]) {
      expect(EventShareLink.eventIdFrom(Uri.parse(link)), isNull, reason: link);
    }
  });

  test('previously shared app links still open an event', () {
    expect(
      EventShareLink.eventIdFrom(Uri.parse('kuclubs://event/old-event')),
      'old-event',
    );
  });

  testWidgets('incoming event link opens its description screen', (
    tester,
  ) async {
    final start = DateTime(2026, 10, 1, 18);
    final event = Event(
      id: '90ef4f3a-40d3-4aa4-8edc-d319a2e82087',
      clubId: 'test-club',
      title: 'Campus Futures Forum',
      description: 'A student-led conversation.',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'Student Center',
      attendeeUserIds: const [],
    );
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventSharedLinkScreen(
            eventId: event.id,
            resolveEvent: (id) async => id == event.id ? event : null,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(EventDetailScreen), findsOneWidget);
    expect(find.text('Campus Futures Forum'), findsWidgets);
    expect(find.text('A student-led conversation.'), findsOneWidget);
  });
}
