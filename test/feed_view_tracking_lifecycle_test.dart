import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_admin_access.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'feed_view_tracking_lifecycle_test_',
    );
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('admin feed records card views after the build completes', (
    tester,
  ) async {
    final originalPosts = List<NewsPost>.from(newsPosts);
    final originalEvents = [...events];
    addTearDown(() async {
      newsPosts
        ..clear()
        ..addAll(originalPosts);
      events
        ..clear()
        ..addAll(originalEvents);
      await authService.logout();
      await tester.binding.setSurfaceSize(null);
    });

    final admin = clubAdmins.firstWhere(
      (candidate) => managedClubForAdmin(candidate.id)?.id == 'c1',
    );
    final club = managedClubForAdmin(admin.id)!;
    expect(authService.login(admin.email, admin.password), isTrue);

    final now = DateTime.now();
    newsPosts
      ..clear()
      ..addAll([
        NewsPost(
          id: 'feed-view-lifecycle-1',
          clubId: club.id,
          authorId: admin.id,
          content: 'First lifecycle regression post',
          createdAt: now,
          imagePath: 'tpl:0',
        ),
        NewsPost(
          id: 'feed-view-lifecycle-2',
          clubId: club.id,
          authorId: admin.id,
          content: 'Second lifecycle regression post',
          createdAt: now.subtract(const Duration(minutes: 1)),
        ),
      ]);
    events.clear();
    await tester.binding.setSurfaceSize(const Size(800, 1200));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('First lifecycle regression post'), findsOneWidget);
    expect(find.text('Second lifecycle regression post'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('home-feed-photo-feed-view-lifecycle-1')),
      findsOneWidget,
    );
    expect(viewTracker.viewCount('feed-view-lifecycle-1'), 1);
    expect(viewTracker.viewCount('feed-view-lifecycle-2'), 1);
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('home feed springs back after bottom overscroll', (tester) async {
    final originalPosts = List<NewsPost>.from(newsPosts);
    final originalEvents = [...events];
    addTearDown(() async {
      newsPosts
        ..clear()
        ..addAll(originalPosts);
      events
        ..clear()
        ..addAll(originalEvents);
      await authService.logout();
      await tester.binding.setSurfaceSize(null);
    });

    expect(authService.login('alice@ku.edu.tr', '111111'), isTrue);
    final now = DateTime.now();
    newsPosts
      ..clear()
      ..addAll(
        List.generate(
          12,
          (index) => NewsPost(
            id: 'feed-bottom-bounce-$index',
            clubId: clubs.first.id,
            authorId: 'u1',
            content: 'Bottom bounce post $index',
            createdAt: now.subtract(Duration(minutes: index)),
          ),
        ),
      );
    events.clear();
    await tester.binding.setSurfaceSize(const Size(390, 800));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
    await tester.pump();
    expect(scrollable.position.maxScrollExtent, greaterThan(0));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byType(CustomScrollView)),
    );
    await gesture.moveBy(const Offset(0, -180));
    await tester.pump();
    expect(
      scrollable.position.pixels,
      greaterThan(scrollable.position.maxScrollExtent),
    );

    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      scrollable.position.pixels,
      closeTo(scrollable.position.maxScrollExtent, 0.5),
    );
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
