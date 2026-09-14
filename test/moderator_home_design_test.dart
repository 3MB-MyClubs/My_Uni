import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/content_audience.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/content_visibility.dart';
import 'package:flutter_application_1/services/club_follow_helper.dart';
import 'package:flutter_application_1/services/guest_session.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_clubup_profile.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/widgets/club_home_design.dart';
import 'package:flutter_application_1/widgets/home_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tempDirectory;
  late AppAdmin moderator;
  const clubId = 'moderator-home-club';
  const postId = 'moderator-home-post';

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp(
      'moderator_home_design_test_',
    );
    Hive.init(tempDirectory.path);
    await contentStore.initialize();
    await viewTracker.initialize();
  });

  tearDownAll(() {
    if (tempDirectory.existsSync()) tempDirectory.deleteSync(recursive: true);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await authService.logout();
    await localeService.setLanguage('en');
    await themeService.setDark(false, persistToAccount: false);

    clubs.clear();
    newsPosts.clear();
    events.clear();
    comments.clear();

    moderator = AppAdmin(
      id: 'moderator-home-admin',
      name: 'ClubUp Moderator',
      email: 'moderator.home@clubup.app',
      password: '',
      isPlatformAdmin: true,
    );
    authService.setClubAdmin(moderator, checkTerms: false);

    clubs.add(
      Club(
        id: clubId,
        name: 'Campus Club',
        description: '',
        adminUserIds: const ['campus-club-admin'],
      ),
    );
    newsPosts.add(
      NewsPost(
        id: postId,
        clubId: clubId,
        authorId: 'campus-club-admin',
        content: 'A board-only post that the moderator can review.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        audience: ContentAudience.board,
      ),
    );
  });

  tearDown(() async {
    await authService.logout();
    clubs.clear();
    newsPosts.clear();
    events.clear();
    comments.clear();
  });

  Widget app(Widget home) => ProviderScope(
    child: MaterialApp(
      locale: Locale(localeService.languageCode),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );

  testWidgets(
    'platform moderator uses the standard Home UI without losing permissions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(393, 1200);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(app(const FeedScreen()));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byType(HomeFeedHeader), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-feed-scope-dropdown')),
        findsOneWidget,
      );
      expect(find.text('${S.hiPrefix} ClubUp'), findsOneWidget);
      expect(find.byType(ClubHomeComposerCard), findsNothing);
      expect(find.byKey(const ValueKey('home-feed-tab-0')), findsNothing);
      expect(find.byType(HomeFeedPostCard), findsOneWidget);
      expect(
        find.byKey(const ValueKey('home-post-follow-$clubId')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('moderator-home-post-menu-$postId')),
        findsOneWidget,
      );

      expect(isClubUpAdmin(authService.currentAdmin), isTrue);
      expect(canViewPost(newsPosts.single), isTrue);
      expect(contentStore.canDeletePost(postId, moderator.id), isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('platform moderator cannot trigger a club follow mutation', (
    tester,
  ) async {
    var changed = false;
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () =>
                  handleFollowTap(context, clubId, () => changed = true),
              child: const Text('Try follow'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Try follow'));
    await tester.pump();

    expect(canCurrentSessionFollowClubs, isFalse);
    expect(userState.isFollowing(clubId), isFalse);
    expect(changed, isFalse);
  });

  testWidgets('moderator can delete any post from its three-dot menu', (
    tester,
  ) async {
    await tester.pumpWidget(app(const FeedScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(
      find.byKey(const ValueKey('moderator-home-post-menu-$postId')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Delete post'), findsOneWidget);

    await tester.tap(find.text('Delete post'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);

    // Exercise the same local fallback used when the backend is unavailable;
    // this test process deliberately does not initialize a Supabase client.
    guestSession.begin();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(newsPosts, isEmpty);
    expect(find.byType(HomeFeedPostCard), findsNothing);
    expect(find.text('Post deleted'), findsOneWidget);
    guestSession.end();

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('ordinary club admins do not receive the global delete menu', (
    tester,
  ) async {
    await authService.logout();
    authService.setClubAdmin(
      AppAdmin(
        id: 'campus-club-admin',
        name: 'Campus Club',
        email: 'campus.club@ku.edu.tr',
        password: '',
      ),
      checkTerms: false,
    );

    await tester.pumpWidget(app(const FeedScreen()));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(HomeFeedPostCard), findsOneWidget);
    expect(
      find.byKey(const ValueKey('moderator-home-post-menu-$postId')),
      findsNothing,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('platform moderator keeps the Moderation navigation tab', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 900);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(app(const MainNavScreen(isAdmin: true)));
    await tester.pump();

    final navigation = find.byKey(const ValueKey('mobile-bottom-navigation'));
    expect(navigation, findsOneWidget);
    expect(
      find.descendant(of: navigation, matching: find.text(S.moderation)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: navigation,
        matching: find.byIcon(Icons.shield_outlined),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
