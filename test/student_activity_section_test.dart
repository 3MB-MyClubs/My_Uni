import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/screens/student_activity_screen.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/services/checkin_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/student_activity_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _studentId = 'student-activity-test';

Club _club(String id, String name) =>
    Club(id: id, name: name, description: name, adminUserIds: const []);

Event _event({
  required String id,
  required String clubId,
  required String title,
  required DateTime start,
  Duration length = const Duration(hours: 2),
  List<String> attendees = const [_studentId],
}) => Event(
  id: id,
  clubId: clubId,
  title: title,
  description: title,
  dateTime: start,
  endTime: start.add(length),
  location: 'SOS B10',
  attendeeUserIds: List<String>.from(attendees),
);

/// Installs a two-club, three-event record for [_studentId]: one upcoming
/// RSVP, one past event they were scanned into, and one past event nobody
/// scanned. Restores the global lists afterwards.
void _seedRecord(DateTime now) {
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

  clubs
    ..clear()
    ..addAll([_club('robotics', 'KU Robotics'), _club('jazz', 'Jazz Society')]);

  events
    ..clear()
    ..addAll([
      _event(
        id: 'ev-upcoming',
        clubId: 'robotics',
        title: 'Line-Follower Workshop',
        start: now.add(const Duration(days: 6)),
      ),
      _event(
        id: 'ev-attended',
        clubId: 'jazz',
        title: 'Open-Air Jazz Night',
        start: now.subtract(const Duration(days: 20)),
      ),
      _event(
        id: 'ev-unscanned',
        clubId: 'robotics',
        title: 'Arduino 101',
        start: now.subtract(const Duration(days: 90)),
      ),
      // Someone else's event — must never reach this student's record.
      _event(
        id: 'ev-other',
        clubId: 'jazz',
        title: 'Someone Else Only',
        start: now.subtract(const Duration(days: 3)),
        attendees: const ['other-student'],
      ),
    ]);
}

Widget _hostProfile() => ProviderScope(
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: StudentProfileScreen(
      onSettings: () {},
      data: const StudentProfileData(
        userId: _studentId,
        initials: 'HT',
        name: 'Hakan Tuncay',
        email: 'htuncay23@ku.edu.tr',
        graduation: "Class of '27",
        major: 'Computer Engineering',
        year: "Class of '27",
        bio: 'Robotics builder.',
        clubs: 2,
        followers: 4,
        following: 6,
      ),
    ),
  ),
);

void main() {
  /// Records a door scan through the real store. Seed events use non-UUID
  /// ids, so the write stays local and never reaches Supabase.
  Future<void> scanIn(String eventId) async {
    await checkinStore.toggle(
      eventId: eventId,
      userId: _studentId,
      actorId: 'door-staff',
    );
    addTearDown(() async {
      if (checkinStore.isCheckedIn(eventId, _studentId)) {
        await checkinStore.toggle(
          eventId: eventId,
          userId: _studentId,
          actorId: 'door-staff',
        );
      }
    });
  }

  setUp(() async {
    _seedRecord(DateTime.now());
    await scanIn('ev-attended');
  });

  test('summary splits an RSVP record into upcoming and past', () {
    final summary = studentActivityService.summaryFor(_studentId);

    expect(summary.total, 3);
    expect(summary.upcoming.map((e) => e.eventId), ['ev-upcoming']);
    expect(summary.past.map((e) => e.eventId), ['ev-attended', 'ev-unscanned']);
    // Only the scanned one counts as confirmed attendance.
    expect(summary.attendedCount, 1);
    expect(summary.past.first.checkedIn, isTrue);
    expect(summary.past.last.isUnconfirmed, isTrue);
    expect(summary.clubCount, 2);
  });

  test('a walk-in scan without an RSVP still lands on the record', () async {
    await scanIn('ev-other');

    final summary = studentActivityService.summaryFor(_studentId);
    final walkIn = summary.past.firstWhere((e) => e.eventId == 'ev-other');

    expect(walkIn.rsvped, isFalse);
    expect(walkIn.checkedIn, isTrue);
  });

  test('an in-progress event sorts ahead of everything upcoming', () {
    final now = DateTime.now();
    events.add(
      _event(
        id: 'ev-live',
        clubId: 'jazz',
        title: 'Happening Right Now',
        start: now.subtract(const Duration(minutes: 30)),
      ),
    );

    final summary = studentActivityService.summaryFor(_studentId);
    expect(summary.upcoming.first.eventId, 'ev-live');
    expect(summary.upcoming.first.isLive, isTrue);
  });

  test('academic years run September to August', () {
    expect(academicYearLabel(DateTime(2025, 9, 1)), '2025–26');
    expect(academicYearLabel(DateTime(2026, 8, 31)), '2025–26');
    expect(academicYearLabel(DateTime(2026, 9, 1)), '2026–27');
  });

  testWidgets('the profile shows going and been-there events', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_hostProfile());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('EVENTS & ACTIVITIES'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('GOING · 1'), findsOneWidget);
    expect(find.text('BEEN THERE · 2'), findsOneWidget);
    expect(find.text('Line-Follower Workshop'), findsOneWidget);
    expect(find.text('Open-Air Jazz Night'), findsOneWidget);
    expect(find.text('Going'), findsOneWidget);
    expect(find.text('Attended'), findsOneWidget);
    expect(find.text('Not scanned'), findsOneWidget);
    expect(find.text('Someone Else Only'), findsNothing);
    expect(find.text('See all 3'), findsOneWidget);
    expect(
      find.text('Attendance is confirmed by event check-in'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('See all opens the full history with filters', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_hostProfile());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('See all 3'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('See all 3'));
    await tester.pumpAndSettle();

    expect(find.byType(StudentActivityScreen), findsOneWidget);
    expect(find.text('Events & activities'), findsOneWidget);
    expect(find.text('Visible on your public profile'), findsOneWidget);
    expect(find.text('All 3'), findsOneWidget);
    expect(find.text('Upcoming 1'), findsOneWidget);
    expect(find.text('Past 2'), findsOneWidget);

    await tester.tap(find.text('Upcoming 1'));
    await tester.pump();

    expect(find.text('Line-Follower Workshop'), findsOneWidget);
    expect(find.text('Open-Air Jazz Night'), findsNothing);

    await tester.tap(find.text('Past 2'));
    await tester.pump();

    expect(find.text('Line-Follower Workshop'), findsNothing);
    expect(find.text('Open-Air Jazz Night'), findsOneWidget);
    expect(find.text('Arduino 101'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty record invites the student to browse events', (
    tester,
  ) async {
    events.clear();

    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_hostProfile());
    await tester.pump();

    await tester.scrollUntilVisible(
      find.text('No events yet'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    expect(find.text('No events yet'), findsOneWidget);
    expect(find.text("Browse this week's events"), findsOneWidget);
    expect(find.text('See all 0'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
