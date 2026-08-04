import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/rsvp_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/rsvp_button.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('rsvp_motion_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('past events do not show an RSVP action', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: RsvpButton(
            eventId: 'past-event',
            color: Colors.red,
            isPast: true,
          ),
        ),
      ),
    );

    expect(find.text("Let's Go"), findsNothing);
    expect(find.text('Ended'), findsNothing);
    expect(find.text('This event has passed'), findsNothing);
    expect(find.byType(GestureDetector), findsNothing);
  });

  testWidgets('joining an event plays and settles the confirmation pulse', (
    tester,
  ) async {
    const testEmail = 'rsvp.motion@ku.edu.tr';
    const eventId = 'rsvp-motion-event';
    users.removeWhere((user) => user.email == testEmail);
    events.removeWhere((event) => event.id == eventId);
    expect(
      authService.signUp('RSVP Motion Tester', testEmail, '135790'),
      isTrue,
    );
    final event = Event(
      id: eventId,
      clubId: 'motion-test-club',
      title: 'Motion Test Event',
      description: 'Exercises RSVP confirmation motion.',
      dateTime: DateTime.now().add(const Duration(days: 1)),
      endTime: DateTime.now().add(const Duration(days: 1, hours: 1)),
      location: 'Campus',
      attendeeUserIds: const [],
    );
    events.add(event);
    addTearDown(() {
      rsvpStore.clear();
      events.removeWhere((event) => event.id == eventId);
      users.removeWhere((user) => user.email == testEmail);
    });

    rsvpStore.seed(event.id, false);
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: false,
                textScaler: TextScaler.noScaling,
              ),
              child: SizedBox(
                width: 400,
                child: RsvpButton(eventId: event.id, color: Colors.red),
              ),
            ),
          ),
        ),
      ),
    );

    rsvpStore.replaceForUser([event.id], authService.currentUser!.id);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));

    final activePulse = tester.widget<Transform>(
      find.byKey(const ValueKey('rsvp-confirmation-pulse')),
    );
    expect(activePulse.transform.getMaxScaleOnAxis(), greaterThan(1));
    // The joined slot is cancel-only — the pulse is the confirmation, so there
    // is no separate "you're going" affirmation to assert on.
    expect(find.text('Cancel'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    final settledPulse = tester.widget<Transform>(
      find.byKey(const ValueKey('rsvp-confirmation-pulse')),
    );
    expect(settledPulse.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
    expect(tester.takeException(), isNull);
  });
}
