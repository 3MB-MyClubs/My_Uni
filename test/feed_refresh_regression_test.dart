import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('feed_refresh_regression_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
  });

  tearDownAll(() async {
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  setUp(() async {
    await authService.logout();
    users.removeWhere(
      (user) => user.email == 'feed-refresh-regression@ku.edu.tr',
    );
    expect(
      authService.signUp(
        'Feed Refresh Tester',
        'feed-refresh-regression@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
  });

  tearDown(() => authService.logout());

  testWidgets('feed scope stays switchable and refresh can run twice', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: FeedScreen(),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    final scrollView = find.byType(CustomScrollView);
    // The redesigned student Home puts the feed scope in the header dropdown
    // (`home-feed-alt`) instead of the old segmented pill, so only the active
    // label is on screen at rest. Home opens on For You.
    final dropdown = find.byKey(const ValueKey('home-feed-scope-dropdown'));
    expect(dropdown, findsOneWidget);
    expect(find.text('Senin İçin'), findsOneWidget);
    expect(find.text('Takip'), findsNothing);

    await _pullToRefresh(tester, scrollView);

    await tester.tap(dropdown);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Takip'), findsOneWidget);
    final followingOption = find.byKey(
      const ValueKey('home-feed-scope-option-0'),
    );
    expect(
      tester.getCenter(followingOption).dx,
      moreOrLessEquals(tester.getCenter(dropdown).dx, epsilon: 0.1),
    );

    await tester.tap(find.text('Takip'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Takip'), findsOneWidget);
    expect(find.text('Senin İçin'), findsNothing);

    await _pullToRefresh(tester, scrollView);

    expect(tester.takeException(), isNull);
  });
}

Future<void> _pullToRefresh(WidgetTester tester, Finder scrollView) async {
  final gesture = await tester.startGesture(tester.getCenter(scrollView));
  await gesture.moveBy(const Offset(0, 120));
  await tester.pump();
  expect(
    tester
        .widget<AnimatedOpacity>(
          find.byKey(const ValueKey('home-refresh-indicator')),
        )
        .opacity,
    1,
  );
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 900));
}
