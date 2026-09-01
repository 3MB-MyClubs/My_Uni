import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/create_post_screen.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/widgets/club_home_design.dart';
import 'package:flutter_application_1/widgets/clubup_design.dart';
import 'package:flutter_application_1/widgets/content_image_uploader.dart';
import 'package:flutter_application_1/widgets/home_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The CLUB HOME area — `home-feed-alt-light` / `home-feed-alt-dark`
/// (Figma `272:31` / `272:200`) and the typed `admin-compose` state `305:468`.
///
/// The club POV is a `setClubAdmin` session: no student user, so the frame's
/// like/share controls resolve to what the club account can actually do.
void main() {
  late Directory tempDir;
  const clubId = 'club-home-design-club';
  const postId = 'club-home-design-post-1';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_home_design_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');
    await authService.logout();
    userState.replaceLikedPosts(const []);
    clubs
      ..removeWhere((club) => club.id == clubId)
      ..add(
        Club(
          id: clubId,
          name: 'Design Society',
          shortName: 'IES',
          description: 'CLUB HOME redesign fixture',
          adminUserIds: const ['club-home-design-admin'],
        ),
      );
    newsPosts
      ..clear()
      ..add(
        NewsPost(
          id: postId,
          clubId: clubId,
          authorId: 'club-home-design-admin',
          content:
              "We're hosting a workshop on accessible color palettes next "
              'week! All are welcome to join.',
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
    await themeService.setDark(false);
  });

  void signInClubAdmin() {
    authService.setClubAdmin(
      AppAdmin(
        id: 'club-home-design-admin',
        name: 'Design Society',
        email: 'design.society@ku.edu.tr',
        password: '22222222',
      ),
    );
  }

  Future<void> pumpHome(WidgetTester tester, {double height = 1400}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(393, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const FeedScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
  }

  testWidgets('club Home shares the student header and keeps its composer', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpHome(tester);

    // Same student-style top layer, without the student-only feed filter.
    expect(find.byType(ClubHomeHeader), findsNothing);
    expect(find.byType(HomeFeedHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-feed-scope-dropdown')),
      findsNothing,
    );
    expect(find.text(S.forYou), findsNothing);
    expect(find.text('${S.hiPrefix} @IES'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-notifications-bell')),
      findsOneWidget,
    );

    // `admin-compose` 298:5.
    expect(find.byType(ClubHomeComposerCard), findsOneWidget);
    expect(find.text(S.clubHomeComposerHint), findsOneWidget);
    expect(find.text(S.post), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-home-composer-photo')),
      findsOneWidget,
    );
    final dividerFinder = find.byKey(
      const ValueKey('club-home-composer-divider'),
    );
    final divider = tester.widget<Container>(dividerFinder);
    expect(tester.getSize(dividerFinder).height, 3);
    expect(divider.color, ClubUpColors.text);
    expect(tester.takeException(), isNull);
  });

  testWidgets('new-post flow is text and optional photo only', (tester) async {
    signInClubAdmin();
    tester.view.devicePixelRatio = 1;
    // A wide harness keeps this regression focused on the available creation
    // controls rather than the legacy form's narrow fallback-font overflows.
    tester.view.physicalSize = const Size(800, 1200);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CreatePostScreen(),
        ),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CreatePostScreen)),
    )!;
    expect(find.text(l10n.templateLabel), findsNothing);
    expect(find.byIcon(Icons.palette_outlined), findsNothing);
    expect(find.text(l10n.photoLabel), findsOneWidget);
    expect(find.byType(ContentImageUploader), findsOneWidget);
    expect(find.text(l10n.addPoll), findsNothing);
    expect(find.byIcon(Icons.poll_outlined), findsNothing);
    expect(find.text(l10n.markAsAnnouncement), findsNothing);
    expect(find.byIcon(Icons.campaign_outlined), findsNothing);
    expect(find.byType(Switch), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('photo posts use the same edge-to-edge layout as student Home', (
    tester,
  ) async {
    signInClubAdmin();
    newsPosts.first = NewsPost(
      id: postId,
      clubId: clubId,
      authorId: 'club-home-design-admin',
      content: 'Workshop next week!',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      imagePath: 'tpl:1',
    );
    await pumpHome(tester);

    final card = find.byKey(const ValueKey('club-home-post-card-$postId'));
    expect(card, findsOneWidget);
    final photo = find.byKey(const ValueKey('club-home-post-photo-$postId'));
    final badge = find.byKey(const ValueKey('club-home-post-club-$postId'));
    expect(photo, findsOneWidget);
    expect(badge, findsOneWidget);
    // The student layout is edge-to-edge and puts attribution below the photo.
    final photoRect = tester.getRect(photo);
    final badgeRect = tester.getRect(badge);
    // The entrance transition may still translate the card by a few pixels;
    // its laid-out width is nevertheless the full viewport, just like Home.
    expect(tester.getSize(photo).width, 393);
    expect(badgeRect.top, greaterThanOrEqualTo(photoRect.bottom));
    expect(find.text('Design Society'), findsWidgets);

    // `interaction-row` 272:72 — likes, comments and views.
    expect(
      find.byKey(const ValueKey('club-home-post-like-$postId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-home-post-comment-$postId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-home-post-views-$postId')),
      findsOneWidget,
    );
    // Sharing a post needs a student sender; a club-admin login has none.
    expect(
      find.byKey(const ValueKey('club-home-post-share-$postId')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('text-only posts use the same header-first student layout', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpHome(tester);

    final cardFinder = find.byKey(
      const ValueKey('club-home-post-card-$postId'),
    );
    final card = tester.widget<Container>(cardFinder);
    final decoration = card.decoration! as BoxDecoration;
    expect(tester.getSize(cardFinder).width, 393);
    expect(decoration.color, ClubUpColors.background);
    expect(decoration.borderRadius, BorderRadius.zero);
    expect(
      find.byKey(const ValueKey('club-home-post-photo-$postId')),
      findsNothing,
    );
    final badge = find.byKey(const ValueKey('club-home-post-club-$postId'));
    expect(badge, findsOneWidget);
    final caption = find.textContaining('accessible color palettes');
    expect(caption, findsOneWidget);
    expect(tester.getCenter(badge).dy, lessThan(tester.getCenter(caption).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing fills the compose card, as in 305:468', (tester) async {
    signInClubAdmin();
    await pumpHome(tester);

    final field = find.byKey(const ValueKey('club-home-composer-field'));
    final composer = tester.widget<Container>(
      find.byKey(const ValueKey('club-home-composer')),
    );
    expect(composer.decoration, isNull);
    final composerField = tester.widget<TextField>(field);
    expect(composerField.decoration!.filled, isFalse);
    expect(composerField.decoration!.fillColor, Colors.transparent);
    expect(composerField.decoration!.focusedBorder, InputBorder.none);

    await tester.tap(field);
    await tester.pump();
    // Focusing stays inside Home; no second composer or modal is mounted.
    expect(find.byType(TextField), findsOneWidget);

    await tester.enterText(field, 'Just wrapped up our latest design sprint');
    // The hint fades rather than disappearing, so let the decorator settle.
    await tester.pump(const Duration(milliseconds: 300));

    // The typed state prints the paragraph in the card itself.
    expect(
      find.text('Just wrapped up our latest design sprint'),
      findsOneWidget,
    );
    final hintOpacity = tester.widget<AnimatedOpacity>(
      find
          .ancestor(
            of: find.text(S.clubHomeComposerHint),
            matching: find.byType(AnimatedOpacity),
          )
          .first,
    );
    expect(hintOpacity.opacity, 0);
    final postAction = find.byKey(const ValueKey('club-home-composer-post'));
    expect(
      find.descendant(of: postAction, matching: find.byType(Container)),
      findsNothing,
    );

    final editable = tester.state<EditableTextState>(
      find.byType(EditableText).first,
    );
    expect(editable.widget.focusNode.hasFocus, isTrue);
    await tester.tap(find.byKey(const ValueKey('club-home-post-card-$postId')));
    await tester.pump();
    expect(editable.widget.focusNode.hasFocus, isFalse);

    final postCountBeforeReview = newsPosts.length;
    await tester.tap(postAction);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('club-home-post-preview')),
      findsOneWidget,
    );
    expect(find.text('Ready to post?'), findsOneWidget);
    expect(find.text('Just wrapped up our latest design sprint'), findsWidgets);
    expect(
      find.byKey(const ValueKey('club-home-post-preview-confirm')),
      findsOneWidget,
    );
    // Opening the preview alone never publishes.
    expect(newsPosts.length, postCountBeforeReview);
    await tester.tap(find.byKey(const ValueKey('club-home-post-preview-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('club-home-post-preview')), findsNothing);
    expect(newsPosts.length, postCountBeforeReview);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode paints the zinc ramp, not ClubUpColors', (
    tester,
  ) async {
    signInClubAdmin();
    await themeService.setDark(true);
    addTearDown(() => themeService.setDark(false));
    await pumpHome(tester);

    expect(ClubHomeColors.page, const Color(0xFF121212));
    expect(ClubHomeColors.card, const Color(0xFF18181B));
    expect(ClubHomeColors.composeCard, const Color(0xFF141417));
    expect(ClubHomeColors.border, const Color(0xFF27272A));
    // The accent does not lift in this section.
    expect(ClubHomeColors.accent, const Color(0xFF800020));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF121212));
    final divider = tester.widget<Container>(
      find.byKey(const ValueKey('club-home-composer-divider')),
    );
    expect(divider.color, Colors.white);
    expect(tester.takeException(), isNull);
  });

  test('view counts print as the frame does', () {
    expect(formatClubHomeCount(0), '0');
    expect(formatClubHomeCount(999), '999');
    expect(formatClubHomeCount(2400), '2.4k');
    expect(formatClubHomeCount(12400), '12k');
  });
}
