import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/post_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/comment_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Comments are disabled for posts: students can still view the post detail,
/// but no comment list, composer, or send action is available.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Post detail hides comments and disables comment creation', (
    tester,
  ) async {
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

    final club = clubs.first;
    final post = NewsPost(
      id: 'comments_disabled_test_post',
      clubId: club.id,
      authorId: 'comments_disabled_test_author',
      content: 'Comments are disabled on this post.',
      createdAt: DateTime.now(),
    );
    final before = commentStore.countFor(post.id);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PostDetailScreen(
            post: post,
            clubColor: const Color(0xFF8C1D40),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.textContaining('Comments · '), findsNothing);
    expect(find.byIcon(Icons.mode_comment_outlined), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsNothing);

    await commentStore.add(post: post, content: 'This should not appear');
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('This should not appear'), findsNothing);
    expect(commentStore.countFor(post.id), before);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('comments-disabled');

    expect(tester.takeException(), isNull);
  });
}
