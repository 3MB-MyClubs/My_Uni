import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/post_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/comment_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Phase 1: a student writes a comment on a post, sees it render, the count
/// updates, the club gets notified, and the author can delete it again.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Student can comment on a post and delete their comment', (
    tester,
  ) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');

    final post = newsPosts.first;
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

    // Empty state or existing list header renders.
    expect(find.textContaining('Comments · '), findsOneWidget);

    // Write and send a comment.
    await tester.enterText(
      find.byType(TextField).last,
      'Harika etkinlikti, tebrikler!',
    );
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Harika etkinlikti, tebrikler!'), findsOneWidget);
    expect(commentStore.countFor(post.id), before + 1);

    // The club account was notified.
    expect(
      userState.dynamicNotifications.any(
        (n) => n.id.startsWith('post_comment_${post.id}_u1'),
      ),
      isTrue,
    );

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('phase1-comments');

    // Author deletes their own comment.
    await tester.tap(find.byIcon(Icons.delete_outline_rounded).last);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Harika etkinlikti, tebrikler!'), findsNothing);
    expect(commentStore.countFor(post.id), before);

    expect(tester.takeException(), isNull);
  });
}
