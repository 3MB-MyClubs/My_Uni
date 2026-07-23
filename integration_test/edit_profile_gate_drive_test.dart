import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot() async {
    authService.logout(); // clear any session leaked from a previous test
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
  }

  Widget wrap() => MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SettingsScreen(onLogout: () {}),
  );

  testWidgets('Student sees Edit Profile in Settings', (tester) async {
    await boot();
    authService.login('alice@ku.edu.tr', '11111111'); // a student

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 500));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('settings-student');

    expect(authService.currentUser, isNotNull);
    expect(find.text('Edit Profile'), findsOneWidget);

    // Opens the full editor.
    await tester.tap(find.text('Edit Profile'));
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot('settings-student-editor');
    expect(find.text('University year'), findsOneWidget);
  });

  testWidgets('Club admin does NOT see Edit Profile', (tester) async {
    await boot();
    authService.login('kuacm@ku.edu.tr', '11111111'); // a club admin

    await tester.pumpWidget(wrap());
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('settings-club');

    expect(authService.currentAdmin, isNotNull);
    expect(find.text('Edit Profile'), findsNothing);
    expect(find.text('Club Photo'), findsOneWidget);
  });
}
