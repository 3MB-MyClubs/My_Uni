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
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// The real nav-bar "+" a club admin sees must open the Post/Event chooser —
/// not jump straight to event creation.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Club admin center + opens the Post/Event chooser', (
    tester,
  ) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM (c4) admin

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainNavScreen(isAdmin: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    await tester.tap(find.byIcon(Icons.add_rounded));
    await tester.pump(const Duration(milliseconds: 500));

    // The chooser sheet is up, not the event composer.
    expect(find.text('Create'), findsOneWidget);
    expect(find.text('Post'), findsOneWidget);
    expect(find.text('Event'), findsOneWidget);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('nav-center-add-chooser');

    // Tapping Post opens the club's quick composer sheet (not event creation).
    await tester.tap(find.text('Post'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Create Event'), findsNothing);

    expect(tester.takeException(), isNull);
  });
}
