import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 350));
    await binding.takeScreenshot(name);
  }

  Future<void> boot(WidgetTester tester, bool dark) async {
    await messageService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    // The real feed has a pre-existing setState-during-build bug
    // (ViewTracker.recordView -> notifyListeners while PostCard is still
    // mounting) that only surfaces under the test binding's synchronous pump.
    // Not related to the nav bar redesign under test, so sidestep it here by
    // emptying the feed rather than touching feed_screen.dart.
    newsPosts.clear();
    authService.login('alice@ku.edu.tr');
    await tutorialService.complete(authService.currentUser!.id);
    await themeService.setDark(dark);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          home: const MainNavScreen(isAdmin: false),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
  }

  testWidgets('Liquid glass bottom nav — light mode', (tester) async {
    await boot(tester, false);
    await shot(tester, 'nav-01-light-home');

    await tester.tap(find.text('Events'));
    await tester.pump(); // capsule starts sliding
    await tester.pump(const Duration(milliseconds: 120));
    await shot(tester, 'nav-02-light-mid-transition');

    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'nav-03-light-events-settled');

    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'nav-04-light-profile');
  });

  testWidgets('Liquid glass bottom nav — dark mode', (tester) async {
    await boot(tester, true);
    await shot(tester, 'nav-05-dark-home');

    await tester.tap(find.text('Alerts'));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'nav-06-dark-alerts');
  });
}
