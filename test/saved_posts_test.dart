import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/saved_posts_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/home_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Saved items has always had a Posts tab, but nothing in the app could put a
/// post in it — only events had a bookmark. These tests pin the post half of
/// that store: the Home feed card saves, the save is persisted per user, and a
/// club session (which has no Saved surface to read it back) never gets the
/// control.
void main() {
  late Directory tempDir;
  late List<Club> originalClubs;
  late List<NewsPost> originalPosts;
  late List<User> originalUsers;
  late String userId;

  const clubId = 'saved-posts-club';
  const postId = 'saved-post-1';

  Finder saveButton(String id) =>
      find.byKey(ValueKey('home-post-save-$id'));

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('saved_posts_');
    Hive.init(tempDir.path);
    SharedPreferences.setMockInitialValues(const {});
    await userPrefsService.initialize();
  });

  setUp(() {
    originalClubs = List<Club>.from(clubs);
    originalPosts = List<NewsPost>.from(newsPosts);
    originalUsers = List<User>.from(users);
    clubs.clear();
    newsPosts.clear();
    users.clear();
    userState.savedPostIds.clear();

    clubs.add(
      Club(
        id: clubId,
        name: 'Campus Creators',
        description: 'Fixture club',
        adminUserIds: const [clubId],
      ),
    );
    newsPosts.add(
      NewsPost(
        id: postId,
        clubId: clubId,
        authorId: clubId,
        content: 'Minutes from the last meeting are up.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    );

    expect(
      authService.signUp('Saver Student', 'post.saver@ku.edu.tr', '135790'),
      isTrue,
    );
    userId = authService.currentUser!.id;
  });

  tearDown(() {
    authService.logout();
    userState.savedPostIds.clear();
    clubs
      ..clear()
      ..addAll(originalClubs);
    newsPosts
      ..clear()
      ..addAll(originalPosts);
    users
      ..clear()
      ..addAll(originalUsers);
  });

  tearDownAll(() {
    // No Hive.close(): this file writes through userPrefsService, and closing
    // the box waits on those writes forever (see saved_events_test).
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('the Home feed post card writes the shared saved state', (
    tester,
  ) async {
    await pumpCard(tester, newsPosts.first);

    expect(saveButton(postId), findsOneWidget);
    expect(userState.isSaved(postId), isFalse);
    expect(
      find.descendant(
        of: saveButton(postId),
        matching: find.byIcon(Icons.bookmark_border_rounded),
      ),
      findsOneWidget,
    );

    await tester.tap(saveButton(postId));
    await tester.pump(const Duration(milliseconds: 400));

    expect(userState.isSaved(postId), isTrue);
    // The card fills the bookmark without a manual refresh.
    expect(
      find.descendant(
        of: saveButton(postId),
        matching: find.byIcon(Icons.bookmark_rounded),
      ),
      findsOneWidget,
    );

    // Tapping again unsaves.
    await tester.tap(saveButton(postId));
    await tester.pump(const Duration(milliseconds: 400));
    expect(userState.isSaved(postId), isFalse);
  });

  testWidgets('the post save survives a restart of the saved-state store', (
    tester,
  ) async {
    await pumpCard(tester, newsPosts.first);

    await tester.tap(saveButton(postId));
    // Let the write land before reading it back.
    await tester.pump(const Duration(milliseconds: 100));

    // Wipe the in-memory set the way a fresh launch would, then reload.
    userState.savedPostIds.clear();
    expect(userState.isSaved(postId), isFalse);

    userPrefsService.load(userId);
    expect(userState.isSaved(postId), isTrue);
  });

  testWidgets('a club session gets no save control on a post', (tester) async {
    authService.logout();
    authService.setClubAdmin(
      AppAdmin(
        id: clubId,
        name: 'Campus Creators',
        email: 'creators@ku.edu.tr',
        password: '135790',
      ),
      checkTerms: false,
    );

    await pumpCard(tester, newsPosts.first, clubContext: true);

    expect(saveButton(postId), findsNothing);
    expect(find.byKey(const ValueKey('club-home-post-save-$postId')),
        findsNothing);
  });

  testWidgets('a signed-out session gets no save control on a post', (
    tester,
  ) async {
    authService.logout();

    await pumpCard(tester, newsPosts.first);

    expect(saveButton(postId), findsNothing);
  });

  testWidgets('Saved items lists a post saved from the feed', (tester) async {
    await pumpCard(tester, newsPosts.first);
    await tester.tap(saveButton(postId));
    await tester.pump(const Duration(milliseconds: 400));

    await tester.pumpWidget(_app(const SavedPostsScreen()));
    await tester.pump();

    // The screen opens on the Posts segment.
    expect(find.text('Minutes from the last meeting are up.'), findsOneWidget);
  });
}

/// Pumps the card the way Home does. The avatars are Riverpod consumers, so
/// the scope is not optional.
Future<void> pumpCard(
  WidgetTester tester,
  NewsPost post, {
  bool clubContext = false,
}) async {
  tester.view.physicalSize = const Size(402 * 3, 906 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    _app(
      SingleChildScrollView(
        child: HomeFeedPostCard(
          post: post,
          onChanged: () {},
          clubContext: clubContext,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
}

Widget _app(Widget home) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: home),
  ),
);
