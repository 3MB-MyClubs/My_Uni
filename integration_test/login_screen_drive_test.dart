import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/notification_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';

/// Drives the new entry experience:
///  A) App opens directly on the Login Screen (design handoff recreation).
///  B) Tapping "Sign up" hands off to the multi-step sign-up flow.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> boot() async {
    await messageService.initialize();
    await notificationService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
  }

  testWidgets('App opens on Login Screen, Sign up → flow', (tester) async {
    await boot();

    await tester.pumpWidget(const MyApp());
    await tester.pump(const Duration(milliseconds: 700));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('login-01-root');

    // Brand + login affordances are the root UI.
    expect(find.text('Koç University'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Create a student account'), findsOneWidget);

    // Hand off to the multi-step sign-up flow.
    await tester.tap(find.text('Create a student account'));
    await tester.pump(const Duration(milliseconds: 700));
    await binding.takeScreenshot('login-02-signup-step1');
    expect(find.textContaining('school email'), findsOneWidget);
  });
}
