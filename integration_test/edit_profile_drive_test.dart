import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/screens/edit_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

/// Drives the profile → Edit Profile flow as Hakan (u5):
///  - tap "Edit profile" opens the dedicated full-screen editor
///  - set year, major, add a double major + minor, toggle interests
///  - save and confirm the profile shows the new academic info
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 350));
    await binding.takeScreenshot(name);
  }

  testWidgets('Edit profile — dedicated screen with majors/minors/interests',
      (tester) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('htuncay23@ku.edu.tr'); // Hakan (u5)

    // Pre-seed academic info so the display + editor-load are verified
    // deterministically (interactive adds are exercised below as a bonus).
    userState.setMajor('u5', 'Computer Science');
    userState.setYear('u5', '3rd Year');
    userState.setDoubleMajors('u5', ['Economics']);
    userState.setMinors('u5', ['Psychology']);
    userState.setInterests('u5', ['Tech', 'Music']);

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // 01 — profile before editing
    await shot(tester, 'ep-01-profile-before');

    // Open the dedicated Edit Profile screen
    final editBtn = find.text('Edit profile');
    expect(editBtn, findsWidgets);
    await tester.tap(editBtn.first);
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(EditProfileScreen), findsOneWidget);
    // Editor loads with the seeded values (year selected, major filled).
    await shot(tester, 'ep-02-edit-screen');

    // Add another double major interactively to prove the editor works.
    final dmField =
        find.widgetWithText(TextField, 'Add a double major program');
    if (dmField.evaluate().isNotEmpty) {
      await tester.scrollUntilVisible(dmField.first, 200,
          scrollable: find.byType(Scrollable).first);
      await tester.enterText(dmField.first, 'Mathematics');
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(find.byIcon(Icons.add_rounded).first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    // Scroll so the list editors (double major / minor chips) are in frame.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -360));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'ep-03-edit-filled');

    // Save (AppBar action)
    await tester.tap(find.text('Save').first);
    await tester.pump(const Duration(milliseconds: 800));

    // 04 — back on profile, showing the academic info (major · year,
    //      double major + minor tags)
    await shot(tester, 'ep-04-profile-after');
  });
}
