import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/widgets/comments_sheet.dart';

/// Drives the Home feed's comment affordance: every post card carries a
/// comment button and tapping it opens the sheet with a working composer.
///
/// Posting is deliberately not asserted here. Comments are server-owned — a
/// send only succeeds against a real Supabase session, which this harness
/// (mock login, fixture post ids) does not have — so a green "comment posted"
/// assertion would only be provable by letting comments fall back to local
/// storage, which is exactly what [CommentStore] refuses to do.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Home feed post card opens the comments sheet', (tester) async {
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

    final originalPosts = List<NewsPost>.from(newsPosts);
    addTearDown(() {
      newsPosts
        ..clear()
        ..addAll(originalPosts);
      comments.removeWhere((c) => c.postId == 'comments_feed_test_post');
    });

    final post = NewsPost(
      id: 'comments_feed_test_post',
      clubId: clubs.first.id,
      authorId: 'comments_feed_test_author',
      content: 'A post that can be commented on.',
      createdAt: DateTime.now(),
    );
    newsPosts
      ..clear()
      ..add(post);
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: FeedScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // "All" shows every club's posts regardless of what alice follows.
    if (find.text('All').evaluate().isNotEmpty) {
      await tester.tap(find.text('All'));
      await tester.pump(const Duration(milliseconds: 400));
    }

    final commentButton = find.byKey(ValueKey('home-feed-comment-${post.id}'));
    expect(commentButton, findsOneWidget);

    await tester.tap(commentButton);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(CommentsSheet), findsOneWidget);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('comments-sheet-empty');

    // The composer is present and the send button only lights up once there is
    // something to send.
    final sendButton = find.byKey(const ValueKey('post-comment-send'));
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.widget<IconButton>(sendButton).onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'Nice post!');
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<IconButton>(sendButton).onPressed, isNotNull);

    await binding.takeScreenshot('comments-sheet-composing');
    expect(tester.takeException(), isNull);
  });
}
