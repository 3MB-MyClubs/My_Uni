import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
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
      authService.signUp('Design Tester', 'design.tester@ku.edu.tr', '135790'),
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

  testWidgets('peer profile renders the profile-menu frame', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await pumpPeerProfile(tester);

    // `header` — back chevron + the peer's handle as the title.
    expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
    expect(find.text('@elifd'), findsNWidgets(2)); // header title + hero handle

    // `profile-hero` — name, "Follows you" badge, bio, three stats.
    expect(find.text('Elif Demir'), findsOneWidget);
    expect(find.text(S.followsYou), findsOneWidget);
    expect(find.text('Rooftop regular. Vinyl collector.'), findsOneWidget);
    expect(find.text('CLUBS'), findsOneWidget);
    expect(find.text('FOLLOWING'), findsOneWidget);
    expect(find.text('FOLLOWERS'), findsOneWidget);

    // `actions` — Follow (filled, with the plus) beside Message.
    expect(find.byType(ProfileActionButton), findsNWidgets(2));
    expect(find.text('Follow back'), findsOneWidget);
    expect(find.text(S.message), findsOneWidget);
    expect(find.byIcon(Icons.add_rounded), findsOneWidget);

    // `mutual-clubs` — the club both students follow, with its member count.
    expect(find.text(S.mutualClubs), findsOneWidget);
    expect(find.text('Rooftop Collective'), findsOneWidget);
    expect(find.text('342 members'), findsOneWidget);

    expect(tester.takeException(), isNull);
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
