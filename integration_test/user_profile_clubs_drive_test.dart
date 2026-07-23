import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/student_campus_profile.dart';

/// Verifies another student's profile lists their clubs inline (like the
/// own-profile Clubs card) instead of hiding them behind the Clubs stat.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Visited profile shows inline clubs card with roles', (
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

    // Visit Can (u2): 5 subscribed clubs, so the card shows 4 + "See all".
    final can = users.firstWhere((u) => u.id == 'u2');
    userState.setMajor(can.id, 'Computer Engineering');
    userState.setYear(can.id, '2nd Year');

    // Give Can a board role so the burgundy role badge renders.
    final roleClub = clubs.firstWhere((c) => c.id == can.subscribedClubIds[1]);
    if (!roleClub.boardMemberIds.contains(can.id)) {
      roleClub.boardMemberIds.add(can.id);
    }
    roleClub.boardMemberTitles[can.id] = 'Vice President';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: UserProfileScreen(user: can),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));

    // The inline clubs card is on screen without tapping anything.
    expect(find.text('CLUBS · 5'), findsOneWidget);
    expect(find.textContaining('Vice President'), findsOneWidget);
    expect(find.text('See all'), findsOneWidget);
    final profileView = tester.widget<StudentCampusProfileView>(
      find.byType(StudentCampusProfileView),
    );
    expect(profileView.memberships.first.club.id, roleClub.id);
    expect(profileView.memberships.first.role, 'Vice President');

    await tester.scrollUntilVisible(find.text('See all'), 120);
    await tester.pump(const Duration(milliseconds: 400));

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('user-profile-clubs-card');

    expect(tester.takeException(), isNull);
  });
}
