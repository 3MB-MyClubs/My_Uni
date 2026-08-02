import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/feed_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('feed_likers_ui_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await viewTracker.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('liked-by row opens the animated liker sheet', (tester) async {
    final originalPosts = List<NewsPost>.from(newsPosts);
    final originalEvents = List<Event>.from(events);
    final post = newsPosts.firstWhere((candidate) => candidate.id == 'n1');
    addTearDown(() {
      newsPosts
        ..clear()
        ..addAll(originalPosts);
      events
        ..clear()
        ..addAll(originalEvents);
      authService.logout();
    });

    newsPosts
      ..clear()
      ..add(post);
    events.clear();
    expect(authService.login('alice@ku.edu.tr', '111111'), isTrue);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FeedScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    final likedBy = find.byKey(const ValueKey('post-liked-by-n1'));
    expect(likedBy, findsOneWidget);
    expect(
      find.descendant(of: likedBy, matching: find.byType(UserAvatar)),
      findsOneWidget,
    );
    expect(find.textContaining('Liked by'), findsOneWidget);

    await tester.tap(likedBy);
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.byKey(const ValueKey('post-likers-sheet-n1')), findsOneWidget);
    expect(find.text('Can Serbester'), findsOneWidget);
    expect(find.text('Emir Karaarslan'), findsOneWidget);
    expect(find.text('Deniz Kaya'), findsOneWidget);
  });
}
