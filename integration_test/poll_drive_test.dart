import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/post_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/poll_store.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Phase 4: polls render on posts, votes show percentage bars, and the
/// poll + announcement fields survive the Hive round-trip.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Student votes on a poll and sees live results', (tester) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await pollStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');

    final pollPost = NewsPost(
      id: 'test_poll_post',
      clubId: 'c1',
      authorId: 'c1',
      content: 'Which workshop should we run next?',
      createdAt: DateTime.now(),
      poll: const PollData(
        question: 'Pick our next workshop topic',
        options: ['Flutter', 'Rust', 'Machine Learning'],
      ),
      isAnnouncement: true,
    );

    // Model round-trip keeps poll + announcement.
    final roundTrip = NewsPost.fromMap(pollPost.toMap());
    expect(roundTrip.poll?.question, 'Pick our next workshop topic');
    expect(roundTrip.poll?.options.length, 3);
    expect(roundTrip.isAnnouncement, isTrue);

    newsPosts.insert(0, pollPost);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: PostDetailScreen(
            post: pollPost,
            clubColor: const Color(0xFF8C1D40),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Pick our next workshop topic'), findsOneWidget);
    expect(find.text('Rust'), findsOneWidget);

    // Vote and check results state.
    await tester.tap(find.text('Rust'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(pollStore.myVote('test_poll_post', 'u1'), 1);
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('1 vote'), findsOneWidget);

    // Change vote.
    await tester.tap(find.text('Flutter'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(pollStore.myVote('test_poll_post', 'u1'), 0);
    expect(pollStore.totalVotes('test_poll_post'), 1);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('phase4-poll');

    newsPosts.removeWhere((p) => p.id == 'test_poll_post');
    expect(tester.takeException(), isNull);
  });
}
