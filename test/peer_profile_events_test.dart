import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/student_activity_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A visited student's profile lists what they are going to next, not just the
/// clubs they are in. The record comes from [StudentActivityService], which the
/// screen hydrates for whoever is being visited.
void main() {
  const clubId = 'peer-events-club';
  const eventId = 'peer-events-event';
  const hostedEventId = 'peer-events-hosted-event';
  late User signedInUser;
  late User visitedUser;

  setUp(() {
    clubs.add(
      Club(
        id: clubId,
        name: 'Peer Events Club',
        description: 'Backs the visited-profile events section.',
        adminUserIds: const [],
      ),
    );
    signedInUser = User(
      id: 'peer-events-me',
      name: 'Signed In Student',
      email: 'peer.events.me@ku.edu.tr',
      password: '246802',
      role: 'student',
      subscribedClubIds: const [clubId],
    );
    visitedUser = User(
      id: 'peer-events-them',
      name: 'Visited Student',
      email: 'peer.events.them@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [clubId],
    );
    users.addAll([signedInUser, visitedUser]);
    userState.replaceFollowedClubs(const [clubId]);
    authService.login(signedInUser.email, signedInUser.password);
  });

  tearDown(() {
    authService.logout();
    userState.replaceFollowedClubs(const []);
    studentActivityService.clearRemoteHistory();
    events.removeWhere((event) => event.id == eventId);
    users.removeWhere(
      (user) => user.id == signedInUser.id || user.id == visitedUser.id,
    );
    clubs.removeWhere((club) => club.id == clubId);
  });

  void addEvent({required bool visitedIsAttending}) {
    final start = DateTime.now().add(const Duration(days: 3));
    events.add(
      Event(
        id: eventId,
        clubId: clubId,
        title: 'Robotics Night',
        description: 'Backs the visited-profile events section.',
        dateTime: start,
        endTime: start.add(const Duration(hours: 2)),
        location: 'SOS B10',
        attendeeUserIds: visitedIsAttending ? [visitedUser.id] : [],
      ),
    );
  }

  /// An event at a club where the visited student sits on the board — what the
  /// section calls "Hosting Next" — happening *before* the one above.
  void addHostedEvent() {
    const hostedClubId = 'peer-events-board-club';
    final hostedClub = Club(
      id: hostedClubId,
      name: 'Board Club',
      description: 'The club this student helps run.',
      adminUserIds: const [],
    );
    hostedClub.boardMemberIds.add(visitedUser.id);
    hostedClub.boardMemberTitles[visitedUser.id] = 'President';
    clubs.add(hostedClub);
    final start = DateTime.now().add(const Duration(days: 1));
    events.add(
      Event(
        id: hostedEventId,
        clubId: hostedClubId,
        title: 'Board Briefing',
        description: 'Backs the hosting-does-not-hide test.',
        dateTime: start,
        endTime: start.add(const Duration(hours: 1)),
        location: 'CASE 27',
        attendeeUserIds: [visitedUser.id],
      ),
    );
    addTearDown(() {
      events.removeWhere((event) => event.id == hostedEventId);
      clubs.removeWhere((club) => club.id == hostedClubId);
    });
  }

  Future<void> pumpVisitedProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserProfileScreen(user: visitedUser),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('visited profile lists the events that student is going to', (
    tester,
  ) async {
    addEvent(visitedIsAttending: true);

    await pumpVisitedProfile(tester);

    expect(find.text('Robotics Night'), findsOneWidget);
  });

  testWidgets('visited profile shows no event the student is not going to', (
    tester,
  ) async {
    addEvent(visitedIsAttending: false);

    await pumpVisitedProfile(tester);

    expect(find.text('Robotics Night'), findsNothing);
    // Said out loud rather than drawn as a blank: an empty record and a record
    // that never loaded must not look the same.
    expect(find.text(S.noUpcomingEvents), findsOneWidget);
  });

  testWidgets('an event they host does not hide one they are going to', (
    tester,
  ) async {
    addEvent(visitedIsAttending: true);
    addHostedEvent();

    await pumpVisitedProfile(tester);

    expect(find.text('Board Briefing'), findsOneWidget);
    expect(find.text('Robotics Night'), findsOneWidget);
  });
}
