import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/student_profile_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/profile_design.dart';
import 'package:flutter_application_1/widgets/student_campus_profile.dart';

void main() {
  testWidgets('club role badges stay readable in light and dark modes', (
    tester,
  ) async {
    addTearDown(() => themeService.setDark(false));

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await themeService.setDark(brightness == Brightness.dark);

      for (final role in ['Member', 'Founder', 'President']) {
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(brightness: brightness),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ColoredBox(
                color: StudentCampusPalette.solid,
                child: StudentClubRoleBadge(role: role),
              ),
            ),
          ),
        );
        await tester.pump();

        final badge = find.byType(StudentClubRoleBadge);
        final container = tester.widget<Container>(
          find.descendant(of: badge, matching: find.byType(Container)),
        );
        final decoration = container.decoration! as BoxDecoration;
        final label = tester.widget<Text>(find.text(role));
        final foreground = label.style!.color!;
        final background = Color.alphaBlend(
          decoration.color!,
          StudentCampusPalette.solid,
        );

        expect(
          _contrastRatio(foreground, background),
          greaterThanOrEqualTo(4.5),
          reason: '$role must remain readable in ${brightness.name} mode',
        );
      }
    }
  });

  testWidgets('blank bios are omitted from student profiles', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StudentProfileScreen(
            onSettings: () {},
            data: const StudentProfileData(
              userId: 'blank-bio-test',
              initials: 'S',
              name: 'Student',
              email: 'student@ku.edu.tr',
              graduation: '',
              major: '',
              year: '',
              bio: '   ',
              clubs: 0,
              following: 0,
              followers: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    // `profile-hero` drops the bio line entirely rather than printing a
    // placeholder, so nothing sits between the name and the stats row.
    expect(find.text('   '), findsNothing);
    expect(find.text('BIO'), findsNothing);
    expect(find.text('No bio yet.'), findsNothing);
    expect(find.text('Add a bio…'), findsNothing);
    expect(find.text('Student'), findsOneWidget);
    expect(find.text('@student'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student profile keeps the club loading state visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: StudentProfileScreen(
            onSettings: () {},
            clubsLoading: true,
            data: const StudentProfileData(
              userId: 'clubs-loading-test',
              initials: 'S',
              name: 'Student',
              graduation: '',
              major: '',
              year: '',
              bio: '',
              clubs: 0,
              following: 0,
              followers: 0,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('profile-clubs-loading')), findsOneWidget);
    expect(find.text(S.noClubsYetLine), findsNothing);
  });

  testWidgets(
    'student profile renders the profile-screen frame at phone width',
    (tester) async {
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
                  StudentClubDetail(
                    club: music,
                    memberCount: 68,
                    role: 'Member',
                  ),
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

      // `header` + `profile-hero`.
      final wordmark = find.byKey(const ValueKey('profile-clubup-logo'));
      expect(wordmark, findsOneWidget);
      expect(find.text('ClubUp'), findsOneWidget);
      final wordmarkSpan = tester.widget<Text>(wordmark).textSpan! as TextSpan;
      final wordmarkSpans = wordmarkSpan.children!;
      expect((wordmarkSpans[0] as TextSpan).style!.color, ProfileColors.accent);
      expect((wordmarkSpans[1] as TextSpan).style!.color, ProfileColors.text);
      expect(find.text('Hakan Tuncay'), findsOneWidget);
      expect(find.text('@htuncay23'), findsNothing);
      expect(
        find.text('Robotics builder and occasional jazz listener.'),
        findsOneWidget,
      );
      expect(find.text('CLUBS'), findsOneWidget);
      expect(find.text('FOLLOWING'), findsOneWidget);
      expect(find.text('FOLLOWERS'), findsOneWidget);

      // `my-clubs-section` + `events-section`.
      expect(find.text('My Clubs'), findsOneWidget);
      expect(find.text('KU Robotics'), findsOneWidget);
      expect(find.text('Drama & Theatre'), findsOneWidget);
      expect(find.text('84 members'), findsOneWidget);
      expect(find.text('Upcoming events'), findsOneWidget);

      // Stripped to the frame: no campus ID card, no role badges, no academic
      // block — the handoff puts academic info on `profile-edit` instead.
      expect(find.byType(StudentCampusIdCard), findsNothing);
      expect(find.text('STUDENT ID'), findsNothing);
      expect(find.text('Minor in Physics'), findsNothing);
      expect(find.byType(StudentClubRoleBadge), findsNothing);
      expect(tester.takeException(), isNull);

      await tester.tap(find.bySemanticsLabel('Share profile'));
      await tester.tap(find.bySemanticsLabel('Settings'));
      expect(shared, isTrue);
      expect(openedSettings, isTrue);
    },
  );

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

    // Stripped to `profile-menu`: no campus ID card, no role badges.
    expect(find.byType(StudentCampusIdCard), findsNothing);
    expect(find.text('STUDENT ID'), findsNothing);
    expect(find.text(profileHandle(student.email)), findsWidgets);
    expect(find.text('CLUBS'), findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // Visited profiles show Follow + Message side by side.
    expect(find.byType(ProfileActionButton), findsNWidgets(2));
    expect(find.text(S.message), findsOneWidget);
    // The role-first club union still puts the board-role club first.
    expect(find.text(roleOnlyClub.name), findsOneWidget);

    await tester.tap(find.text(S.message));
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

    // `my-clubs-section` renders that union; the role badge the old campus
    // card carried is not part of the frame.
    expect(find.text(roleOnlyClub.name), findsOneWidget);
    expect(find.text('President'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the board badge opens the board-memberships overlay', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final rooftop = Club(
      id: 'board-rooftop',
      name: 'Rooftop Collective',
      description: 'Sunset sessions every Thursday.',
      adminUserIds: const [],
    );
    final arts = Club(
      id: 'board-arts',
      name: 'Underground Arts',
      description: 'Basement gigs and gallery nights.',
      adminUserIds: const [],
    );
    final followedOnly = Club(
      id: 'board-zen',
      name: 'Zen Movement',
      description: 'Morning stretch on the lawn.',
      adminUserIds: const [],
    );
    Club? openedClub;

    Widget profile(List<StudentClubDetail> details) => ProviderScope(
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: StudentProfileScreen(
          onSettings: () {},
          onClubTap: (club) => openedClub = club,
          data: StudentProfileData(
            userId: 'board-badge-test',
            initials: 'HE',
            name: 'Hakan Erdogan',
            email: 'hakan.erdogan@ku.edu.tr',
            graduation: '',
            major: '',
            year: '',
            bio: 'Adventure seeker.',
            clubs: details.length,
            followers: 89,
            following: 156,
            clubDetails: details,
          ),
        ),
      ),
    );

    // A student with no board seat gets no badge at all.
    await tester.pumpWidget(
      profile([StudentClubDetail(club: followedOnly, memberCount: 89)]),
    );
    await tester.pump();
    expect(find.byType(ProfileRolePill), findsNothing);

    await tester.pumpWidget(
      profile([
        StudentClubDetail(
          club: rooftop,
          memberCount: 342,
          role: 'President',
          boardRole: 'President',
        ),
        StudentClubDetail(
          club: arts,
          memberCount: 128,
          role: 'Treasurer',
          boardRole: 'Treasurer',
        ),
        StudentClubDetail(club: followedOnly, memberCount: 89),
      ]),
    );
    await tester.pump();

    // `board-badge` sits between the name and the bio, and titles stay in the
    // overlay rather than on the page.
    expect(find.text('Board Member'), findsOneWidget);
    expect(find.text('President'), findsNothing);

    await tester.tap(find.text('Board Member'));
    await tester.pumpAndSettle();

    // `board-memberships-overlay`: one row per seat, follower-only clubs out.
    expect(find.text('Board Memberships'), findsOneWidget);
    expect(find.text('Rooftop Collective'), findsWidgets);
    expect(find.text('President'), findsOneWidget);
    expect(find.text('Treasurer'), findsOneWidget);
    expect(find.text('342 members'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Zen Movement'),
      ),
      findsNothing,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text('Underground Arts'),
      ),
    );
    await tester.pumpAndSettle();

    expect(openedClub?.id, arts.id);
    expect(find.text('Board Memberships'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

double _contrastRatio(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
