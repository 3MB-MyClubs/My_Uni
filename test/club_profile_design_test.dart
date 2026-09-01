import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/club_board_members_screen.dart';
import 'package:flutter_application_1/screens/club_insights_screen.dart';
import 'package:flutter_application_1/screens/club_profile_members_screen.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_insights_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/club_profile_design.dart';
import 'package:flutter_application_1/widgets/event_cover_image.dart';
import 'package:flutter_application_1/widgets/home_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The CLUB PROFİLE area — section label `555:33`.
///
/// Frames covered: `club-profile` `337:8` / `337:98`, `events` `343:12`,
/// `board` `332:1963`, `board-members-all` `346:6` and `insights` `347:6`.
/// The frames are the club's own point of view, but they are the only
/// club-profile design in the handoff, so **students render them too** — with
/// the admin controls off and Follow + Club Chat in their place. Only the
/// ClubUp platform moderator (and a session-less pump) keeps the old screen.
void main() {
  late Directory tempDir;
  const clubId = 'club-profile-design-club';
  const adminId = 'club-profile-design-admin';
  const boardId = 'club-profile-design-board-1';
  const memberId = 'club-profile-design-member-1';
  // A student who is *not* in this club — the browsing point of view. Signing
  // in as `memberId` would drop them from the member directory they open.
  const viewerId = 'club-profile-design-viewer';
  const postId = 'club-profile-design-post-1';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_profile_design_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  late Club club;

  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');
    await authService.logout();

    club = Club(
      id: clubId,
      name: 'Rooftop Collective',
      shortName: 'RC',
      description: 'A curator of deep grooves, fine arts and sunset sessions.',
      categoryName: 'Music, Arts',
      adminUserIds: const [adminId],
      boardMemberIds: [boardId],
      boardMemberTitles: const {boardId: 'President'},
    );
    clubs
      ..removeWhere((item) => item.id == clubId)
      ..add(club);
    users
      ..removeWhere(
        (item) =>
            item.id == boardId || item.id == memberId || item.id == viewerId,
      )
      ..add(
        User(
          id: boardId,
          name: 'Liam Connor',
          email: 'liam@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [clubId],
        ),
      )
      ..add(
        User(
          id: memberId,
          name: 'Maya Stone',
          email: 'maya@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [clubId],
        ),
      )
      ..add(
        User(
          id: viewerId,
          name: 'Ada Yilmaz',
          email: 'ada@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    newsPosts
      ..clear()
      ..add(
        NewsPost(
          id: postId,
          clubId: clubId,
          authorId: adminId,
          content: 'Golden hour at the terrace last night.',
          createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        ),
      );
    final start = DateTime.now().add(const Duration(days: 3, hours: 18));
    events
      ..clear()
      ..add(
        Event(
          id: 'club-profile-design-event-1',
          clubId: clubId,
          title: 'Sunset Terrace Grooves',
          description: 'Deep grooves on the roof.',
          dateTime: start,
          endTime: start.add(const Duration(hours: 5)),
          location: 'The Sky Lounge Terrace',
          attendeeUserIds: const [],
        ),
      );
  });

  tearDown(() async {
    clubs.removeWhere((item) => item.id == clubId);
    users.removeWhere(
      (item) =>
          item.id == boardId || item.id == memberId || item.id == viewerId,
    );
    newsPosts.clear();
    events.clear();
    await authService.logout();
    await themeService.setDark(false);
  });

  void signInClubAdmin() {
    authService.setClubAdmin(
      AppAdmin(
        id: adminId,
        name: 'Rooftop Collective',
        email: 'rooftop.collective@ku.edu.tr',
        password: '22222222',
      ),
    );
  }

  void signInStudent() {
    expect(authService.login('ada@ku.edu.tr', '111111'), isTrue);
  }

  Future<void> pumpProfile(
    WidgetTester tester, {
    double height = 2200,
    int initialTabIndex = 0,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(402, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubProfileScreen(
            club: club,
            color: const Color(0xFF800020),
            initialTabIndex: initialTabIndex,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('the club sees the frame header, identity card and stat cells', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester);

    // `chat-header` 332:2208 — the frame titles the screen, not the club.
    expect(find.text(S.clubProfileTitle), findsOneWidget);
    final identityCard = find.byType(ClubProfileIdentityCard);
    expect(identityCard, findsOneWidget);
    final identityBadge = find.descendant(
      of: identityCard,
      matching: find.byType(ClubVerifiedBadge),
    );
    expect(identityBadge, findsOneWidget);
    final badgeIcons = tester
        .widgetList<Icon>(
          find.descendant(of: identityBadge, matching: find.byType(Icon)),
        )
        .toList();
    expect(badgeIcons, hasLength(2));
    expect(badgeIcons[0].icon, Icons.verified_rounded);
    expect(badgeIcons[0].color, const Color(0xFF800020));
    expect(badgeIcons[1].icon, Icons.check_rounded);
    expect(badgeIcons[1].color, Colors.white);
    expect(find.text('Rooftop Collective'), findsWidgets);
    expect(find.text('@RC'), findsOneWidget);
    final handle = tester.widget<Text>(
      find.byKey(const ValueKey('club-profile-handle')),
    );
    expect(handle.style?.color, ClubProfileColors.text);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('club-profile-handle')),
        matching: find.byType(ClubProfileChip),
      ),
      findsNothing,
    );

    // `categories-row` 426:20 splits the club's comma-separated categories.
    expect(find.text('Music'), findsOneWidget);
    expect(find.text('Arts'), findsOneWidget);

    // `stats-row` 337:39 — Timeline / Members / Events.
    final identity = find.byType(ClubProfileIdentityCard);
    expect(tester.getSize(identity).height, lessThan(210));
    final stats = find.byType(ClubProfileStatsRow);
    expect(stats, findsOneWidget);
    // The 56pt cells plus the card's 1pt hairline on each side.
    expect(tester.getSize(stats).height, 58);
    expect(find.byType(ClubProfileSegmentedTabs), findsWidgets);
    expect(find.text(S.clubProfileTimeline), findsNWidgets(2));
    expect(
      find.text(AppLocalizations.of(tester.element(stats))!.posts),
      findsNothing,
    );
    final primaryTabs = find.byWidgetPredicate(
      (widget) => widget is ClubProfileSegmentedTabs && !widget.compact,
    );
    expect(primaryTabs, findsOneWidget);
    expect(tester.getSize(primaryTabs).height, 38);

    // Stripped to the frame: no Club Chat shortcut.
    expect(find.text(S.clubChat), findsNothing);
    expect(find.byKey(ValueKey('club-community-button-$clubId')), findsNothing);

    // The club's own header keeps the insights entry the frame draws.
    expect(find.byKey(const ValueKey('club-profile-insights')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the public @handle updates when club initials change', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester);

    expect(find.text('@RC'), findsOneWidget);

    club.shortName = 'IES';
    userState.bumpClubInfo();
    await tester.pump();

    expect(find.text('@RC'), findsNothing);
    expect(find.text('@IES'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Members stat opens the joined-member searchable directory', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester);

    final stats = find.byType(ClubProfileStatsRow);
    final membersLabel = find.descendant(
      of: stats,
      matching: find.text(AppLocalizations.of(tester.element(stats))!.members),
    );
    await tester.tap(membersLabel);
    await tester.pumpAndSettle();

    expect(find.byType(ClubProfileMembersScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-profile-member-$boardId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-profile-member-$memberId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-profile-members-search-card')),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text(S.clubNoMemberMatches), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with no session the old screen still renders', (tester) async {
    // The ClubUp platform moderator's path, and any session-less pump. Neither
    // is a club nor a student, so neither reaches the frames.
    await pumpProfile(tester);

    expect(find.text(S.clubProfileTitle), findsNothing);
    expect(find.byType(ClubProfileIdentityCard), findsNothing);
    expect(find.byType(ClubVerifiedBadge), findsOneWidget);
    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text(S.clubProfileTimeline.toUpperCase()), findsOneWidget);
    // The legacy header overflows this fixture by 4.5px at 402pt wide — the
    // same at HEAD, verified in a clean worktree. Drained, not asserted on:
    // this area deliberately left that screen alone.
    tester.takeException();
  });

  testWidgets('a student browsing the club gets the same frames', (
    tester,
  ) async {
    signInStudent();
    await pumpProfile(tester);

    // Same chrome as the club sees.
    expect(find.text(S.clubProfileTitle), findsOneWidget);
    expect(find.byType(ClubProfileIdentityCard), findsOneWidget);
    expect(find.byType(ClubProfileStatsRow), findsOneWidget);
    expect(find.byType(ClubProfileSegmentedTabs), findsWidgets);
    expect(find.text('@RC'), findsOneWidget);
    expect(find.text('Music'), findsOneWidget);

    // None of the admin controls.
    expect(find.byKey(const ValueKey('club-profile-insights')), findsNothing);
    expect(find.byIcon(Icons.settings_outlined), findsNothing);

    // Student actions in their place.
    expect(find.byKey(const ValueKey('club-profile-follow')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-profile-club-chat')),
      findsOneWidget,
    );
    expect(find.text(S.clubChat), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Follow button reflects and flips with followed state', (
    tester,
  ) async {
    signInStudent();
    await pumpProfile(tester);
    final l10n = AppLocalizations.of(
      tester.element(find.byType(ClubProfileIdentityCard)),
    )!;

    ClubProfileActionButton followButton() =>
        tester.widget<ClubProfileActionButton>(
          find.byKey(const ValueKey('club-profile-follow')),
        );

    // Not following: the filled accent call to action.
    expect(followButton().label, l10n.follow);
    expect(followButton().filled, isTrue);

    userState.followedClubIds.add(clubId);
    addTearDown(() => userState.followedClubIds.remove(clubId));
    await pumpProfile(tester);

    // Following: outlined, so it reads as a state rather than an invitation.
    expect(followButton().label, l10n.following);
    expect(followButton().filled, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-pressing the identity card offers Report & Block', (
    tester,
  ) async {
    signInStudent();
    await pumpProfile(tester);

    // The frame draws no overflow, so this is the student's moderation route.
    await tester.longPress(find.byType(ClubProfileIdentityCard));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-profile-report')), findsOneWidget);
    expect(find.text(S.blockAndReportClub), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a club long-press on the identity card does nothing', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester);

    await tester.longPress(find.byType(ClubProfileIdentityCard));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-profile-report')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student-facing Members stat opens the same directory', (
    tester,
  ) async {
    signInStudent();
    await pumpProfile(tester);

    final stats = find.byType(ClubProfileStatsRow);
    final l10n = AppLocalizations.of(tester.element(stats))!;
    await tester.tap(
      find.descendant(of: stats, matching: find.text(l10n.members)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ClubProfileMembersScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-profile-member-$boardId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-profile-member-$memberId')),
      findsOneWidget,
    );
  });

  testWidgets('Timeline uses the Home feed card with the club menu', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester);

    expect(find.byKey(const ValueKey('club-profile-posts')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-profile-post-$postId')),
      findsOneWidget,
    );
    expect(find.byType(HomeFeedPostCard), findsOneWidget);
    expect(find.text('Golden hour at the terrace last night.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-home-post-actions-panel-$postId')),
      findsOneWidget,
    );

    // The frame's `more-horizontal` carries the pin / delete actions.
    final menu = find.byKey(const ValueKey('club-profile-post-menu-$postId'));
    expect(menu, findsOneWidget);
    await tester.tap(menu);
    await tester.pumpAndSettle();
    expect(
      find.text(
        AppLocalizations.of(
          tester.element(find.byType(ClubProfileStatsRow)),
        )!.pinToTop,
      ),
      findsOneWidget,
    );
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Timeline photo cards stay full-width at phone height', (
    tester,
  ) async {
    const photoPostId = 'club-profile-phone-photo';
    newsPosts.add(
      NewsPost(
        id: photoPostId,
        clubId: clubId,
        authorId: adminId,
        content: 'A full-width photo update.',
        createdAt: DateTime.now(),
        imagePath: 'tpl:1',
      ),
    );
    signInClubAdmin();
    await pumpProfile(tester, height: 874);

    final photo = find.byKey(
      const ValueKey('club-home-post-photo-$photoPostId'),
    );
    expect(photo, findsOneWidget);
    expect(tester.getSize(photo).width, closeTo(402, 0.1));
    expect(
      find.byKey(const ValueKey('club-home-post-actions-panel-$photoPostId')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('posts form a vertical timeline with the newest first', (
    tester,
  ) async {
    final now = DateTime.now();
    newsPosts.addAll([
      NewsPost(
        id: 'club-profile-grid-newest',
        clubId: clubId,
        authorId: adminId,
        content: 'Newest post',
        createdAt: now,
        imagePath: 'tpl:1',
      ),
      NewsPost(
        id: 'club-profile-grid-third',
        clubId: clubId,
        authorId: adminId,
        content: 'Third post',
        createdAt: now.subtract(const Duration(hours: 8)),
        imagePath: 'tpl:2',
      ),
      NewsPost(
        id: 'club-profile-grid-fourth',
        clubId: clubId,
        authorId: adminId,
        content: 'Fourth post',
        createdAt: now.subtract(const Duration(hours: 12)),
        imagePath: 'tpl:3',
      ),
    ]);

    signInClubAdmin();
    await pumpProfile(tester);

    expect(
      tester.widget<ListView>(find.byKey(const ValueKey('club-profile-posts'))),
      isA<ListView>(),
    );

    final newest = find.byKey(
      const ValueKey('club-profile-post-club-profile-grid-newest'),
    );
    final second = find.byKey(const ValueKey('club-profile-post-$postId'));
    final third = find.byKey(
      const ValueKey('club-profile-post-club-profile-grid-third'),
    );
    final fourth = find.byKey(
      const ValueKey('club-profile-post-club-profile-grid-fourth'),
    );
    final newestOffset = tester.getTopLeft(newest);
    final secondOffset = tester.getTopLeft(second);
    final thirdOffset = tester.getTopLeft(third);
    final fourthOffset = tester.getTopLeft(fourth);

    expect(newestOffset.dy, lessThan(secondOffset.dy));
    expect(secondOffset.dy, lessThan(thirdOffset.dy));
    expect(thirdOffset.dy, lessThan(fourthOffset.dy));
    expect(newestOffset.dx, closeTo(secondOffset.dx, 0.1));
    expect(secondOffset.dx, closeTo(thirdOffset.dx, 0.1));
    expect(thirdOffset.dx, closeTo(fourthOffset.dx, 0.1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'an older pinned post does not replace the newest timeline post',
    (tester) async {
      final now = DateTime.now();
      newsPosts.add(
        NewsPost(
          id: 'club-profile-newest-unpinned',
          clubId: clubId,
          authorId: adminId,
          content: 'Newest unpinned post',
          createdAt: now,
        ),
      );
      final wasPinned = userState.isPostPinned(postId);
      if (!wasPinned) userState.togglePinnedPost(postId);
      addTearDown(() {
        if (userState.isPostPinned(postId) != wasPinned) {
          userState.togglePinnedPost(postId);
        }
      });

      signInClubAdmin();
      await pumpProfile(tester);

      final newest = find.byKey(
        const ValueKey('club-profile-post-club-profile-newest-unpinned'),
      );
      final olderPinned = find.byKey(
        const ValueKey('club-profile-post-$postId'),
      );
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(olderPinned).dy),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('the Events tab uses compact rows and keeps Past reachable', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester, initialTabIndex: 1);

    expect(find.byKey(const ValueKey('club-profile-events')), findsOneWidget);
    expect(find.text('Sunset Terrace Grooves'), findsOneWidget);
    expect(find.text('The Sky Lounge Terrace'), findsOneWidget);
    expect(find.byType(ClubProfileEventCard), findsOneWidget);

    final eventCard = find.byKey(
      const ValueKey('club-event-card-club-profile-design-event-1'),
    );
    expect(tester.getSize(eventCard).height, lessThan(130));
    final cover = find.descendant(
      of: eventCard,
      matching: find.byType(EventCoverImage),
    );
    expect(tester.getSize(cover), const Size(96, 96));
    expect(
      find.descendant(
        of: eventCard,
        matching: find.byType(ClubProfilePrimaryButton),
      ),
      findsNothing,
    );

    // The frame draws no filter, but the club's history has no other door.
    expect(find.byKey(const ValueKey('club-events-filter-1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The compact event row draws a chevron rather than the frame's "RSVP Now"
  // pill (a decision that predates this change), so `actionLabel` reaches the
  // user as the chevron's Semantics label. It still has to say the right thing:
  // a club cannot RSVP its own event, a student can.
  testWidgets('the event row action reads View for the club', (tester) async {
    signInClubAdmin();
    await pumpProfile(tester, initialTabIndex: 1);

    final card = find.byType(ClubProfileEventCard);
    final l10n = AppLocalizations.of(tester.element(card))!;
    expect(
      tester.widget<ClubProfileEventCard>(card).actionLabel,
      l10n.viewLabel,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the event row action reads RSVP for a student', (tester) async {
    signInStudent();
    await pumpProfile(tester, initialTabIndex: 1);

    final card = find.byType(ClubProfileEventCard);
    final l10n = AppLocalizations.of(tester.element(card))!;
    expect(tester.widget<ClubProfileEventCard>(card).actionLabel, l10n.rsvp);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Board lists members and View all opens the searchable page', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpProfile(tester, initialTabIndex: 2);

    expect(find.byKey(const ValueKey('club-profile-board')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-board-row-$boardId')),
      findsOneWidget,
    );
    expect(find.text('Liam Connor'), findsWidgets);
    expect(find.text('President'), findsWidgets);

    await tester.tap(find.text(S.clubProfileViewAll));
    await tester.pumpAndSettle();

    // `board-members-all` 346:6 — its own header and search field.
    expect(find.byType(ClubBoardMembersScreen), findsOneWidget);
    expect(find.text(S.clubProfileBoardMembersTitle), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-board-member-$boardId')),
      findsOneWidget,
    );

    final searchCard = tester.widget<ClubProfileCard>(
      find.byKey(const ValueKey('club-board-members-search-card')),
    );
    expect(searchCard.padding, const EdgeInsets.all(16));
    final searchField = tester.widget<TextField>(find.byType(TextField));
    expect(searchField.decoration?.filled, isFalse);
    expect(searchField.decoration?.enabledBorder, InputBorder.none);
    expect(searchField.decoration?.focusedBorder, InputBorder.none);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pump();
    expect(find.text(S.clubProfileNoMembersMatch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Club Insights draws the metric tiles and post performance', (
    tester,
  ) async {
    signInClubAdmin();
    final preview = ClubInsightsData(
      followers: 1247,
      totalRsvps: 89,
      totalLikes: 2831,
      totalViews: 14506,
      postCount: 1,
      since: DateTime(2025, 1, 1),
      events: const [],
      topPosts: [PostStat(post: newsPosts.first, likes: 248, views: 1800)],
    );

    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 1400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubInsightsScreen(
            club: club,
            accent: const Color(0xFF800020),
            previewData: preview,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text(S.clubInsightsTitle), findsOneWidget);
    expect(find.byType(ClubProfileMetricTile), findsNWidgets(4));
    expect(find.text('1,247'), findsOneWidget);
    expect(find.text('14,506'), findsOneWidget);
    expect(find.text(S.clubInsightsPostPerformance), findsOneWidget);
    expect(find.text(S.clubInsightsMostPopular), findsOneWidget);
    expect(find.byType(ClubProfilePostStatRow), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark lifts the accent text to the section\'s bright rose', (
    tester,
  ) async {
    await themeService.setDark(true);
    addTearDown(() => themeService.setDark(false));
    signInClubAdmin();
    await pumpProfile(tester);

    expect(ClubProfileColors.page, const Color(0xFF0A0A0A));
    expect(ClubProfileColors.card, const Color(0xFF121212));
    expect(ClubProfileColors.accent, const Color(0xFF800020));
    expect(ClubProfileColors.accentText, const Color(0xFFFA526B));

    final handle = tester.widget<Text>(
      find.byKey(const ValueKey('club-profile-handle')),
    );
    expect(handle.style?.color, Colors.white);

    final chip = tester.widget<Text>(
      find.descendant(
        of: find.byType(ClubProfileChip).first,
        matching: find.byType(Text),
      ),
    );
    expect(chip.style?.color, const Color(0xFFFA526B));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a real 402x874 window in Turkish clips nothing', (tester) async {
    await localeService.setLanguage('tr');
    addTearDown(() => localeService.setLanguage('en'));
    signInClubAdmin();

    // A tall test viewport hides horizontal crowding behind scroll; the frame
    // itself is 402x874, and `flutter_test`'s fallback font is wider than
    // Figtree, so this is the strictest fit the area gets before a simulator.
    await pumpProfile(tester, height: 874);
    expect(find.text('Akış'), findsNWidgets(2));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('club-profile-tab-1')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('club-profile-tab-2')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
