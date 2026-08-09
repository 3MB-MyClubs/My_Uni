import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/this_week_screen.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('event search matches custom tags case-insensitively', (
    tester,
  ) async {
    final originalClubs = List<Club>.from(clubs);
    final originalEvents = List<Event>.from(events);
    addTearDown(() {
      clubs
        ..clear()
        ..addAll(originalClubs);
      events
        ..clear()
        ..addAll(originalEvents);
    });

    final start = DateTime.now().add(const Duration(days: 3));
    clubs
      ..clear()
      ..add(
        Club(
          id: 'tag-search-club',
          name: 'Campus Creators',
          description: 'A club for campus activities.',
          adminUserIds: const [],
        ),
      );
    events
      ..clear()
      ..addAll([
        Event(
          id: 'tag-search-match',
          clubId: 'tag-search-club',
          title: 'Thursday Gathering',
          description: 'Join us for an evening activity.',
          dateTime: start,
          endTime: start.add(const Duration(hours: 2)),
          location: 'Student Center',
          attendeeUserIds: const [],
          tags: const ['Hackathon', 'Free Food'],
        ),
        Event(
          id: 'tag-search-other',
          clubId: 'tag-search-club',
          title: 'Board Games Night',
          description: 'A relaxed evening of games.',
          dateTime: start.add(const Duration(days: 1)),
          endTime: start.add(const Duration(days: 1, hours: 2)),
          location: 'Student Lounge',
          attendeeUserIds: const [],
          tags: const ['Games'],
        ),
      ]);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ThisWeekScreen(),
        ),
      ),
    );
    await tester.pump();

    final search = find.widgetWithText(
      TextField,
      'Search events, clubs, topics',
    );

    await tester.enterText(search, 'HACKATHON');
    await tester.pump();
    expect(find.text('Thursday Gathering'), findsOneWidget);
    expect(find.text('Board Games Night'), findsNothing);

    await tester.enterText(search, 'food');
    await tester.pump();
    expect(find.text('Thursday Gathering'), findsOneWidget);
    expect(find.text('Board Games Night'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
