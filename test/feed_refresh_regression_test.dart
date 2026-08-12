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

  testWidgets('following remains tappable and refresh can run twice', (
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
    final following = find.text('Takip');
    final forYou = find.text('Senin İçin');
    expect(following, findsOneWidget);
    expect(forYou, findsOneWidget);

    await _pullToRefresh(tester, scrollView);
    await tester.tap(following);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_tabTextColor(tester, 'home-feed-tab-0'), Colors.white);

    await tester.tap(forYou);
    await tester.pump(const Duration(milliseconds: 350));
    expect(_tabTextColor(tester, 'home-feed-tab-1'), Colors.white);
    await _pullToRefresh(tester, scrollView);

    expect(tester.takeException(), isNull);
  });
}

Color _tabTextColor(WidgetTester tester, String key) {
  final tab = find.byKey(ValueKey(key));
  final textStyle = find.descendant(
    of: tab,
    matching: find.byType(AnimatedDefaultTextStyle),
  );
  return tester.widget<AnimatedDefaultTextStyle>(textStyle).style.color!;
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
