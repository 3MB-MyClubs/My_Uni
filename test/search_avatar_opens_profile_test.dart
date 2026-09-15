import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/club_avatar.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In Search, a row's picture goes where the row goes.
///
/// [UserAvatar] and [ClubAvatar] each open the full-screen photo viewer from
/// their own `GestureDetector`, but **only for someone who has actually
/// uploaded a picture** — an initials avatar draws no detector at all. So the
/// bug was intermittent by person: the same tap reached the profile for one
/// student and the photo viewer for the next. Every fixture here therefore
/// carries a real photo URL; without one these tests pass against the bug.
void main() {
  const viewerId = 'search-avatar-viewer';
  const peerId = 'search-avatar-peer';
  const clubId = 'search-avatar-club';
  const photo = 'https://example.com/search-avatar.jpg';

  setUp(() async {
    authService.logout();
    await localeService.setLanguage('en');

    users.add(
      User(
        id: viewerId,
        name: 'Search Viewer',
        email: 'search.avatar.viewer@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    peopleService.cacheRegisteredUser(
      User(
        id: peerId,
        name: 'Zenith Photographer',
        email: 'zenith.photographer@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    clubs.add(
      Club(
        id: clubId,
        name: 'Zenith Rooftop Society',
        description: '',
        logoUrl: photo,
        adminUserIds: const [],
      ),
    );
    userState.remotePhotoUrls[peerId] = photo;

    expect(
      authService.login('search.avatar.viewer@ku.edu.tr', '135790'),
      isTrue,
    );
    userState.replaceFollowedClubs(const []);
    userState.replaceFollowedUsers(const []);
  });

  tearDown(() {
    authService.logout();
    userState.remotePhotoUrls.remove(peerId);
    userState.replaceFollowedClubs(const []);
    userState.replaceFollowedUsers(const []);
    users.removeWhere((user) => user.id == viewerId);
    clubs.removeWhere((club) => club.id == clubId);
  });

  Future<void> pumpSearch(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ExploreScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// A photo viewer route would cover the search screen without ever mounting
  /// a profile, so arriving at one is proof the picture did not take the tap.
  Future<void> settleRoute(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets("a student's photo in the results opens their profile", (
    tester,
  ) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'Zenith Photographer');
    await tester.pump();

    // The search field carries the query text too, hence findsWidgets.
    expect(find.text('Zenith Photographer'), findsWidgets);
    final avatar = find.byType(UserAvatar);
    expect(avatar, findsOneWidget);

    // Tap the point the picture occupies rather than the widget: the avatar
    // deliberately answers no hit test of its own now, and this is the gesture
    // a person actually makes.
    await tester.tapAt(tester.getCenter(avatar));
    await settleRoute(tester);

    expect(find.byType(UserProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a club's logo in the results opens the club profile", (
    tester,
  ) async {
    await pumpSearch(tester);
    await tester.enterText(find.byType(TextField), 'Zenith Rooftop');
    await tester.pump();

    expect(find.text('Zenith Rooftop Society'), findsOneWidget);
    final avatar = find.byType(ClubAvatar);
    expect(avatar, findsOneWidget);

    await tester.tapAt(tester.getCenter(avatar));
    await settleRoute(tester);

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets("a trending card's logo opens the club profile", (tester) async {
    await pumpSearch(tester);

    // No query: the discovery list, where the club is a card in the trending
    // rail rather than a row.
    final card = find.ancestor(
      of: find.text('Zenith Rooftop Society'),
      matching: find.byType(GestureDetector),
    );
    expect(card, findsWidgets);
    final avatar = find
        .descendant(of: card.first, matching: find.byType(ClubAvatar))
        .first;

    await tester.tapAt(tester.getCenter(avatar));
    await settleRoute(tester);

    expect(find.byType(ClubProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
