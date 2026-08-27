import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/student_connections_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/club_profile_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final alice = User(
    id: 'connections-alice',
    name: 'Alice Student',
    email: 'alice@ku.edu.tr',
    password: '',
    role: 'student',
    subscribedClubIds: [],
  );
  final bora = User(
    id: 'connections-bora',
    name: 'Bora Student',
    email: 'bora@ku.edu.tr',
    password: '',
    role: 'student',
    subscribedClubIds: [],
  );

  Widget app(Widget home) => ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  testWidgets('search persists while switching between all three sections', (
    tester,
  ) async {
    User? opened;
    final robotics = Club(
      id: 'connections-bora-robotics',
      name: 'Bora Robotics',
      description: '',
      adminUserIds: const [],
    );
    await tester.pumpWidget(
      app(
        StudentConnectionsScreen(
          initialSection: StudentConnectionSection.followers,
          clubs: [robotics],
          followers: [alice, bora],
          following: [bora],
          clubColorFor: (_) => const Color(0xFF800020),
          clubSubtitleFor: (_) => 'Member',
          onOpenUser: (user) => opened = user,
        ),
      ),
    );

    expect(find.byKey(const ValueKey('student-connections-screen')), findsOne);
    expect(find.byType(ClubProfileSegmentedTabs), findsOne);
    expect(find.byType(ClubProfileSearchField), findsOne);
    expect(
      find.byKey(const ValueKey('student-person-result-connections-alice')),
      findsOne,
    );
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('student-person-result-connections-bora'),
            ),
          )
          .height,
      72,
    );
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Follow back'), findsNothing);
    final searchCard = find.ancestor(
      of: find.byKey(const ValueKey('student-connections-search')),
      matching: find.byType(ClubProfileCard),
    );
    expect(
      tester.getSize(searchCard),
      tester.getSize(find.byType(ClubProfileSegmentedTabs)),
    );

    final search = find.descendant(
      of: find.byKey(const ValueKey('student-connections-search')),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'bora');
    await tester.pump();

    expect(find.text('Alice Student'), findsNothing);
    expect(find.text('Bora Student'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('student-connections-tab-0')));
    await tester.pump();
    expect(find.text('Bora Robotics'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('student-connections-tab-2')));
    await tester.pump();
    expect(find.text('Bora Student'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);

    await tester.tap(find.text('Bora Student'));
    expect(opened, bora);
  });

  testWidgets('clubs use the flat Chats-style result rows', (tester) async {
    final robotics = Club(
      id: 'connections-robotics',
      name: 'KU Robotics',
      description: '',
      adminUserIds: const [],
    );
    final theatre = Club(
      id: 'connections-theatre',
      name: 'KU Theatre',
      description: '',
      adminUserIds: const [],
    );
    Club? opened;

    await tester.pumpWidget(
      app(
        StudentConnectionsScreen(
          initialSection: StudentConnectionSection.clubs,
          clubs: [robotics, theatre],
          followers: const [],
          following: const [],
          clubColorFor: (_) => const Color(0xFF800020),
          clubSubtitleFor: (_) => 'Member',
          onOpenClub: (club) => opened = club,
          onOpenUser: (_) {},
        ),
      ),
    );

    expect(find.byKey(const ValueKey('student-connections-screen')), findsOne);
    expect(
      tester
          .getSize(
            find.byKey(
              const ValueKey('student-club-result-connections-robotics'),
            ),
          )
          .height,
      64,
    );

    final search = find.descendant(
      of: find.byKey(const ValueKey('student-connections-search')),
      matching: find.byType(TextField),
    );
    await tester.enterText(search, 'theatre');
    await tester.pump();

    expect(find.text('KU Robotics'), findsNothing);
    expect(find.text('KU Theatre'), findsOneWidget);
    await tester.tap(find.text('KU Theatre'));
    expect(opened, theatre);
  });

  testWidgets('visited profile stats open three independent routes', (
    tester,
  ) async {
    await tester.pumpWidget(app(UserProfileScreen(user: alice)));
    await tester.pump();

    await tester.tap(find.text('CLUBS'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
    expect(
      tester
          .widget<ClubProfileSegmentedTabs>(
            find.byType(ClubProfileSegmentedTabs),
          )
          .index,
      0,
    );
    Navigator.of(tester.element(find.byType(StudentConnectionsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('FOLLOWING'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
    expect(
      tester
          .widget<ClubProfileSegmentedTabs>(
            find.byType(ClubProfileSegmentedTabs),
          )
          .index,
      2,
    );
    Navigator.of(tester.element(find.byType(StudentConnectionsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('FOLLOWERS'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
    expect(
      tester
          .widget<ClubProfileSegmentedTabs>(
            find.byType(ClubProfileSegmentedTabs),
          )
          .index,
      1,
    );
    expect(find.text('Follow'), findsNothing);
  });

  testWidgets('own profile stats open the same three independent routes', (
    tester,
  ) async {
    final me = User(
      id: 'connections-me',
      name: 'Current Student',
      email: 'current@ku.edu.tr',
      password: '246802',
      role: 'student',
      subscribedClubIds: const ['connections-club'],
    );
    final follower = User(
      id: 'connections-follower',
      name: 'Follower Student',
      email: 'follower@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
      followingUserIds: const ['connections-me'],
    );
    final followed = User(
      id: 'connections-followed',
      name: 'Followed Student',
      email: 'followed@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );
    final club = Club(
      id: 'connections-club',
      name: 'Connections Club',
      description: '',
      adminUserIds: const [],
    );
    final originalFollowedUsers = Set<String>.from(userState.followedUserIds);
    final originalFollowedClubs = Set<String>.from(userState.followedClubIds);
    users.addAll([me, follower, followed]);
    clubs.add(club);
    userState.followedUserIds.add(followed.id);
    userState.replaceFollowedClubs({club.id});
    authService.login(me.email, me.password);
    addTearDown(() {
      authService.logout();
      users.removeWhere(
        (user) =>
            user.id == me.id ||
            user.id == follower.id ||
            user.id == followed.id,
      );
      clubs.removeWhere((item) => item.id == club.id);
      userState.followedUserIds
        ..clear()
        ..addAll(originalFollowedUsers);
      userState.replaceFollowedClubs(originalFollowedClubs);
    });

    await tester.pumpWidget(app(const ProfileScreen()));
    await tester.pump(const Duration(milliseconds: 100));

    await tester.tap(find.text('CLUBS'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
    expect(
      tester
          .widget<ClubProfileSegmentedTabs>(
            find.byType(ClubProfileSegmentedTabs),
          )
          .index,
      0,
    );
    Navigator.of(tester.element(find.byType(StudentConnectionsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('FOLLOWING'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
    expect(
      tester
          .widget<ClubProfileSegmentedTabs>(
            find.byType(ClubProfileSegmentedTabs),
          )
          .index,
      2,
    );
    Navigator.of(tester.element(find.byType(StudentConnectionsScreen))).pop();
    await tester.pumpAndSettle();

    await tester.tap(find.text('FOLLOWERS'));
    await tester.pumpAndSettle();
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
    expect(
      tester
          .widget<ClubProfileSegmentedTabs>(
            find.byType(ClubProfileSegmentedTabs),
          )
          .index,
      1,
    );
  });
}
