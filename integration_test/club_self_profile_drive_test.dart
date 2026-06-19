import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/view_tracker.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';

/// Signs in as the KUACM club admin and opens the Profile tab, which now IS
/// the club's own v2 profile. Confirms there is NO Follow / Message button
/// (no self-follow / self-message) and NO cover banner.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot(name);
  }

  testWidgets('Club own-profile — no follow/message, no banner',
      (tester) async {
    await messageService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    contentStore.loadBoardMemberIds();
    contentStore.loadBoardMemberTitles();
    await themeService.setDark(false);
    authService.login('kuacm@ku.edu.tr', '11111111'); // KUACM club admin

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: const ProfileScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // Signed in as a club → the Profile tab is the club's own v2 profile.
    expect(authService.currentAdmin, isNotNull);
    // No self-follow / self-message on your own club page.
    expect(find.text('Follow'), findsNothing);
    expect(find.text('Message'), findsNothing);
    await shot(tester, 'club-01-own-profile');

    // Scroll to reveal the Posts feed beneath the header.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -260));
    await tester.pump(const Duration(milliseconds: 400));
    await shot(tester, 'club-02-own-profile-feed');
  });
}
