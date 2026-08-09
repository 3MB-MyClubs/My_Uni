import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/news_post.dart';
import 'package:flutter_application_1/screens/club_insights_screen.dart';
import 'package:flutter_application_1/screens/post_detail_screen.dart';
import 'package:flutter_application_1/services/club_insights_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('insights matches the ranked club analytics layout', (
    tester,
  ) async {
    await themeService.setDark(true, persistToAccount: false);

    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;

    const clubId = 'insights-club';
    final club = Club(
      id: clubId,
      name: 'Koç University Atatürk Thought Club',
      shortName: 'KUADK',
      description: '',
      adminUserIds: const ['admin-1'],
      createdAt: DateTime(2024, 7, 24),
    );
    clubs.add(club);
    supabaseClubMemberCounts[clubId] = 3;

    final eventDate = DateTime(2026, 8, 10, 18);
    events.add(
      Event(
        id: 'insights-event',
        clubId: clubId,
        title: 'Club gathering',
        description: '',
        dateTime: eventDate,
        endTime: eventDate.add(const Duration(hours: 1)),
        location: 'Campus',
        attendeeUserIds: const ['u1', 'u2', 'u3', 'u4'],
      ),
    );

    final postFixtures = [
      ('p1', 'Ghjxhv', DateTime(2026, 8, 2), 2),
      ('p2', 'hic bisey', DateTime(2026, 8, 1), 4),
      ('p3', 'Kjvbsdvh aslbc', DateTime(2026, 7, 30), 3),
      ('p4', 'test', DateTime(2026, 7, 28), 2),
      ('p5', 'Gcyyub', DateTime(2026, 7, 24), 1),
    ];
    for (final fixture in postFixtures) {
      final (id, content, createdAt, likeCount) = fixture;
      newsPosts.add(
        NewsPost(
          id: id,
          clubId: clubId,
          authorId: 'admin-1',
          content: content,
          createdAt: createdAt,
        ),
      );
      supabasePostLikeCounts[id] = likeCount;
    }
    final postsById = {for (final post in newsPosts) post.id: post};
    final previewData = ClubInsightsData(
      followers: 3,
      totalRsvps: 4,
      totalLikes: 12,
      totalViews: 153,
      postCount: 5,
      since: DateTime(2024, 7, 24),
      events: [
        EventAttendanceStat(event: events.last, rsvpCount: 4, checkinCount: 0),
      ],
      topPosts: [
        PostStat(post: postsById['p2']!, likes: 4, views: 10),
        PostStat(post: postsById['p3']!, likes: 3, views: 10),
        PostStat(post: postsById['p4']!, likes: 2, views: 9),
        PostStat(post: postsById['p5']!, likes: 1, views: 9),
        PostStat(post: postsById['p1']!, likes: 2, views: 3),
      ],
    );

    addTearDown(() async {
      tester.view.reset();
      clubs.removeWhere((item) => item.id == clubId);
      events.removeWhere((item) => item.clubId == clubId);
      newsPosts.removeWhere((item) => item.clubId == clubId);
      supabaseClubMemberCounts.remove(clubId);
      for (final fixture in postFixtures) {
        supabasePostLikeCounts.remove(fixture.$1);
      }
      await themeService.setDark(false, persistToAccount: false);
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          themeMode: ThemeMode.dark,
          darkTheme: ThemeData.dark(useMaterial3: true),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubInsightsScreen(
            club: club,
            accent: const Color(0xFF9E2045),
            previewData: previewData,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('KUADK · @kuadk'), findsOneWidget);
    expect(find.text('SINCE 24 JUL 2024'), findsOneWidget);
    expect(find.byKey(const ValueKey('insights-metric-followers')), findsOne);
    expect(find.byKey(const ValueKey('insights-metric-rsvps')), findsOne);
    expect(find.byKey(const ValueKey('insights-metric-likes')), findsOne);
    expect(find.byKey(const ValueKey('insights-metric-views')), findsOne);

    expect(find.text('12'), findsOneWidget);
    expect(find.text('153'), findsOneWidget);
    expect(find.text('all time, by views'), findsOneWidget);

    final second = find.byKey(const ValueKey('insights-post-p2'));
    final third = find.byKey(const ValueKey('insights-post-p3'));
    expect(second, findsOneWidget);
    expect(third, findsOneWidget);
    expect(tester.getTopLeft(second).dy, lessThan(tester.getTopLeft(third).dy));

    await expectLater(
      find.byType(Scaffold).first,
      matchesGoldenFile('../design-qa-club-insights-implementation.png'),
    );

    await tester.drag(
      find.byKey(const ValueKey('club-insights-scroll')),
      const Offset(0, 300),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);

    await tester.tap(second);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(PostDetailScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  });
}
