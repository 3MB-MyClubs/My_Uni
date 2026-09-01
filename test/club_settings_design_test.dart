import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/blocked_accounts_screen.dart';
import 'package:flutter_application_1/screens/club_edit_category_screen.dart';
import 'package:flutter_application_1/screens/club_edit_description_screen.dart';
import 'package:flutter_application_1/screens/settings_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/moderation_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/club_profile_design.dart';
import 'package:flutter_application_1/widgets/club_settings_design.dart';
import 'package:flutter_application_1/widgets/settings_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The club settings sub-flow — Figma `350:6` / `350:184` and everything it
/// opens: `edit-category` `367:61`, `edit-description` `367:157`,
/// `settings-language` `417:208`, `blocked-students` / `blocked-clubs`
/// `414:8` / `414:103`.
///
/// The settings list and the two editors sample to the CLUB PROFILE ramp;
/// the blocked list samples to the settings ramp, which is why it keeps
/// [SettingsColors] — the student's Privacy row opens the same screen.
void main() {
  late Directory tempDir;
  const clubId = 'club-settings-club';
  const adminId = 'club-settings-admin';
  const studentId = 'club-settings-student';

  const categoryOptions = <String>[
    'Academic',
    'Arts',
    'Music',
    'Sports',
    'Wellness',
  ];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_settings_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  late Club club;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await themeService.setDark(false);
    await localeService.setLanguage('en');
    await authService.logout();

    club = Club(
      id: clubId,
      name: 'Rooftop Collective',
      shortName: 'RC',
      description: 'Deep grooves and sunset sessions on the terrace.',
      categoryName: 'Arts, Music',
      adminUserIds: const [adminId],
      boardMemberIds: ['bm-1', 'bm-2'],
    );
    // `setClubAdmin` leaves a club behind whose id is the *admin* id, and
    // `managedClubForAdmin` matches on `club.id == adminId` first. Leaving it
    // in place makes a later test resolve the wrong club, so the list is
    // cleared rather than filtered.
    clubs
      ..clear()
      ..add(club);
  });

  tearDown(() async {
    clubs.clear();
    users.removeWhere((item) => item.id == studentId);
    moderationService.clearActiveUser();
    await authService.logout();
    await themeService.setDark(false);
  });

  void signInStudent() {
    users
      ..removeWhere((item) => item.id == studentId)
      ..add(
        User(
          id: studentId,
          name: 'Alice Yıldız',
          email: 'alice.settings@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    authService.login('alice.settings@ku.edu.tr', '111111');
  }

  void signInClubAdmin() {
    authService.setClubAdmin(
      AppAdmin(
        id: adminId,
        name: 'Rooftop Collective',
        email: 'rooftop.collective@ku.edu.tr',
        password: '22222222',
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester,
    Widget home, {
    double height = 2000,
    double width = 393,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    // `pumpWidget` reuses the element tree when the shape matches, so a route
    // or a focus left by the previous test survives into this one. Tearing the
    // tree down first makes each pump a clean app.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> pumpSettings(WidgetTester tester, {double height = 2000}) =>
      pump(tester, SettingsScreen(onLogout: () {}), height: height);

  // ── settings list ──────────────────────────────────────────────────────────

  testWidgets('the club sees the frame: identity card and six sections', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpSettings(tester);

    expect(find.byKey(const ValueKey('club-settings-header')), findsOneWidget);
    expect(find.byType(ClubSettingsIdentityCard), findsOneWidget);
    expect(find.text('Rooftop Collective'), findsWidgets);

    // Club profile fields are editable only from the club settings card.
    for (final key in const [
      ValueKey('club-settings-name'),
      ValueKey('club-settings-initials'),
      ValueKey('club-settings-category'),
      ValueKey('club-settings-description'),
    ]) {
      expect(find.byKey(key), findsOneWidget);
    }

    // `section-label` on each of the frame's six groups.
    expect(
      find.text(S.clubSettingsProfileSection.toUpperCase()),
      findsOneWidget,
    );
    expect(
      find.text(S.clubSettingsManagementSection.toUpperCase()),
      findsOneWidget,
    );
    expect(find.text(S.settingsPreferences.toUpperCase()), findsOneWidget);
    expect(find.text(S.settingsSupport.toUpperCase()), findsOneWidget);
    expect(find.text(S.clubSettingsLegalSection.toUpperCase()), findsOneWidget);
    expect(find.text(S.settingsDangerZone.toUpperCase()), findsOneWidget);

    // Rows are grouped into one card per section, not one card per row.
    expect(find.byType(ClubSettingsGroupCard), findsNWidgets(5));

    // `management-group` 350:67 — the board row carries the live count.
    expect(find.byKey(const ValueKey('club-settings-board')), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.byKey(const ValueKey('club-settings-blocked')), findsOneWidget);

    expect(find.byKey(const ValueKey('club-settings-logout')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-settings-delete')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a student keeps the student settings screen', (tester) async {
    // `users` is empty at rest in this repo, so the fixture is seeded here
    // rather than fished out of mock_data.
    signInStudent();
    await pumpSettings(tester);

    expect(find.byKey(const ValueKey('club-settings-header')), findsNothing);
    expect(find.byType(ClubSettingsIdentityCard), findsNothing);
    expect(find.byKey(const ValueKey('club-settings-initials')), findsNothing);
    // The student frame's chrome, unchanged.
    expect(find.byType(SettingsHeaderBar), findsOneWidget);
    expect(find.byType(SettingsRowCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the club Preferences row uses the student segmented toggle', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpSettings(tester);

    // Chosen over the frame's switch so both settings screens behave alike.
    expect(
      find.byKey(const ValueKey('club-settings-appearance')),
      findsOneWidget,
    );
    expect(find.byType(SettingsSegmentedToggle), findsOneWidget);
    expect(find.text(S.settingsLightOption), findsOneWidget);
    expect(find.text(S.settingsDarkOption), findsOneWidget);

    // The language row keeps the frame's value-plus-sheet shape.
    expect(
      find.byKey(const ValueKey('club-settings-language')),
      findsOneWidget,
    );
    expect(find.text('English'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Language row opens the Choose Language sheet', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('club-settings-language')));
    await tester.pumpAndSettle();

    expect(find.text(S.clubSettingsChooseLanguage), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-settings-language-en')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-settings-language-tr')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('club-settings-language-tr')));
    await tester.pumpAndSettle();
    expect(localeService.languageCode, 'tr');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the name sheet saves through the row on the identity card', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('club-settings-name')));
    await tester.pumpAndSettle();

    expect(find.text(S.clubEditNameTitle), findsOneWidget);
    expect(find.text(S.clubEditNameSave), findsOneWidget);
    // Nothing typed yet, so the pill is inert.
    await tester.tap(find.byKey(const ValueKey('club-settings-name-save')));
    await tester.pumpAndSettle();
    expect(club.name, 'Rooftop Collective');

    await tester.enterText(
      find.byKey(const ValueKey('club-settings-name-field')),
      'Terrace Society',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('club-settings-name-save')));
    await tester.pumpAndSettle();

    expect(club.name, 'Terrace Society');
    // The sheet closes itself on a successful save.
    expect(find.text(S.clubEditNameTitle), findsNothing);
    // The sheet closes itself on a successful save.
    expect(find.text(S.clubEditNameTitle), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the initials sheet validates and saves the public @name', (
    tester,
  ) async {
    signInClubAdmin();
    await pumpSettings(tester);

    // The short name stays private to the editor instead of being repeated on
    // the settings card.
    expect(find.text('@RC'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('club-settings-initials')));
    await tester.pumpAndSettle();

    expect(find.text(S.clubEditInitialsTitle), findsOneWidget);
    final initialsField = tester.widget<TextField>(
      find.byKey(const ValueKey('club-settings-initials-field')),
    );
    expect(initialsField.controller?.text, 'RC');
    await tester.enterText(
      find.byKey(const ValueKey('club-settings-initials-field')),
      'not valid',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('club-settings-initials-error')),
      findsOneWidget,
    );
    final decoratedField = tester.widget<TextField>(
      find.byKey(const ValueKey('club-settings-initials-field')),
    );
    expect(decoratedField.decoration?.border, InputBorder.none);
    expect(decoratedField.decoration?.enabledBorder, InputBorder.none);
    expect(decoratedField.decoration?.focusedBorder, InputBorder.none);
    expect(decoratedField.decoration?.errorBorder, InputBorder.none);
    expect(decoratedField.decoration?.focusedErrorBorder, InputBorder.none);
    expect(club.shortName, 'RC');

    await tester.enterText(
      find.byKey(const ValueKey('club-settings-initials-field')),
      '@IES',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('club-settings-initials-save')));
    await tester.pumpAndSettle();

    expect(club.shortName, 'IES');
    expect(find.text(S.clubEditInitialsTitle), findsNothing);
    expect(find.text('@IES'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  // ── category editor ────────────────────────────────────────────────────────

  testWidgets('the initials sheet has no suggested value or placeholder', (
    tester,
  ) async {
    club.shortName = null;
    signInClubAdmin();
    await pumpSettings(tester);

    await tester.tap(find.byKey(const ValueKey('club-settings-initials')));
    await tester.pumpAndSettle();

    final initialsField = tester.widget<TextField>(
      find.byKey(const ValueKey('club-settings-initials-field')),
    );
    expect(initialsField.controller?.text, isEmpty);
    expect(initialsField.decoration?.hintText, isNull);
    expect(find.text('kbr or IES'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  Widget categoryScreen() => ClubEditCategoryScreen(
    club: club,
    categoryOptions: categoryOptions,
    localizeCategory: (context, category) => category,
  );

  testWidgets('the category editor draws suggested and added chips', (
    tester,
  ) async {
    await pump(tester, categoryScreen(), height: 900);

    expect(find.text(S.clubCategorySuggested.toUpperCase()), findsOneWidget);
    expect(find.text(S.clubCategoryAdded.toUpperCase()), findsOneWidget);
    // Arts and Music are on the club, so they appear twice — suggested
    // (selected) and added.
    expect(find.text('Arts'), findsNWidgets(2));
    expect(find.text('Sports'), findsOneWidget);

    // Save is inert until something changes.
    await tester.tap(find.byKey(const ValueKey('club-settings-save')));
    await tester.pumpAndSettle();
    expect(club.categoryName, 'Arts, Music');
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking a chip and saving rewrites categoryName', (
    tester,
  ) async {
    await pump(tester, categoryScreen(), height: 900);

    await tester.tap(
      find.byKey(const ValueKey('club-edit-category-chip-Sports')),
    );
    await tester.pump();
    // Tapping an added chip takes it back off.
    await tester.tap(
      find.byKey(const ValueKey('club-edit-category-added-Arts')),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('club-settings-save')));
    await tester.pumpAndSettle();

    expect(club.categoryName, 'Music, Sports');
    expect(tester.takeException(), isNull);
  });

  testWidgets('typing an unknown tag offers to create it', (tester) async {
    await pump(tester, categoryScreen(), height: 900);

    await tester.enterText(
      find.byKey(const ValueKey('club-edit-category-search')),
      'Rooftop Sessions',
    );
    await tester.pump();
    expect(
      find.byKey(const ValueKey('club-edit-category-create')),
      findsOneWidget,
    );
    expect(find.text(S.clubCategoryAdd), findsOneWidget);
    final addCategory = find.byKey(const ValueKey('club-edit-category-create'));
    final inputCard = find.byKey(
      const ValueKey('club-edit-category-input-card'),
    );
    expect(tester.getSize(addCategory).height, 32);
    expect(
      tester.getSize(addCategory).width,
      lessThan(tester.getSize(inputCard).width - 80),
    );
    expect(tester.widget<ClubSettingsChip>(addCategory).selected, isTrue);

    await tester.tap(addCategory);
    await tester.pump();
    expect(
      find.byKey(const ValueKey('club-edit-category-added-Rooftop Sessions')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('club-settings-save')));
    await tester.pumpAndSettle();
    expect(club.categoryName, 'Arts, Music, Rooftop Sessions');
    expect(tester.takeException(), isNull);
  });

  // ── description editor ─────────────────────────────────────────────────────

  testWidgets('category and description inputs have no fill or focus frame', (
    tester,
  ) async {
    void expectCleanDecoration(TextField field) {
      final decoration = field.decoration!;
      expect(decoration.filled, isFalse);
      expect(decoration.border, InputBorder.none);
      expect(decoration.enabledBorder, InputBorder.none);
      expect(decoration.disabledBorder, InputBorder.none);
      expect(decoration.focusedBorder, InputBorder.none);
      expect(decoration.errorBorder, InputBorder.none);
      expect(decoration.focusedErrorBorder, InputBorder.none);
    }

    await pump(tester, categoryScreen(), height: 900);
    final categoryCard = tester.widget<ClubProfileCard>(
      find.byKey(const ValueKey('club-edit-category-input-card')),
    );
    expect(categoryCard.padding, const EdgeInsets.all(16));
    expectCleanDecoration(
      tester.widget<TextField>(
        find.descendant(
          of: find.byKey(const ValueKey('club-edit-category-search')),
          matching: find.byType(TextField),
        ),
      ),
    );

    await pump(tester, ClubEditDescriptionScreen(club: club), height: 900);
    expectCleanDecoration(
      tester.widget<TextField>(
        find.byKey(const ValueKey('club-edit-description-field')),
      ),
    );
    final descriptionSurface = tester.widget<Container>(
      find.byKey(const ValueKey('club-edit-description-input')),
    );
    expect(descriptionSurface.decoration, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the description editor prints the app\'s real character cap', (
    tester,
  ) async {
    await pump(tester, ClubEditDescriptionScreen(club: club), height: 900);

    // The frame prints 300; the field has always capped at 240 and raising a
    // stored limit is a backend question, so the app's number is shown.
    expect(
      find.text(S.clubDescriptionMax(kClubDescriptionMaxLength)),
      findsOneWidget,
    );
    expect(
      find.text(
        S.clubDescriptionCounter(
          club.description.length,
          kClubDescriptionMaxLength,
        ),
      ),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('club-edit-description-field')),
      'Six words is all it takes.',
    );
    await tester.pump();
    expect(
      find.text(S.clubDescriptionCounter(26, kClubDescriptionMaxLength)),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // ── blocked people & clubs ─────────────────────────────────────────────────

  testWidgets('the blocked list tabs, searches and unbans', (tester) async {
    signInStudent();
    await moderationService.activateForUser(authService.currentUser!.id);
    const blockedId = 'club-settings-blocked';
    users
      ..removeWhere((item) => item.id == blockedId)
      ..add(
        User(
          id: blockedId,
          name: 'Sarah Mitchell',
          email: 'sarah@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    addTearDown(() => users.removeWhere((item) => item.id == blockedId));
    await moderationService.blockUser(blockedId, reason: 'test');

    await pump(tester, const BlockedAccountsScreen(), height: 900);

    expect(find.byKey(const ValueKey('blocked-header')), findsOneWidget);
    expect(find.text(S.clubSettingsBlockedRow), findsOneWidget);
    expect(find.text(S.bannedStudentsLabel.toUpperCase()), findsOneWidget);
    expect(
      find.byKey(const ValueKey('blocked-user-$blockedId')),
      findsOneWidget,
    );

    final searchCard = tester.widget<Container>(
      find.byKey(const ValueKey('blocked-search-card')),
    );
    expect(searchCard.padding, const EdgeInsets.all(16));
    final searchCardDecoration = searchCard.decoration! as BoxDecoration;
    expect(searchCardDecoration.color, SettingsColors.card);
    expect(searchCardDecoration.border, isNotNull);
    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey('blocked-search')),
    );
    expect(searchField.decoration?.filled, isFalse);
    expect(searchField.decoration?.enabledBorder, InputBorder.none);
    expect(searchField.decoration?.focusedBorder, InputBorder.none);

    // `filter-tabs` 414:28 — exactly two equal tabs fill the horizontal bar.
    expect(find.byType(TabBar), findsNothing);
    final tabs = find.byKey(const ValueKey('blocked-tabs'));
    final tabTargets = find.descendant(
      of: tabs,
      matching: find.byType(GestureDetector),
    );
    expect(tabTargets, findsNWidgets(2));
    final tabsWidth = tester.getSize(tabs).width;
    expect(
      tester.getSize(tabTargets.at(0)).width,
      closeTo((tabsWidth - 4) / 2, 0.01),
    );
    expect(
      tester.getSize(tabTargets.at(1)).width,
      closeTo((tabsWidth - 4) / 2, 0.01),
    );
    await tester.tap(find.text(S.blockedClubsTab));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('blocked-user-$blockedId')), findsNothing);
    expect(find.text(S.noBlockedClubs), findsOneWidget);

    await tester.tap(find.text(S.blockedStudentsTab));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('blocked-search')),
      'nobody-by-this-name',
    );
    await tester.pump();
    expect(find.text(S.blockedNoMatch), findsOneWidget);

    await tester.enterText(find.byKey(const ValueKey('blocked-search')), '');
    await tester.pump();
    await tester.tap(find.text(S.unblock).first);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('blocked-unblock-confirm')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('blocked-unblock-confirm-yes')));
    await tester.pumpAndSettle();

    expect(moderationService.blockedUserIds, isNot(contains(blockedId)));
    expect(tester.takeException(), isNull);
  });

  // ── palette ────────────────────────────────────────────────────────────────

  testWidgets(
    'dark: the list is on the club ramp, blocked on the settings one',
    (tester) async {
      await themeService.setDark(true);
      signInClubAdmin();
      await pumpSettings(tester);

      final settings = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(settings.backgroundColor, const Color(0xFF0A0A0A));
      expect(ClubProfileColors.card, const Color(0xFF121212));
      expect(ClubProfileColors.field, const Color(0xFF1E1E1E));

      // Burgundy everywhere the frame draws #1DA1F2.
      expect(ClubProfileColors.accent, const Color(0xFF800020));
      expect(SettingsColors.accent, const Color(0xFF800020));

      await pump(tester, const BlockedAccountsScreen(), height: 900);
      final blocked = tester.widget<Scaffold>(find.byType(Scaffold).first);
      expect(blocked.backgroundColor, SettingsColors.background);
      expect(SettingsColors.background, const Color(0xFF09090B));
      expect(SettingsColors.card, const Color(0xFF18181B));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('every screen fits a real 393x852 frame in Turkish', (
    tester,
  ) async {
    await localeService.setLanguage('tr');
    signInClubAdmin();

    await pumpSettings(tester, height: 852);
    expect(find.byKey(const ValueKey('club-settings-scroll')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await pump(tester, categoryScreen(), height: 852);
    expect(tester.takeException(), isNull);

    await pump(tester, ClubEditDescriptionScreen(club: club), height: 852);
    expect(tester.takeException(), isNull);

    await pump(tester, const BlockedAccountsScreen(), height: 852);
    expect(tester.takeException(), isNull);
  });
}
