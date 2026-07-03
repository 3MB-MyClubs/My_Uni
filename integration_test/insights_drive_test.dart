import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/admin_dashboard.dart';
import 'package:flutter_application_1/screens/club_insights_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/checkin_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Phase 5: club insights screen renders engagement data (with check-in
/// rates) and the super-admin dashboard shows totals + a club leaderboard.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> bootstrap() async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await checkinStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
  }

  testWidgets('Club insights shows tiles, attendance bars and top posts', (
    tester,
  ) async {
    await bootstrap();

    // Pick a club with both events and posts, and check one attendee in.
    final club = clubs.firstWhere(
      (c) =>
          events.any((e) => e.clubId == c.id) &&
          newsPosts.any((p) => p.clubId == c.id),
    );
    final clubEvent = events.firstWhere((e) => e.clubId == club.id);
    if (clubEvent.attendeeUserIds.isNotEmpty &&
        !checkinStore.isCheckedIn(clubEvent.id, clubEvent.attendeeUserIds.first)) {
      await checkinStore.toggle(
        eventId: clubEvent.id,
        userId: clubEvent.attendeeUserIds.first,
        actorId: club.id,
      );
    }

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClubInsightsScreen(club: club, accent: const Color(0xFF8C1D40)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.text('Insights'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('RSVPs'), findsOneWidget);
    expect(find.text('EVENT ATTENDANCE'), findsOneWidget);
    expect(find.textContaining('%'), findsWidgets);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('phase5-club-insights');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Super admin dashboard shows totals and leaderboard', (
    tester,
  ) async {
    authService.login(appAdmin.email, appAdmin.password);

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: AdminDashboard())),
    );
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.text('Admin Dashboard'), findsOneWidget);
    expect(find.text('Students'), findsOneWidget);
    expect(find.text('CLUB LEADERBOARD'), findsOneWidget);
    expect(find.textContaining('followers · '), findsWidgets);

    await binding.takeScreenshot('phase5-admin-dashboard');
    expect(tester.takeException(), isNull);
  });
}
