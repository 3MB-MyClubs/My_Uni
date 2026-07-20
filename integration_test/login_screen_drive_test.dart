import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/terms_acceptance_service.dart';

/// Drives the entry experience ("Login Screen v2" design handoff):
///  A) App opens directly on the Login Screen — crest, wordmark, fields.
///  B) Tapping "Sign up" hands off to the multi-step sign-up flow.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot() async {
    await hiveBootstrap.initialize();
    await notificationService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    await termsAcceptanceService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
  }

  testWidgets('App opens on Login Screen v2, Sign up → flow', (tester) async {
    await boot();

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 700));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    if (find.text('Agree and continue').evaluate().isNotEmpty) {
      await binding.takeScreenshot('login-00-community-terms');
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.text('Agree and continue'));
      await tester.pump(const Duration(milliseconds: 700));
    }
    await binding.takeScreenshot('login-01-root-light');

    // Brand + login affordances are the root UI.
    expect(find.text('KOÇ UNIVERSITY'), findsOneWidget);
    expect(find.text('ClubUp'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
    expect(find.text('@ku.edu.tr'), findsOneWidget);
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('Club admin sign in'), findsOneWidget);

    // Filled fields flip the submit button to its active gradient state.
    await tester.enterText(find.byType(TextField).at(0), 'alice');
    await tester.enterText(find.byType(TextField).at(1), '111111');
    // Two pumps: the first frame starts the submit button's enable animation,
    // the second advances past its 220ms so the gradient is fully in.
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('login-02-filled-light');

    // Dark theme pass (two pumps so the rebuilt frame is actually rendered
    // before capture).
    await themeService.setDark(true);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('login-03-filled-dark');
    await themeService.setDark(false);
    await tester.pump(const Duration(milliseconds: 500));

    // Hand off to the multi-step sign-up flow.
    await tester.tap(find.text('Sign up'));
    await tester.pump(const Duration(milliseconds: 700));
    await binding.takeScreenshot('login-04-signup-step1');
    expect(find.textContaining('school email'), findsOneWidget);
  });
}
