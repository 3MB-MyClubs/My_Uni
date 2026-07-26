import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// The real nav-bar "+" a club admin sees must jump straight to event
/// creation — no Post/Event chooser in between.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Club admin center + opens event creation directly', (
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
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM (c4) admin
    await onboardingService.complete('cadmin5');

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainNavScreen(isAdmin: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    // Straight to the event form — no chooser sheet in between.
    expect(find.text('Create'), findsNothing);
    expect(find.text('New Event'), findsOneWidget);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('nav-center-add-event-form');

    expect(tester.takeException(), isNull);
  });
}
