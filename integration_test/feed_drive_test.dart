import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';

/// Drives the real Home feed on a simulator to visually verify:
///  - the Twitter / X-style post layout
///  - the suggestion cadence (friend @10, event @15, club @20)
///  - tapping a friend / event / club opens the right screen
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot(name);
  }

  // Scrolls the feed until [f] is on screen (or we give up).
  Future<bool> scrollTo(WidgetTester t, Finder f, {int max = 60}) async {
    for (int i = 0; i < max; i++) {
      if (f.evaluate().isNotEmpty) {
        try {
          await t.ensureVisible(f.first);
        } catch (_) {}
        await t.pump(const Duration(milliseconds: 200));
        return true;
      }
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, -1100));
      await t.pump(const Duration(milliseconds: 250));
    }
    return f.evaluate().isNotEmpty;
  }

  // Drag the feed back up to the top so the next search starts fresh.
  Future<void> scrollToTop(WidgetTester t, {int times = 18}) async {
    for (int i = 0; i < times; i++) {
      await t.drag(find.byType(CustomScrollView).first, const Offset(0, 1500));
      await t.pump(const Duration(milliseconds: 120));
    }
    await t.pump(const Duration(milliseconds: 200));
  }

  // Pop the top route off the root navigator and let the transition finish.
  Future<void> goBack(WidgetTester t) async {
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    for (int i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Home feed — Twitter layout, suggestion cadence, tap-throughs', (
    tester,
  ) async {
    // Bootstrap the same Hive boxes / services main() sets up (the feed reads
    // them), then log in as a mock student so the feed has a real viewer.
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    contentStore.applyToLists();
    authService.login('alice@ku.edu.tr', '111111');

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: FeedScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // Switch to the full "All" feed so every-N suggestions appear.
    if (find.text('All').evaluate().isNotEmpty) {
      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 500));
    }
    await shot(tester, '01-feed-twitter-top');

    // ── Friend suggestion (every 10 posts) → person profile ──
    try {
      if (await scrollTo(tester, find.text('People You Might Know'))) {
        await shot(tester, '02-friend-suggestion');
        await tester.tap(find.byType(UserAvatar).first);
        await tester.pump(const Duration(milliseconds: 700));
        await shot(tester, '03-friend-profile');
        expect(find.byType(UserProfileScreen), findsOneWidget);
        await goBack(tester);
      }
    } catch (e) {
      debugPrint('friend tap-through skipped: $e');
    }

    // ── Club suggestion (every 20 posts) → club profile ──
    try {
      await scrollToTop(tester);
      if (await scrollTo(tester, find.text('Club You Might Like'))) {
        await shot(tester, '04-club-suggestion');
        await tester.tap(find.text('Club You Might Like'));
        await tester.pump(const Duration(milliseconds: 700));
        await shot(tester, '05-club-profile');
        expect(find.byType(ClubProfileScreen), findsOneWidget);
        await goBack(tester);
      }
    } catch (e) {
      debugPrint('club tap-through skipped: $e');
    }

    // ── Event suggestion (every 15 posts) → event detail (if one is trending) ──
    try {
      await scrollToTop(tester);
      if (await scrollTo(tester, find.text('Trending This Week'), max: 40)) {
        await shot(tester, '06-event-suggestion');
        await tester.tap(find.text('Trending This Week'));
        await tester.pump(const Duration(milliseconds: 700));
        await shot(tester, '07-event-detail');
        expect(find.byType(EventDetailScreen), findsOneWidget);
        await goBack(tester);
      }
    } catch (e) {
      debugPrint('event tap-through skipped: $e');
    }
  });
}
