import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/theme_choice_screen.dart';
import 'package:flutter_application_1/screens/this_week_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 350));
    await binding.takeScreenshot(name);
  }

  testWidgets('First-time theme picker — light, preview dark, proceed', (
    tester,
  ) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    contentStore.applyToLists();
    authService.login('htuncay23@ku.edu.tr', '111111');
    await themeService.setDark(false); // first-time = light

    var chosen = false;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setHarness) => ListenableBuilder(
          listenable: themeService,
          builder: (context, _) => ProviderScope(
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
              theme: ThemeData(brightness: Brightness.light),
              darkTheme: ThemeData(brightness: Brightness.dark),
              home: chosen
                  ? const Scaffold(
                      body: Center(child: Text('Proceeded to the app')),
                    )
                  : ThemeChoiceScreen(
                      onChoose: (d) async {
                        await themeService.setDark(d);
                        setHarness(() => chosen = true);
                      },
                    ),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // 01 — presented in light
    expect(themeService.isDark, false);
    await shot(tester, 'tc-01-light');

    // 02 — tap Dark → live preview (whole screen goes dark)
    await tester.tap(find.text('Dark').first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(themeService.isDark, true);
    await shot(tester, 'tc-02-dark-preview');

    // back to light to confirm it's interactive both ways
    await tester.tap(find.text('Light').first);
    await tester.pump(const Duration(milliseconds: 300));
    expect(themeService.isDark, false);

    // 03 — Continue proceeds
    await tester.tap(find.textContaining('Continue').first);
    await tester.pump(const Duration(milliseconds: 500));
    expect(chosen, true);
    await shot(tester, 'tc-03-proceeded');
  });

  testWidgets('Events (Week) — pull to refresh', (tester) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    contentStore.applyToLists();
    authService.login('htuncay23@ku.edu.tr', '111111');
    await themeService.setDark(false);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: ThisWeekScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    await shot(tester, 'ev-01-week');

    // Pull down to refresh and capture the spinner mid-refresh.
    await tester.fling(
      find.byType(Scrollable).first,
      const Offset(0, 320),
      1000,
    );
    await tester.pump(); // start the indicator
    await tester.pump(const Duration(milliseconds: 200));
    await shot(tester, 'ev-02-refreshing');

    // Let the refresh settle.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(milliseconds: 300));
    await shot(tester, 'ev-03-after-refresh');
  });
}
