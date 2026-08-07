import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_application_1/screens/notifications_screen.dart';
import 'package:flutter_application_1/screens/saved_posts_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_notification_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Covers the Phase 0 quick wins: saved events surfacing, notification
/// filter chips, mention notifications, and the Explore events/posts search.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootstrap() async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');
  }

  testWidgets('Saved screen lists saved events under the Events segment', (
    tester,
  ) async {
    await bootstrap();
    final event = events.first;
    if (!userState.isSaved(event.id)) userState.toggleSave(event.id);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: SavedPostsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Events ('), findsOneWidget);
    await tester.tap(find.textContaining('Events ('));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(event.title), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('phase0-saved-events');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notification chips filter and mentions notify', (tester) async {
    // Generate a mention notification aimed at the logged-in user (u1).
    final post = NewsPost(
      id: 'test_mention_post',
      clubId: 'c1',
      authorId: 'c1',
      content: 'Welcome @Alice!',
      createdAt: DateTime.now(),
      taggedUserIds: const ['u1'],
    );
    clubNotificationService.notifyMentionedUsers(post);
    expect(
      userState.dynamicNotifications.any(
        (n) => n.id == 'mention_test_mention_post_u1',
      ),
      isTrue,
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NotificationsScreen())),
    );
    await tester.pump(const Duration(milliseconds: 400));

    // All four chips render.
    expect(find.text('All'), findsOneWidget);
    expect(find.text('You'), findsOneWidget);
    expect(find.text('Events'), findsOneWidget);
    expect(find.text('Clubs'), findsOneWidget);

    // The "You" bucket contains the mention (rendered as RichText).
    await tester.tap(find.text('You'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.textContaining('mentioned you', findRichText: true),
      findsWidgets,
    );

    await binding.takeScreenshot('phase0-notification-chips');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Explore search is limited to clubs and people', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ExploreScreen())),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Discover Clubs'), findsOneWidget);
    expect(find.text('Find People'), findsOneWidget);
    expect(find.text('Events'), findsNothing);

    await binding.takeScreenshot('phase0-explore-search');
    expect(tester.takeException(), isNull);
  });
}
