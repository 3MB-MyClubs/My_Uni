import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
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

Future<String> _writeTestPhoto(
  Directory directory,
  String name, {
  required int width,
  required int height,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF8B1538),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  final path = '${directory.path}/$name.png';
  await File(path).writeAsBytes(data!.buffer.asUint8List(), flush: true);
  return path;
}

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
    final admin = AppAdmin(
      id: 'vertical-feed-admin',
      name: 'Vertical Feed Club',
      email: 'vertical.feed.club@ku.edu.tr',
      password: '11111111',
    );
    final club = Club(
      id: 'vertical-feed-club',
      name: 'Vertical Feed Club',
      description: 'Vertical photo-feed regression fixture',
      adminUserIds: [admin.id],
    );
    clubAdmins.add(admin);
    clubs.add(club);
    addTearDown(() async {
      newsPosts
        ..clear()
        ..addAll(originalPosts);
      events
        ..clear()
        ..addAll(originalEvents);
      clubAdmins.removeWhere((candidate) => candidate.id == admin.id);
      clubs.removeWhere((candidate) => candidate.id == club.id);
      await authService.logout();
      await tester.binding.setSurfaceSize(null);
    });

    expect(managedClubForAdmin(admin.id)?.id, club.id);
    expect(authService.login(admin.email, admin.password), isTrue);

    final now = DateTime.now();
    final portraitPhoto = (await tester.runAsync(
      () => _writeTestPhoto(
        tempDir,
        'portrait-feed-photo',
        width: 80,
        height: 160,
      ),
    ))!;
    final landscapePhoto = (await tester.runAsync(
      () => _writeTestPhoto(
        tempDir,
        'landscape-feed-photo',
        width: 160,
        height: 80,
      ),
    ))!;
    newsPosts
      ..clear()
      ..addAll([
        NewsPost(
          id: 'feed-view-lifecycle-1',
          clubId: club.id,
          authorId: admin.id,
          content: 'First lifecycle regression post',
          createdAt: now,
          imagePath: portraitPhoto,
        ),
        NewsPost(
          id: 'feed-view-lifecycle-2',
          clubId: club.id,
          authorId: admin.id,
          content: 'Second lifecycle regression post',
          createdAt: now.subtract(const Duration(minutes: 1)),
          imagePath: landscapePhoto,
        ),
      ]);
    events.clear();
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 1800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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

    expect(find.text('First lifecycle regression post'), findsOneWidget);
    expect(find.text('Second lifecycle regression post'), findsOneWidget);
    // A club-admin session now draws the CLUB HOME card (`home-feed-alt`
    // 272:31), whose photo carries the area's own key.
    expect(
      find.byKey(const ValueKey('club-home-post-photo-feed-view-lifecycle-1')),
      findsOneWidget,
    );
    final firstPhoto = find.byKey(
      const ValueKey('club-home-post-photo-feed-view-lifecycle-1'),
    );
    final secondPhoto = find.byKey(
      const ValueKey('club-home-post-photo-feed-view-lifecycle-2'),
    );
    expect(secondPhoto, findsOneWidget);

    final firstPhotoRect = tester.getRect(firstPhoto);
    final secondPhotoRect = tester.getRect(secondPhoto);
    expect(firstPhotoRect.left, secondPhotoRect.left);
    expect(firstPhotoRect.width, secondPhotoRect.width);
    expect(firstPhotoRect.height, greaterThan(firstPhotoRect.width));
    expect(secondPhotoRect.height, lessThan(secondPhotoRect.width));
    expect(secondPhotoRect.top, greaterThan(firstPhotoRect.bottom));
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
