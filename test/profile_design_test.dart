import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/screens/student_connections_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/club_avatar.dart';
import 'package:flutter_application_1/widgets/profile_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// `profile-menu-light` / `profile-menu-dark` (Figma `241:6` / `241:113`) — a
/// student looking at another student's profile.
///
/// The mock directory ships empty (`users` is `[]`), so the session is
/// registered through `signUp` and the peer is cached directly rather than
/// signing in as a seeded student.
void main() {
  const clubId = 'profile-design-mutual-club';
  late Club club;
  late User peer;
  late String myId;
  late Directory tempDir;

  setUpAll(() async {
    // `signUp` writes the local user through PeopleService, which needs a box.
    tempDir = await Directory.systemTemp.createTemp('profile_design_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(false);
    await authService.logout();
    users.removeWhere((user) => user.email.endsWith('@ku.edu.tr'));
    clubs.removeWhere((item) => item.id == clubId);

    club = Club(
      id: clubId,
      name: 'Rooftop Collective',
      description: 'Sunset sessions every Thursday.',
      adminUserIds: const [],
    );
    clubs.add(club);
    supabaseClubMemberCounts[clubId] = 342;

    expect(
      // Eight digits, no adjacent repeated or sequential pair —
      // `isValidNewStudentPassword` rejects the six-digit form this fixture
      // used to pass, which is why every test in this file failed in setUp.
      authService.signUp(
        'Design Tester',
        'design.tester@ku.edu.tr',
        '13579024',
      ),
      isTrue,
    );
    myId = authService.currentUser!.id;
    userState.replaceFollowedClubs(const [clubId]);

    peer = User(
      id: 'profile-design-peer',
      name: 'Elif Demir',
      email: 'elifd@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [clubId],
      // The "Follows you" badge reads this list.
      followingUserIds: [myId],
    );
    peopleService.cacheRegisteredUser(peer);
    userState.setBio(peer.id, 'Rooftop regular. Vinyl collector.');
  });

  tearDown(() async {
    await authService.logout();
    userState.replaceFollowedClubs(const []);
    supabaseClubMemberCounts.remove(clubId);
    clubs.removeWhere((item) => item.id == clubId);
  });

  Future<void> pumpPeerProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: UserProfileScreen(user: peer),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('peer profile renders the New Profile frame', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await pumpPeerProfile(tester);

    // `header` 725:119 — the back circle alone. The redesign drops the
    // `@handle` title, and no other surface on the screen shows a handle.
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.text('@elifd'), findsNothing);

    // `profile-hero` 725:132 — name, "Follows you" badge, bio.
    expect(find.text('Elif Demir'), findsOneWidget);
    expect(find.text(S.followsYou), findsOneWidget);
    expect(find.text('Rooftop regular. Vinyl collector.'), findsOneWidget);

    // `stats` 725:147 — the three-cell row collapsed into one plain line, so
    // the uppercase cell labels are gone and with them their tap targets.
    expect(find.text('CLUBS'), findsNothing);
    expect(find.text('FOLLOWING'), findsNothing);
    expect(find.text('FOLLOWERS'), findsNothing);
    final hero = tester.widget<ProfilePeerHero>(find.byType(ProfilePeerHero));
    expect(hero.statsLabel, S.profileStatsLine('0', '1', '1'));

    // `actions` 725:148 — Follow (filled, with the plus) beside Message.
    expect(find.byType(ProfileActionButton), findsNWidgets(2));
    expect(find.text('Follow back'), findsOneWidget);
    expect(find.text(S.message), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // `tabs` 725:157 is gone at the user's request — the Clubs/Events filter
    // it drew was dropped and only its hairline kept, so both sections show
    // at once and neither tab label is on screen.
    expect(find.text('Clubs'), findsNothing);
    expect(find.text('Events'), findsNothing);

    // `mutual-clubs` — the club both students follow.
    expect(find.text(S.mutualClubs), findsOneWidget);
    expect(find.text('Rooftop Collective'), findsOneWidget);
    expect(find.text('342 members'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the clubs panel caps at four and offers a "+N more" line', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    // Six mutual clubs: four cards, then a tile standing for the other two.
    final extraIds = <String>[];
    for (var i = 0; i < 5; i++) {
      final id = 'overflow-club-$i';
      extraIds.add(id);
      clubs.add(
        Club(
          id: id,
          name: 'Overflow Club $i',
          description: '',
          adminUserIds: const [],
        ),
      );
    }
    addTearDown(() => clubs.removeWhere((c) => extraIds.contains(c.id)));

    final allIds = [clubId, ...extraIds];
    peer = User(
      id: peer.id,
      name: peer.name,
      email: peer.email,
      password: '',
      role: 'student',
      subscribedClubIds: allIds,
      followingUserIds: [myId],
    );
    peopleService.cacheRegisteredUser(peer);
    userState.replaceFollowedClubs(allIds);

    await pumpPeerProfile(tester);

    expect(find.byType(ProfileClubList), findsOneWidget);
    final list = tester.widget<ProfileClubList>(find.byType(ProfileClubList));
    expect(list.entries, hasLength(kProfileClubsPreviewCount));
    expect(list.remaining, 2);
    expect(find.text(S.clubsMoreLine(2)), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('four clubs or fewer show no "+N more" line', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await pumpPeerProfile(tester);

    final list = tester.widget<ProfileClubList>(find.byType(ProfileClubList));
    expect(list.entries, hasLength(1));
    expect(list.remaining, 0);
    expect(find.text(S.clubsMoreLine(1)), findsNothing);
  });

  testWidgets('the clubs list is flat Chats-style rows, divider only', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    const secondId = 'profile-design-second-club';
    clubs.add(
      Club(
        id: secondId,
        name: 'KU Robotics',
        description: '',
        adminUserIds: const [],
      ),
    );
    addTearDown(() => clubs.removeWhere((c) => c.id == secondId));

    final allIds = [clubId, secondId];
    peer = User(
      id: peer.id,
      name: peer.name,
      email: peer.email,
      password: '',
      role: 'student',
      subscribedClubIds: allIds,
      followingUserIds: [myId],
    );
    peopleService.cacheRegisteredUser(peer);
    userState.replaceFollowedClubs(allIds);

    await pumpPeerProfile(tester);

    final first = find.byKey(const ValueKey('profile-club-row-$clubId'));
    final last = find.byKey(const ValueKey('profile-club-row-$secondId'));
    expect(first, findsOneWidget);
    expect(last, findsOneWidget);

    // The Chats inbox row: 64 tall, and the full width of the page column.
    // The bordered panel these rows used to sit in inset them by its own
    // 1px border, so the exact content width is what proves it is gone.
    expect(tester.getSize(first).height, 64);
    expect(tester.getSize(first).width, 393 - 2 * kProfilePagePadding);
    expect(tester.getSize(last).height, 64);

    // A 44pt round avatar, held off its own photo viewer so the row keeps the
    // tap — the same arrangement the Chats-style rows elsewhere use.
    final avatar = tester.widget<ClubAvatar>(
      find.descendant(of: first, matching: find.byType(ClubAvatar)),
    );
    expect(avatar.size, 44);
    expect(avatar.shape, 'circle');
    expect(
      find.ancestor(
        of: find.descendant(of: first, matching: find.byType(ClubAvatar)),
        matching: find.byType(IgnorePointer),
      ),
      findsWidgets,
    );

    // A hairline between the two rows and nothing after the last one.
    Border borderOf(Finder row) =>
        (tester
                    .widgetList<DecoratedBox>(
                      find.descendant(of: row, matching: find.byType(DecoratedBox)),
                    )
                    .first
                    .decoration
                as BoxDecoration)
            .border!
            as Border;
    expect(borderOf(first).bottom.color, ProfileColors.border);
    expect(borderOf(last).bottom.color, Colors.transparent);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the mini avatars open the directory, not the photo viewer', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    // A mutual: someone who follows the peer and whom the viewer follows too.
    final mutual = User(
      id: 'profile-design-mutual',
      name: 'Mutual Friend',
      email: 'mutual@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
      followingUserIds: [peer.id],
    );
    users.add(mutual);
    userState.replaceFollowedUsers([mutual.id]);
    addTearDown(() {
      users.removeWhere((u) => u.id == mutual.id);
      userState.replaceFollowedUsers(const []);
    });

    await pumpPeerProfile(tester);

    expect(find.byType(ProfileAvatarStack), findsOneWidget);

    // `UserAvatar` opens a full-screen photo viewer on tap for anyone who has
    // a photo, which would hijack this row for some people and not others.
    // The stack sits behind an IgnorePointer so the whole line stays one
    // target — tapping the avatars themselves must reach the directory.
    await tester.tap(find.byType(ProfileAvatarStack));
    await tester.pumpAndSettle();

    // Reaching the directory at all is the proof: had `UserAvatar`'s viewer
    // taken the tap, this route would never have been pushed.
    expect(find.byType(StudentConnectionsScreen), findsOneWidget);
  });

  testWidgets('overflow button opens the anchored Report / Ban menu', (
    tester,
  ) async {
    await pumpPeerProfile(tester);

    expect(find.text('Report user'), findsNothing);

    await tester.tap(find.bySemanticsLabel('Safety options'));
    await tester.pumpAndSettle();

    // `dropdown-menu`: the frame's rows are Report User and Ban User; a student
    // cannot ban, so the destructive row is the app's block-and-report action.
    expect(find.text('Report user'), findsOneWidget);
    expect(find.text('Block and report user'), findsOneWidget);
    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.byIcon(Icons.block_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an already-followed peer gets the outlined Following button', (
    tester,
  ) async {
    userState.followedUserIds.add(peer.id);
    addTearDown(() => userState.followedUserIds.remove(peer.id));

    await pumpPeerProfile(tester);

    expect(find.text('Following'), findsOneWidget);
    expect(find.text('Follow back'), findsNothing);
    // `btn-follow` only carries the plus while following is still the action
    // to take, and it stops being the filled button once you follow.
    expect(find.byIcon(Icons.add_rounded), findsNothing);
    final follow = tester.widget<ProfileActionButton>(
      find.byType(ProfileActionButton).first,
    );
    expect(follow.filled, isFalse);
  });
}
