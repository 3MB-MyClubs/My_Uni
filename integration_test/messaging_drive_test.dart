import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/messages_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

/// Drives the messaging inbox as Hakan (u5) to verify the Clubs area:
///  - club joint discussions (group channels)
///  - 1-on-1 direct messages with a club
///  - "Message a club" search → start a new club DM → it appears in Clubs
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 350));
    await binding.takeScreenshot(name);
  }

  Future<void> goBack(WidgetTester t) async {
    final nav = t.state<NavigatorState>(find.byType(Navigator).first);
    nav.pop();
    for (int i = 0; i < 8; i++) {
      await t.pump(const Duration(milliseconds: 120));
    }
  }

  testWidgets('Messaging — students vs clubs, club DMs and discussions',
      (tester) async {
    await messageService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await themeService.initialize();
    contentStore.applyToLists();
    authService.login('htuncay23@ku.edu.tr'); // Hakan (u5)
    await themeService.setDark(false);

    await tester.pumpWidget(
      ListenableBuilder(
        listenable: themeService,
        builder: (context, _) => ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: themeService.isDark ? ThemeMode.dark : ThemeMode.light,
            theme: ThemeData(brightness: Brightness.light),
            darkTheme: ThemeData(brightness: Brightness.dark),
            home: MessagesScreen(),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();

    // 01 — Students tab (people only)
    await shot(tester, '01-inbox-students');

    // Switch to Clubs tab
    final clubsTab = find.text('Clubs');
    if (clubsTab.evaluate().isNotEmpty) {
      await tester.tap(clubsTab.first);
      await tester.pump(const Duration(milliseconds: 400));
    }
    // 02 — Clubs tab: discussions + existing 1-on-1 club DM (KUFoto)
    await shot(tester, '02-inbox-clubs');

    // 03 — open the 1-on-1 club DM (KUFoto)
    final kufoto = find.textContaining('KUFoto');
    if (kufoto.evaluate().isNotEmpty) {
      await tester.tap(kufoto.first);
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, '03-club-dm-conversation');
      await goBack(tester);
    }

    // 04 — search a club to message → "Message a club" results
    final search = find.byType(TextField);
    if (search.evaluate().isNotEmpty) {
      await tester.enterText(search.first, 'Dans');
      await tester.pump(const Duration(milliseconds: 400));
      await shot(tester, '04-message-a-club');

      // tap the club result's "Message" action → opens a 1-on-1 club DM
      final messageBtn = find.text('Message');
      if (messageBtn.evaluate().isNotEmpty) {
        await tester.tap(messageBtn.first);
        await tester.pump(const Duration(milliseconds: 700));
        // send a first message to the club
        final composer = find.byType(TextField);
        if (composer.evaluate().isNotEmpty) {
          await tester.enterText(
              composer.first, 'Hi! How do I sign up for the dance club? 💃');
          await tester.pump(const Duration(milliseconds: 300));
          await tester.tap(find.byIcon(Icons.send_rounded));
          await tester.pump(const Duration(milliseconds: 800));
          await shot(tester, '05-new-club-dm');
        }
        await goBack(tester);
      }

      // 06 — Clubs tab now lists the new club DM under "Direct messages with clubs"
      await tester.pump(const Duration(milliseconds: 400));
      await shot(tester, '06-clubs-after-new-dm');
    }

    // 07 — open a club joint discussion (group channel)
    // clear search first so the discussions list is visible
    if (search.evaluate().isNotEmpty) {
      await tester.enterText(search.first, '');
      await tester.pump(const Duration(milliseconds: 400));
    }
    final disc = find.textContaining('Bilgisayar');
    if (disc.evaluate().isNotEmpty) {
      await tester.tap(disc.first);
      await tester.pump(const Duration(milliseconds: 700));
      await shot(tester, '07-club-discussion');
    }
  });
}
