import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/comment.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/widgets/club_profile_design.dart';
import 'package:flutter_application_1/widgets/clubup_design.dart';
import 'package:flutter_application_1/widgets/home_comments_sheet.dart';
import 'package:flutter_application_1/widgets/home_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The redesigned student HOME area — `home-feed-alt`, `comments` and `share`
/// from the ClubUp-Desings handoff.
void main() {
  late Directory tempDir;
  const clubId = 'home-design-club';
  const postId = 'home-design-post-1';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('home_design_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await authService.logout();
    users.removeWhere((user) => user.email == 'home.design@ku.edu.tr');
    expect(
      authService.signUp('Hakan Design', 'home.design@ku.edu.tr', '135790'),
      isTrue,
    );
    userState.replaceLikedPosts(const []);
    likes.removeWhere((like) => like.postId == postId);
    supabasePostLikeCounts.remove(postId);
    clubs
      ..removeWhere((club) => club.id == clubId)
      ..add(
        Club(
          id: clubId,
          name: 'Design Society',
          description: 'HOME redesign fixture',
          adminUserIds: const [],
        ),
      );
    newsPosts
      ..clear()
      ..add(
        NewsPost(
          id: postId,
          clubId: clubId,
          authorId: 'home-design-author',
          content: 'Accessible colour palettes workshop next week!',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
      );
    events.clear();
    comments.clear();
  });

  tearDown(() async {
    clubs.removeWhere((club) => club.id == clubId);
    newsPosts.clear();
    comments.clear();
    await authService.logout();
  });

  Future<void> pumpHome(WidgetTester tester, {double height = 1200}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(393, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          // main.dart drives MaterialApp's locale from localeService, so the
          // test mirrors that: S.* and AppLocalizations must agree.
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FeedScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('student Home draws the header greeting and one post card', (
    tester,
  ) async {
    await pumpHome(tester);

    // `premium-header-container`
    final greeting = find.byKey(const ValueKey('home-header-greeting'));
    expect(greeting, findsOneWidget);
    expect(find.text('${S.hiPrefix} Hakan'), findsOneWidget);
    final greetingSpan = tester.widget<Text>(greeting).textSpan! as TextSpan;
    final greetingSpans = greetingSpan.children!;
    expect((greetingSpans[0] as TextSpan).style!.color, ClubUpColors.muted);
    expect((greetingSpans[1] as TextSpan).style!.color, ClubUpColors.text);
    final feedScope = find.byKey(const ValueKey('home-feed-scope-dropdown'));
    expect(feedScope, findsOneWidget);
    final headerRect = tester.getRect(find.byType(HomeFeedHeader));
    expect(tester.getCenter(feedScope).dx, closeTo(headerRect.center.dx, 0.5));
    expect(
      find.byKey(const ValueKey('home-notifications-bell')),
      findsOneWidget,
    );

    // The stripped-down feed: no events rail, no segmented pill, no composer.
    expect(find.byKey(const ValueKey('home-feed-tab-0')), findsNothing);
    expect(find.text(S.eventsOnCampus), findsNothing);

    // X-style feed row — full width, shared page surface, then a thin divider.
    final card = find.byKey(const ValueKey('home-post-card-$postId'));
    expect(card, findsOneWidget);
    final verifiedBadge = find.descendant(
      of: card,
      matching: find.byType(ClubVerifiedBadge),
    );
    expect(verifiedBadge, findsOneWidget);
    final verifiedIcon = tester.widget<Icon>(
      find.descendant(
        of: verifiedBadge,
        matching: find.byIcon(Icons.verified_rounded),
      ),
    );
    expect(verifiedIcon.color, const Color(0xFF800020));
    expect(tester.getSize(card).width, 393);
    final postContainer = tester.widget<Container>(card);
    final decoration = postContainer.decoration! as BoxDecoration;
    final foreground = postContainer.foregroundDecoration! as BoxDecoration;
    final divider = foreground.border! as Border;
    expect(postContainer.margin, EdgeInsets.zero);
    expect(decoration.color, ClubUpColors.background);
    expect(decoration.borderRadius, BorderRadius.zero);
    expect(divider.bottom.width, 2);
    expect(divider.bottom.color, ClubUpColors.text.withValues(alpha: 0.56));

    final actionsPanel = tester.widget<Container>(
      find.byKey(const ValueKey('home-post-actions-panel-$postId')),
    );
    final actionsBorder =
        (actionsPanel.decoration! as BoxDecoration).border! as Border;
    expect(actionsBorder.top.width, 0.5);
    expect(actionsBorder.top.color, ClubUpColors.text.withValues(alpha: 0.07));

    // `interaction-row`
    expect(
      find.byKey(const ValueKey('home-post-like-$postId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-post-comment-$postId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('home-post-share-$postId')),
      findsOneWidget,
    );
    final homeFollow = find.byKey(
      const ValueKey('home-post-follow-home-design-club'),
    );
    final followBox = tester.widget<AnimatedContainer>(
      find.descendant(of: homeFollow, matching: find.byType(AnimatedContainer)),
    );
    expect(
      (followBox.decoration! as BoxDecoration).color,
      const Color(0xFF800020),
    );
    expect(find.text(S.unfollow), findsNothing); // not following this club yet
    expect(tester.takeException(), isNull);
  });

  testWidgets('For You uses the foreground colour when Home theme changes', (
    tester,
  ) async {
    await themeService.setDark(false, persistToAccount: false);
    addTearDown(() => themeService.setDark(false, persistToAccount: false));
    await pumpHome(tester);

    final feedScope = find.byKey(const ValueKey('home-feed-scope-dropdown'));
    Text forYouLabel() => tester.widget<Text>(
      find.descendant(of: feedScope, matching: find.text(S.forYou)),
    );

    expect(forYouLabel().style?.color, const Color(0xFF18181B));
    expect(forYouLabel().style?.color, ClubUpColors.text);

    await themeService.setDark(true, persistToAccount: false);
    await tester.pump();

    expect(forYouLabel().style?.color, const Color(0xFFFAFAFA));
    expect(forYouLabel().style?.color, ClubUpColors.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo post puts the club above its caption below the image', (
    tester,
  ) async {
    newsPosts[0] = NewsPost(
      id: postId,
      clubId: clubId,
      authorId: 'home-design-author',
      content: 'A caption placed underneath the posting club.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      imagePath: 'tpl:0',
    );
    await pumpHome(tester);
    await tester.pump(const Duration(milliseconds: 400));

    final photo = find.byKey(ValueKey('home-feed-photo-$postId'));
    final attribution = find.byKey(
      ValueKey('home-post-photo-attribution-$postId'),
    );
    final caption = find.byKey(ValueKey('home-post-caption-$postId'));
    expect(photo, findsOneWidget);
    expect(attribution, findsOneWidget);
    expect(caption, findsOneWidget);
    expect(find.text('Design Society'), findsOneWidget);
    expect(tester.getRect(photo).left, 0);
    expect(tester.getRect(photo).right, 393);
    expect(tester.getSize(photo).height, closeTo((393 - 40) / (4 / 5), 0.1));
    expect(
      tester.getRect(attribution).top,
      greaterThanOrEqualTo(tester.getRect(photo).bottom),
    );
    expect(
      tester.getRect(caption).top,
      greaterThan(tester.getRect(attribution).bottom),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'liking a club post smoothly fills the heart and rolls its count',
    (tester) async {
      await pumpHome(tester);

      final action = find.byKey(const ValueKey('home-post-like-$postId'));
      final motion = find.byKey(
        const ValueKey('home-post-like-heart-motion-$postId'),
      );
      expect(
        find.descendant(
          of: action,
          matching: find.byIcon(Icons.favorite_border_rounded),
        ),
        findsOneWidget,
      );
      expect(tester.widget<ScaleTransition>(motion).scale.value, 1);

      await tester.tap(action);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(userState.isLiked(postId), isTrue);
      expect(postLikeCount(postId), 1);
      expect(
        tester.widget<ScaleTransition>(motion).scale.value,
        greaterThan(1),
      );
      expect(
        find.descendant(
          of: action,
          matching: find.byIcon(Icons.favorite_rounded),
        ),
        findsOneWidget,
      );

      // Let the heart settle and the content-store save debounce complete.
      await tester.pump(const Duration(seconds: 2));
      expect(tester.widget<ScaleTransition>(motion).scale.value, 1);
      expect(
        find.descendant(of: action, matching: find.text('1')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home header follows scroll direction and restores at the top', (
    tester,
  ) async {
    for (var i = 2; i <= 7; i++) {
      newsPosts.add(
        NewsPost(
          id: 'home-design-post-$i',
          clubId: clubId,
          authorId: 'home-design-author',
          content: 'Scrollable home feed post $i',
          createdAt: DateTime.now().subtract(Duration(hours: i)),
        ),
      );
    }
    await pumpHome(tester, height: 844);

    final scrollView = find.byType(CustomScrollView);
    AnimatedOpacity controls() => tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('home-header-controls')),
    );
    BoxDecoration headerDecoration() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('home-header-surface')),
                )
                .decoration!
            as BoxDecoration;
    BoxDecoration bellDecoration() =>
        tester
                .widget<AnimatedContainer>(
                  find.byKey(const ValueKey('home-notifications-bell-surface')),
                )
                .decoration!
            as BoxDecoration;

    expect(controls().opacity, 1);
    expect(headerDecoration().color, ClubUpColors.background);

    await tester.drag(scrollView, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controls().opacity, 0);

    await tester.drag(scrollView, const Offset(0, 24));
    await tester.pump(const Duration(milliseconds: 350));
    expect(controls().opacity, 1);
    expect(headerDecoration().color, Colors.transparent);
    expect(bellDecoration().color, Colors.transparent);

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(0);
    await tester.pump(const Duration(milliseconds: 300));
    expect(controls().opacity, 1);
    expect(headerDecoration().color, ClubUpColors.background);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'comment action opens the redesigned sheet and its reply thread',
    (tester) async {
      comments.add(
        Comment(
          id: 'home-design-comment-1',
          postId: postId,
          userId: authService.currentUser!.id,
          content: 'This is exactly what I need!',
          createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      );
      await pumpHome(tester);

      await tester.tap(find.byKey(const ValueKey('home-post-comment-$postId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // `comments-bottom-sheet`
      expect(
        find.byKey(const ValueKey('home-comments-sheet-$postId')),
        findsOneWidget,
      );
      final l10n = await AppLocalizations.delegate.load(
        Locale(S.hiPrefix == 'Hi,' ? 'en' : 'tr'),
      );
      expect(find.text(l10n.comments), findsOneWidget);
      expect(find.text('This is exactly what I need!'), findsOneWidget);
      expect(find.byKey(const ValueKey('home-comment-field')), findsOneWidget);

      // `reply-thread` — the Reply link switches the sheet to the thread view.
      await tester.tap(
        find.byKey(const ValueKey('home-comment-reply-home-design-comment-1')),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(S.repliesTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('home-replies-back')), findsOneWidget);
      expect(find.text(S.noRepliesYetLine), findsOneWidget);

      // Replies are session-only (see HomeCommentExtras) — they never reach the
      // backend, but they do show up in the thread.
      await tester.enterText(
        find.byKey(const ValueKey('home-comment-field')),
        'Count me in too!',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('home-comment-send')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Count me in too!'), findsOneWidget);
      expect(homeCommentExtras.replyCountFor('home-design-comment-1'), 1);

      await tester.tap(find.byKey(const ValueKey('home-replies-back')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(l10n.comments), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('share action opens the share sheet and Copy Link records it', (
    tester,
  ) async {
    shares.removeWhere((share) => share.targetId == postId);
    await pumpHome(tester);

    await tester.tap(find.byKey(const ValueKey('home-post-share-$postId')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // `share-bottom-sheet`
    expect(find.byKey(const ValueKey('home-share-sheet')), findsOneWidget);
    expect(find.text(S.shareSheetTitle), findsOneWidget);
    expect(find.byKey(const ValueKey('home-share-search')), findsOneWidget);
    expect(find.text(S.shareResultsLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('home-share-copy-link')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-share-cancel')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-share-copy-link')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    // Let contentStore's save debounce fire so no timer outlives the test.
    await tester.pump(const Duration(seconds: 2));
    expect(shares.where((share) => share.targetId == postId).length, 1);
    expect(tester.takeException(), isNull);
  });
}
