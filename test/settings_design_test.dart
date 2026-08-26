import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/settings_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// `profile-settings-light` / `profile-settings-dark` (Figma `120:3` /
/// `120:144`) — the student Settings page.
///
/// The mock directory ships empty (`users` is `[]`), so each session is
/// registered through `signUp` rather than signed in as a seeded student.
void main() {
  late Directory tempDir;
  var accountCount = 0;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('settings_design_test_');
    Hive.init(tempDir.path);
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');
    await authService.logout();
    users.removeWhere((user) => user.email.endsWith('@ku.edu.tr'));
  });

  tearDown(() async {
    await authService.logout();
    await themeService.setDark(false);
    await localeService.setLanguage('en');
  });

  void signInStudent() {
    accountCount += 1;
    final email = 'settings.design$accountCount@ku.edu.tr';
    expect(authService.signUp('Design Tester', email, '135790'), isTrue);
  }

  Future<void> pumpSettings(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(onLogout: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('a student gets the profile-settings frame', (tester) async {
    signInStudent();
    userState.savedPostIds
      ..clear()
      ..addAll(['saved-a', 'saved-b']);
    addTearDown(userState.savedPostIds.clear);

    await pumpSettings(tester);

    // `sec-account` / `sec-preferences` / `sec-support` / `sec-danger-zone`.
    expect(find.text('ACCOUNT'), findsOneWidget);
    expect(find.text(S.settingsPreferences.toUpperCase()), findsOneWidget);
    expect(find.text(S.settingsSupport.toUpperCase()), findsOneWidget);
    expect(find.text(S.settingsDangerZone.toUpperCase()), findsOneWidget);

    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text(S.settingsEditProfileSubtitle), findsOneWidget);
    expect(find.text(S.settingsPrivacy), findsOneWidget);
    expect(find.text(S.settingsSavedItems), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text(S.settingsReportProblem), findsOneWidget);
    expect(find.text(S.settingsAboutClubUp), findsOneWidget);
    expect(find.text(S.settingsWebVersion), findsOneWidget);
    expect(find.text('Log Out'), findsOneWidget);
    expect(find.text('Delete Account'), findsOneWidget);

    // Stripped to the frame: the old identity card, the "Change my name" row
    // (now a field inside Edit Profile) and the Support & Legal group are gone.
    expect(find.text('Change my name'), findsNothing);
    // The old screen titled the appearance row "Light Mode"; the frame's row is
    // titled "Appearance" with the state in the toggle beside it.
    expect(find.text('Light Mode'), findsNothing);
    expect(find.text('Appearance'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the appearance and language toggles drive the services', (
    tester,
  ) async {
    signInStudent();
    await pumpSettings(tester);

    expect(find.byType(SettingsSegmentedToggle), findsNWidgets(2));
    expect(themeService.isDark, isFalse);

    await tester.tap(find.text(S.settingsDarkOption));
    await tester.pump(const Duration(milliseconds: 300));
    expect(themeService.isDark, isTrue);

    await tester.tap(find.text(S.settingsLightOption));
    await tester.pump(const Duration(milliseconds: 300));
    expect(themeService.isDark, isFalse);

    await tester.tap(find.text('Türkçe'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(localeService.languageCode, 'tr');

    await tester.tap(find.text('English'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(localeService.languageCode, 'en');
    expect(tester.takeException(), isNull);
  });

  testWidgets('preference toggle pills slide briefly between choices', (
    tester,
  ) async {
    signInStudent();
    await pumpSettings(tester);

    Finder indicatorFor(Finder toggle) => find.descendant(
      of: toggle,
      matching: find.byKey(
        const ValueKey('settings-segmented-indicator-surface'),
      ),
    );

    final appearanceToggle = find.byType(SettingsSegmentedToggle).at(0);
    final appearanceIndicator = indicatorFor(appearanceToggle);
    final startAppearanceX = tester.getTopLeft(appearanceIndicator).dx;

    await tester.tap(find.text(S.settingsDarkOption));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final midAppearanceX = tester.getTopLeft(appearanceIndicator).dx;
    await tester.pumpAndSettle();
    final endAppearanceX = tester.getTopLeft(appearanceIndicator).dx;

    expect(midAppearanceX, greaterThan(startAppearanceX));
    expect(midAppearanceX, lessThan(endAppearanceX));

    final languageToggle = find.byType(SettingsSegmentedToggle).at(1);
    final languageIndicator = indicatorFor(languageToggle);
    final startLanguageX = tester.getTopLeft(languageIndicator).dx;

    await tester.tap(find.text('Türkçe'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    final midLanguageX = tester.getTopLeft(languageIndicator).dx;
    await tester.pumpAndSettle();
    final endLanguageX = tester.getTopLeft(languageIndicator).dx;

    expect(midLanguageX, greaterThan(startLanguageX));
    expect(midLanguageX, lessThan(endLanguageX));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a club admin now gets the club frame, not this one', (
    tester,
  ) async {
    // `settings` `350:6` replaced the legacy club screen. This file owns the
    // *student* frame, so all it pins is that the two no longer collide:
    // `club_settings_design_test.dart` covers the club screen itself.
    final club = Club(
      id: 'settings-design-club-record',
      name: 'Design Club',
      description: 'A club for the settings fixture.',
      adminUserIds: const ['settings-design-club'],
    );
    clubs
      ..clear()
      ..add(club);
    addTearDown(clubs.clear);
    authService.setClubAdmin(
      AppAdmin(
        id: 'settings-design-club',
        name: 'Design Club',
        email: 'design.club@ku.edu.tr',
        password: '22222222',
      ),
    );

    await pumpSettings(tester);

    expect(find.byKey(const ValueKey('club-settings-header')), findsOneWidget);
    // The student frame's own chrome is not drawn for a club.
    expect(find.byType(SettingsHeaderBar), findsNothing);
    expect(find.byType(SettingsRowCard), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the ClubUp moderator still gets the pre-redesign screen', (
    tester,
  ) async {
    // `_managedClub` is null for the platform admin, so neither redesigned
    // settings screen applies and the legacy one is still the fallback.
    clubs.clear();
    authService.setClubAdmin(
      AppAdmin(
        id: 'admin1',
        name: 'ClubUp',
        email: 'clubup@ku.edu.tr',
        password: '22222222',
      ),
    );

    await pumpSettings(tester);

    expect(find.byKey(const ValueKey('club-settings-header')), findsNothing);
    expect(find.byType(SettingsHeaderBar), findsNothing);
    expect(find.byType(SettingsRowCard), findsNothing);
    expect(find.text('Light Mode'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
