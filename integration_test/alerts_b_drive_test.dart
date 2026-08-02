import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/notifications_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';

/// Drives the Style-B notification center as Hakan (u5):
///  - All view with New / Earlier groups + filter chips with counts
///  - Events and You filters actually filter
///  - a pending follow request shows working Accept / Decline
///  - mark-all-read clears the New group
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 350));
    await binding.takeScreenshot(name);
  }

  testWidgets('Alerts Style B — filtered & grouped', (tester) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('htuncay23@ku.edu.tr', '111111'); // Hakan (u5)

    // Seed a pending follow request so Accept / Decline is exercised.
    userState.sendFollowRequest('u3', 'u5', 'Emir Karaarslan');

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: const NotificationsScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // 01 — All: New / Earlier groups + filter chips
    await shot(tester, 'nb-01-all');

    // 02 — Events filter
    if (find.text('Events').evaluate().isNotEmpty) {
      await tester.tap(find.text('Events').first);
      await tester.pump(const Duration(milliseconds: 400));
      await shot(tester, 'nb-02-events');
    }

    // 03 — You filter (shows the pending follow request + Accept/Decline)
    if (find.text('You').evaluate().isNotEmpty) {
      await tester.tap(find.text('You').first);
      await tester.pump(const Duration(milliseconds: 400));
      await shot(tester, 'nb-03-you');
    }

    // Exercise Accept (a working action) if present
    if (find.text('Accept').evaluate().isNotEmpty) {
      await tester.tap(find.text('Accept').first);
      await tester.pump(const Duration(milliseconds: 500));
      await shot(tester, 'nb-04-after-accept');
    }

    // 05 — back to All, then mark all read
    if (find.text('All').evaluate().isNotEmpty) {
      await tester.tap(find.text('All').first);
      await tester.pump(const Duration(milliseconds: 300));
    }
    if (find.byIcon(Icons.done_all_rounded).evaluate().isNotEmpty) {
      await tester.tap(find.byIcon(Icons.done_all_rounded).first);
      await tester.pump(const Duration(milliseconds: 500));
      await shot(tester, 'nb-05-mark-all-read');
    }
  });
}
