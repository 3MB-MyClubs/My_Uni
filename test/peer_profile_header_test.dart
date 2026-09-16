import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/profile_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The visited profile's header floats over the list: it keeps its place while
/// the page scrolls under it, and the strip it sits in is not a pointer barrier
/// — a drag that starts up there still scrolls the profile.
void main() {
  const clubId = 'peer-header-club';
  late User signedInUser;
  late User visitedUser;

  setUp(() {
    clubs.add(
      Club(
        id: clubId,
        name: 'Header Club',
        description: 'Backs the floating-header test.',
        adminUserIds: const [],
      ),
    );
    signedInUser = User(
      id: 'peer-header-me',
      name: 'Signed In Student',
      email: 'peer.header.me@ku.edu.tr',
      password: '246802',
      role: 'student',
      subscribedClubIds: const [clubId],
    );
    visitedUser = User(
      id: 'peer-header-them',
      name: 'Visited Student',
      email: 'peer.header.them@ku.edu.tr',
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
    users.removeWhere(
      (user) => user.id == signedInUser.id || user.id == visitedUser.id,
    );
    clubs.removeWhere((club) => club.id == clubId);
  });

  Future<void> pumpVisitedProfile(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(393, 852);
    tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
    tester.view.viewPadding = const FakeViewPadding(top: 47, bottom: 34);
    addTearDown(tester.view.reset);

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

  testWidgets('the header holds the top while the profile scrolls under it', (
    tester,
  ) async {
    await pumpVisitedProfile(tester);

    final headerFinder = find.byType(ProfileBackHeader);
    final heroFinder = find.byType(ProfilePeerHero);
    final headerBefore = tester.getRect(headerFinder);
    final heroBefore = tester.getRect(heroFinder);

    // Nothing starts life under the glyphs: the hero clears the header.
    expect(heroBefore.top, greaterThanOrEqualTo(headerBefore.bottom));

    // From open page, below the header — a plain scroll drag.
    await tester.dragFrom(const Offset(196, 600), const Offset(0, -160));
    await tester.pump();

    expect(tester.getRect(headerFinder), headerBefore);
    expect(tester.getRect(heroFinder).top, lessThan(heroBefore.top));
  });

  testWidgets('a drag that starts in the header strip still scrolls', (
    tester,
  ) async {
    await pumpVisitedProfile(tester);

    final heroTop = tester.getRect(find.byType(ProfilePeerHero)).top;
    final header = tester.getRect(find.byType(ProfileBackHeader));

    // Between the two buttons, where only the gradient is painted.
    await tester.dragFrom(header.center, const Offset(0, -160));
    await tester.pump();

    expect(tester.getRect(find.byType(ProfilePeerHero)).top, lessThan(heroTop));
  });
}
