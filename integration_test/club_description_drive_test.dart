import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';

/// Signs in as the KUACM club admin and edits the club description from
/// Settings, confirming it saves onto the club itself.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot(name);
  }

  testWidgets('Club description — editable from Settings', (tester) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM club admin

    final club = clubs.firstWhere((c) => c.adminUserIds.contains('cadmin5'));

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: SettingsScreen(onLogout: () {}),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // Settings shows the Club section with the description tile.
    expect(find.text('Club Description'), findsOneWidget);
    await shot(tester, 'desc-01-settings');

    // Open the edit sheet.
    await tester.tap(find.text('Club Description'));
    await tester.pump(const Duration(milliseconds: 500));
    await shot(tester, 'desc-02-edit-sheet');

    // Replace the description and save.
    const newDesc = 'Hack-KU 2026 sign-ups are open — weekly workshops, '
        'mentorship and a spring hackathon. All majors welcome!';
    await tester.enterText(find.byType(TextField).first, newDesc);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Save'));
    await tester.pump(const Duration(milliseconds: 500));

    // The edit landed on the club object (so it shows everywhere).
    expect(club.description, newDesc);
    await shot(tester, 'desc-03-after-save');
  });
}
