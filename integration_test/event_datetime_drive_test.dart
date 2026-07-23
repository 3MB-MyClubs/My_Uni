import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/create_event_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';

/// Confirms the create-event date/time uses the single iOS wheel sheet
/// (one scroll for date + time) instead of the Material calendar + clock.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Create event — date/time opens the wheel sheet', (tester) async {
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: const CreateEventScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // The "Starts" date/time pill is near the top.
    final start = DateTime.now().add(const Duration(hours: 1));
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${months[start.month - 1]} ${start.day}, ${start.year}';

    await tester.tap(find.text(dateStr).first);
    await tester.pump(const Duration(milliseconds: 500));

    // The wheel sheet is up: Cancel / Starts / Done header.
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Starts'), findsWidgets);
    await binding.takeScreenshot('dt-01-wheel');

    await tester.tap(find.text('Done'));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('dt-02-after');
  });
}
