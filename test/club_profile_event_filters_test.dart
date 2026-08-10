import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/event_cleanup_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Club _club(String id, String name) => Club(
  id: id,
  name: name,
  description: '$name description',
  adminUserIds: const [],
);

Event _event({
  required String id,
  required String clubId,
  required String title,
  required DateTime start,
  Duration duration = const Duration(hours: 2),
}) => Event(
  id: id,
  clubId: clubId,
  title: title,
  description: '$title description',
  dateTime: start,
  endTime: start.add(duration),
  location: 'Koç University',
  attendeeUserIds: [],
);

Widget _host(Club club) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: ClubProfileScreen(club: club, color: Colors.red, initialTabIndex: 1),
  ),
);

Future<void> _openEvents(WidgetTester tester, Club club) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(_host(club));
  await tester.pump();
}

Future<void> _selectPast(WidgetTester tester) async {
  final filter = tester.widget<GestureDetector>(
    find.byKey(const ValueKey('club-events-filter-past')),
  );
  filter.onTap!();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 250));
}

void main() {
  late List<Club> originalClubs;
  late List<Event> originalEvents;
  late Club viewedClub;

  setUp(() {
    originalClubs = List<Club>.from(clubs);
    originalEvents = List<Event>.from(events);
    viewedClub = _club('club-event-filter', 'Event Filter Club');
    final otherClub = _club('other-event-filter', 'Other Club');
    final now = DateTime.now();

    clubs
      ..clear()
      ..addAll([viewedClub, otherClub]);
    events
      ..clear()
      ..addAll([
        _event(
          id: 'future-event',
          clubId: viewedClub.id,
          title: 'Future Workshop',
          start: now.add(const Duration(days: 5)),
        ),
        _event(
          id: 'live-event',
          clubId: viewedClub.id,
          title: 'Live Meetup',
          start: now.subtract(const Duration(minutes: 30)),
        ),
        _event(
          id: 'recent-past-event',
          clubId: viewedClub.id,
          title: 'Recent Alumni Talk',
          start: now.subtract(const Duration(days: 2)),
        ),
        _event(
          id: 'old-past-event',
          clubId: viewedClub.id,
          title: 'Old Welcome Night',
          start: now.subtract(const Duration(days: 30)),
        ),
        _event(
          id: 'other-club-past-event',
          clubId: otherClub.id,
          title: 'Other Club Event',
          start: now.subtract(const Duration(days: 1)),
        ),
      ]);
  });

  tearDown(() {
    clubs
      ..clear()
      ..addAll(originalClubs);
    events
      ..clear()
      ..addAll(originalEvents);
  });

  testWidgets(
    'Club Profile switches one event area between Upcoming and Past',
    (tester) async {
      await _openEvents(tester, viewedClub);

      expect(find.text('Upcoming'), findsOneWidget);
      expect(find.text('Past'), findsOneWidget);
      expect(find.text('Future Workshop'), findsOneWidget);
      expect(find.text('Live Meetup'), findsOneWidget);
      expect(find.text('Recent Alumni Talk'), findsNothing);

      await _selectPast(tester);

      expect(find.text('Future Workshop'), findsNothing);
      expect(find.text('Live Meetup'), findsNothing);
      expect(find.text('Recent Alumni Talk'), findsOneWidget);
      expect(find.text('Old Welcome Night'), findsOneWidget);
      expect(find.text('Other Club Event'), findsNothing);

      final recentTop = tester.getTopLeft(find.text('Recent Alumni Talk')).dy;
      final oldTop = tester.getTopLeft(find.text('Old Welcome Night')).dy;
      expect(recentTop, lessThan(oldTop));

      final eventCard = tester.widget<GestureDetector>(
        find.byKey(const ValueKey('club-event-card-recent-past-event')),
      );
      eventCard.onTap!();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(EventDetailScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Past uses the localized empty state in the same event area', (
    tester,
  ) async {
    events.removeWhere(
      (event) =>
          event.clubId == viewedClub.id &&
          !event.endTime.isAfter(DateTime.now()),
    );

    await _openEvents(tester, viewedClub);
    await _selectPast(tester);

    expect(find.text('No past events yet.'), findsOneWidget);
    expect(find.text('Future Workshop'), findsNothing);
    expect(find.text('Past'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('past events remain stored for club and student history', () async {
    await eventCleanupService.cleanupExpiredEvents();

    expect(
      events.map((event) => event.id),
      containsAll(['recent-past-event', 'old-past-event']),
    );
  });
}
