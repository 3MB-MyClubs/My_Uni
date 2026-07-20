import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';

/// Club admin on their OWN club profile: compact posts + delete post/event.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Own club profile — compact posts, admin can delete', (
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
    contentStore.loadBoardMemberIds();
    contentStore.loadBoardMemberTitles();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM (c4) admin

    final club = clubs.firstWhere((c) => c.id == 'c4');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ClubProfileScreen(
            club: club,
            color: AppColors.primaryRed,
            onSettings: () {},
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('club-posts-compact');

    // Admin ⋯ menus exist (app bar + one per post).
    final menus = find.byIcon(Icons.more_horiz_rounded);
    expect(menus, findsWidgets);

    // Delete the first post via its ⋯ menu (index 1; index 0 is the app bar).
    final postsBefore = newsPosts.where((p) => p.clubId == 'c4').length;
    await tester.tap(menus.at(1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete post'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete')); // confirm
    await tester.pump(const Duration(milliseconds: 500));

    expect(newsPosts.where((p) => p.clubId == 'c4').length, postsBefore - 1);
    expect(tester.takeException(), isNull);

    // Switch to the EVENTS tab and delete an event.
    await tester.tap(find.text('EVENTS'));
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('club-events-admin');

    final eventsBefore = events.where((e) => e.clubId == 'c4').length;
    final eventMenus = find.byIcon(Icons.more_horiz_rounded);
    await tester.tap(eventMenus.at(1));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete event'));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.text('Delete'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(events.where((e) => e.clubId == 'c4').length, eventsBefore - 1);
    expect(tester.takeException(), isNull);
  });
}
