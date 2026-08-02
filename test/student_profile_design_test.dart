import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/student_campus_profile.dart';

void main() {
  testWidgets('blank bios are omitted from student profiles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: StudentCampusProfileView(
            profile: const StudentCampusProfile(
              userId: 'blank-bio-test',
              name: 'Student',
              email: 'student@ku.edu.tr',
              major: '',
              year: '',
              bio: '   ',
              clubs: 0,
              following: 0,
              followers: 0,
            ),
            title: 'Student Profile',
            leading: const SizedBox.shrink(),
            trailing: const SizedBox.shrink(),
            memberships: const [],
            clubsTitle: 'Clubs',
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('BIO'), findsNothing);
    expect(find.text('No bio yet.'), findsNothing);
    expect(find.text('Add a bio…'), findsNothing);
  });

  testWidgets('student profile renders the Campus ID design at phone width', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final robotics = Club(
      id: 'robotics',
      name: 'KU Robotics',
      description: 'Student robotics club',
      adminUserIds: const [],
    );
    final theatre = Club(
      id: 'theatre',
      name: 'Drama & Theatre',
      description: 'Student theatre club',
      adminUserIds: const [],
    );
    final music = Club(
      id: 'music',
      name: 'Music Collective',
      description: 'Student music club',
      adminUserIds: const [],
    );
    final astronomy = Club(
      id: 'astronomy',
      name: 'KU Astronomy',
      description: 'Student astronomy club',
      adminUserIds: const [],
    );
    var shared = false;
    var openedSettings = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StudentProfileScreen(
            onShare: () => shared = true,
            onSettings: () => openedSettings = true,
            data: StudentProfileData(
              userId: 'student-design-test',
              initials: 'HT',
              name: 'Hakan Tuncay',
              email: 'htuncay23@ku.edu.tr',
              graduation: "Class of '27",
              major: 'Computer Engineering',
              year: "Class of '27",
              bio: 'Robotics builder and occasional jazz listener.',
              clubs: 4,
              followers: 31,
              following: 12,
              minors: const ['Physics'],
              clubDetails: [
                StudentClubDetail(
                  club: robotics,
                  memberCount: 84,
                  role: 'Member',
                ),
                StudentClubDetail(
                  club: theatre,
                  memberCount: 42,
                  role: 'Founder',
                ),
                StudentClubDetail(club: music, memberCount: 68, role: 'Member'),
                StudentClubDetail(
                  club: astronomy,
                  memberCount: 36,
                  role: 'Member',
                ),
              ],
            ),
            followedClubs: [robotics, theatre, music, astronomy],
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(StudentCampusIdCard), findsOneWidget);
    expect(find.text('STUDENT ID'), findsOneWidget);
    expect(find.text('Hakan Tuncay'), findsOneWidget);
    expect(find.text('Minor in Physics'), findsOneWidget);
    expect(find.text('MY CLUBS'), findsOneWidget);
    expect(find.text('KU Robotics'), findsOneWidget);
    expect(find.text('Drama & Theatre'), findsOneWidget);
    expect(find.byType(StudentClubRoleBadge), findsNWidgets(4));
    expect(find.text('Founder'), findsOneWidget);
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.bySemanticsLabel('Share profile'));
    await tester.tap(find.bySemanticsLabel('Settings'));
    expect(shared, isTrue);
    expect(openedSettings, isTrue);
  });

  testWidgets('visited student profile shares the design without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(authService.logout);

    authService.login(users.first.email, users.first.password);
    final student = users.firstWhere((user) => user.id == 'u2');
    final roleOnlyClub = clubs.firstWhere(
      (club) => !student.subscribedClubIds.contains(club.id),
    );
    final originalBoardIds = List<String>.from(roleOnlyClub.boardMemberIds);
    final originalTitles = Map<String, String>.from(
      roleOnlyClub.boardMemberTitles,
    );
    addTearDown(() {
      roleOnlyClub.boardMemberIds
        ..clear()
        ..addAll(originalBoardIds);
      roleOnlyClub.boardMemberTitles
        ..clear()
        ..addAll(originalTitles);
    });
    roleOnlyClub.boardMemberIds.add(student.id);
    roleOnlyClub.boardMemberTitles[student.id] = 'President';
    userState.setMajor(
      student.id,
      'Electrical & Electronics Engineering and Computer Science',
    );
    userState.setYear(student.id, '3rd Year');
    userState.setBio(student.id, 'Building things with the robotics team.');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserProfileScreen(user: student),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(StudentCampusIdCard), findsOneWidget);
    expect(find.text('Student Profile'), findsOneWidget);
    expect(find.text('STUDENT ID'), findsOneWidget);
    expect(find.text('CLUBS · 6'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    // Visited profiles show Follow + Message side by side.
    expect(find.byType(StudentProfilePrimaryButton), findsNWidgets(2));
    expect(find.text('Message'), findsOneWidget);
    final profileView = tester.widget<StudentCampusProfileView>(
      find.byType(StudentCampusProfileView),
    );
    expect(profileView.profile.clubs, 6);
    expect(profileView.memberships.first.club.id, roleOnlyClub.id);
    expect(profileView.memberships.first.role, 'President');
    expect(find.text('President'), findsOneWidget);
    expect(find.byIcon(Icons.workspace_premium_rounded), findsOneWidget);
    expect(
      profileView.memberships.where((item) => item.club.id == roleOnlyClub.id),
      hasLength(1),
    );

    await tester.tap(find.text('Message'));
    await tester.pumpAndSettle();

    final chat = tester.widget<ChatThreadScreen>(find.byType(ChatThreadScreen));
    expect(chat.recipient?.id, student.id);
    expect(chat.threadId, 'dm:u1|u2');
    expect(find.text('Can Serbester'), findsOneWidget);
    expect(find.text('Student profile'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('own profile uses the same role-first club union', (
    tester,
  ) async {
    addTearDown(authService.logout);
    authService.login(users.first.email, users.first.password);
    final student = users.first;
    final originalFollowedIds = Set<String>.from(userState.followedClubIds);
    final roleOnlyClub = clubs.firstWhere((club) => club.id == 'c2');
    final originalBoardIds = List<String>.from(roleOnlyClub.boardMemberIds);
    final originalTitles = Map<String, String>.from(
      roleOnlyClub.boardMemberTitles,
    );
    addTearDown(() {
      userState.replaceFollowedClubs(originalFollowedIds);
      roleOnlyClub.boardMemberIds
        ..clear()
        ..addAll(originalBoardIds);
      roleOnlyClub.boardMemberTitles
        ..clear()
        ..addAll(originalTitles);
    });

    userState.replaceFollowedClubs(['c4', 'c7']);
    roleOnlyClub.boardMemberIds.add(student.id);
    roleOnlyClub.boardMemberTitles[student.id] = 'President';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ProfileScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final profile = tester.widget<StudentProfileScreen>(
      find.byType(StudentProfileScreen),
    );
    expect(profile.data.clubs, 3);
    expect(profile.followedClubs.map((club) => club.id), ['c2', 'c4', 'c7']);
    expect(profile.data.clubDetails.first.club.id, roleOnlyClub.id);
    expect(profile.data.clubDetails.first.role, 'President');

    final profileView = tester.widget<StudentCampusProfileView>(
      find.byType(StudentCampusProfileView),
    );
    expect(profileView.memberships.first.club.id, roleOnlyClub.id);
    expect(profileView.memberships.first.role, 'President');
    expect(find.text('President'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
