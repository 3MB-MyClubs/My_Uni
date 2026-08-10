import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/services/account_preferences_service.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

void main() {
  test('loads saved account choices on another service instance', () async {
    const userId = '82d32a55-f211-47aa-89e6-3649eced7691';
    final rows = <String, Map<String, dynamic>>{};

    Future<void> write(String id, Map<String, dynamic> values) async {
      rows[id] = {...?rows[id], ...values};
    }

    final firstDevice = AccountPreferencesService(
      userIdProvider: () => userId,
      rowLoader: (id) async => rows[id],
      rowWriter: write,
    );
    await firstDevice.loadForCurrentUser();

    expect(firstDevice.status, AccountPreferencesStatus.loaded);
    expect(
      firstDevice.nextRequiredPreference,
      AccountPreferencePrompt.language,
    );
    expect(firstDevice.hasLanguagePreference, isFalse);
    expect(firstDevice.hasThemePreference, isFalse);

    await firstDevice.saveLanguage('en');
    expect(firstDevice.nextRequiredPreference, AccountPreferencePrompt.theme);
    await firstDevice.saveTheme(true);
    expect(firstDevice.nextRequiredPreference, AccountPreferencePrompt.none);

    final secondDevice = AccountPreferencesService(
      userIdProvider: () => userId,
      rowLoader: (id) async => rows[id],
      rowWriter: write,
    );
    final loaded = await secondDevice.loadForCurrentUser();

    expect(loaded.languageCode, 'en');
    expect(loaded.isDark, isTrue);
    expect(secondDevice.hasLanguagePreference, isTrue);
    expect(secondDevice.hasThemePreference, isTrue);
  });

  test('keeps missing and invalid values unset', () async {
    final service = AccountPreferencesService(
      userIdProvider: () => 'user-id',
      rowLoader: (_) async => {'language_code': 'de', 'theme_mode': 'system'},
      rowWriter: (_, _) async {},
    );

    final loaded = await service.loadForCurrentUser();

    expect(loaded.languageCode, isNull);
    expect(loaded.isDark, isNull);
    expect(service.hasLanguagePreference, isFalse);
    expect(service.hasThemePreference, isFalse);
  });

  test('a failed fetch never looks like missing first-time choices', () async {
    final service = AccountPreferencesService(
      userIdProvider: () => 'student-auth-id',
      rowLoader: (_) async => throw Exception('temporary network failure'),
      rowWriter: (_, _) async {},
    );

    await expectLater(service.loadForCurrentUser(), throwsException);

    expect(service.status, AccountPreferencesStatus.error);
    expect(service.isLoadedForCurrentUser, isFalse);
    expect(service.needsLanguagePreference, isFalse);
    expect(service.needsThemePreference, isFalse);
    expect(service.nextRequiredPreference, AccountPreferencePrompt.none);
  });

  test('prompts only for the missing preference', () async {
    final languageMissing = AccountPreferencesService(
      userIdProvider: () => 'student-auth-id',
      rowLoader: (_) async => {'language_code': null, 'theme_mode': 'dark'},
      rowWriter: (_, _) async {},
    );
    final themeMissing = AccountPreferencesService(
      userIdProvider: () => 'club-auth-id',
      rowLoader: (_) async => {'language_code': 'tr', 'theme_mode': null},
      rowWriter: (_, _) async {},
    );

    await languageMissing.loadForCurrentUser();
    await themeMissing.loadForCurrentUser();

    expect(
      languageMissing.nextRequiredPreference,
      AccountPreferencePrompt.language,
    );
    expect(themeMissing.nextRequiredPreference, AccountPreferencePrompt.theme);
  });

  test('a late response cannot replace the newly switched account', () async {
    var currentId = 'student-auth-id';
    final studentResponse = Completer<Map<String, dynamic>?>();
    final service = AccountPreferencesService(
      userIdProvider: () => currentId,
      rowLoader: (id) {
        if (id == 'student-auth-id') return studentResponse.future;
        return Future.value({'language_code': 'tr', 'theme_mode': 'light'});
      },
      rowWriter: (_, _) async {},
    );

    final oldLoad = service.loadForCurrentUser();
    currentId = 'club-auth-id';
    await service.loadForCurrentUser();
    studentResponse.complete({'language_code': 'en', 'theme_mode': 'dark'});
    await oldLoad;

    expect(service.preferences.languageCode, 'tr');
    expect(service.preferences.isDark, isFalse);
    expect(service.status, AccountPreferencesStatus.loaded);
    expect(service.nextRequiredPreference, AccountPreferencePrompt.none);
  });

  test(
    'student and club first login, relogin, and Settings changes stay isolated',
    () async {
      const studentId = 'student-auth-id';
      const clubId = 'club-auth-id';
      var currentId = studentId;
      final rows = <String, Map<String, dynamic>>{};

      Future<void> write(String id, Map<String, dynamic> values) async {
        rows[id] = {...?rows[id], ...values};
      }

      AccountPreferencesService device() => AccountPreferencesService(
        userIdProvider: () => currentId,
        rowLoader: (id) async => rows[id],
        rowWriter: write,
      );

      final firstDevice = device();
      await firstDevice.loadForCurrentUser();
      expect(
        firstDevice.nextRequiredPreference,
        AccountPreferencePrompt.language,
      );
      await firstDevice.saveLanguage('en');
      await firstDevice.saveTheme(true);

      currentId = clubId;
      final clubSession = device();
      await clubSession.loadForCurrentUser();
      expect(
        clubSession.nextRequiredPreference,
        AccountPreferencePrompt.language,
      );
      await clubSession.saveLanguage('tr');
      await clubSession.saveTheme(false);

      currentId = studentId;
      final studentRelogin = device();
      var loaded = await studentRelogin.loadForCurrentUser();
      expect(loaded.languageCode, 'en');
      expect(loaded.isDark, isTrue);
      expect(
        studentRelogin.nextRequiredPreference,
        AccountPreferencePrompt.none,
      );

      await studentRelogin.saveLanguage('tr');
      await studentRelogin.saveTheme(false);

      currentId = clubId;
      final clubRelogin = device();
      loaded = await clubRelogin.loadForCurrentUser();
      expect(loaded.languageCode, 'tr');
      expect(loaded.isDark, isFalse);

      currentId = studentId;
      final studentAfterSettingsChange = device();
      loaded = await studentAfterSettingsChange.loadForCurrentUser();
      expect(loaded.languageCode, 'tr');
      expect(loaded.isDark, isFalse);
    },
  );

  test(
    'does not persist signed-out device changes as account choices',
    () async {
      var writes = 0;
      final service = AccountPreferencesService(
        userIdProvider: () => null,
        rowLoader: (_) async => null,
        rowWriter: (_, _) async => writes++,
      );

      await service.saveLanguage('tr');
      await service.saveTheme(false);

      expect(writes, 0);
      expect(service.hasLanguagePreference, isFalse);
      expect(service.hasThemePreference, isFalse);
    },
  );

  test('choice and Settings services write account values', () async {
    final savedLanguages = <String>[];
    final savedThemes = <bool>[];
    final locale = LocaleService(
      accountSaver: (code) async => savedLanguages.add(code),
    );
    final theme = ThemeService(
      accountSaver: (isDark) async => savedThemes.add(isDark),
    );

    await locale.markLanguageChosen('app-user', 'en');
    await theme.markThemeChosen('app-user', true);
    await locale.setLanguage('tr');
    await theme.setDark(false);

    expect(savedLanguages, ['en', 'tr']);
    expect(savedThemes, [true, false]);
    expect(locale.hasChosenLanguage('app-user'), isTrue);
    expect(theme.hasChosenTheme('app-user'), isTrue);
  });

  test('applying loaded account values does not write them back', () async {
    var writes = 0;
    final locale = LocaleService(accountSaver: (_) async => writes++);
    final theme = ThemeService(accountSaver: (_) async => writes++);

    await locale.applyAccountLanguage('app-user', 'en');
    await theme.applyAccountTheme('app-user', true);

    expect(writes, 0);
    expect(locale.languageCode, 'en');
    expect(theme.isDark, isTrue);
  });

  test('local fallback values are cached per authenticated account', () async {
    var accountId = 'student-auth-id';
    final locale = LocaleService(
      accountIdProvider: () => accountId,
      accountSaver: (_) async {},
    );
    final theme = ThemeService(
      accountIdProvider: () => accountId,
      accountSaver: (_) async {},
    );

    await locale.setLanguage('en');
    await theme.setDark(true);

    accountId = 'club-auth-id';
    await locale.setLanguage('tr');
    await theme.setDark(false);

    expect(locale.cachedLanguageFor('student-auth-id'), 'en');
    expect(theme.cachedThemeFor('student-auth-id'), isTrue);
    expect(locale.cachedLanguageFor('club-auth-id'), 'tr');
    expect(theme.cachedThemeFor('club-auth-id'), isFalse);
  });

  test(
    'Settings keeps the immediate cached value but reports save failures',
    () async {
      final locale = LocaleService(
        accountIdProvider: () => 'student-auth-id',
        accountSaver: (_) async => throw Exception('offline'),
      );
      final theme = ThemeService(
        accountIdProvider: () => 'student-auth-id',
        accountSaver: (_) async => throw Exception('offline'),
      );

      await expectLater(
        locale.setLanguage('en', rethrowAccountSaveFailure: true),
        throwsException,
      );
      await expectLater(
        theme.setDark(true, rethrowAccountSaveFailure: true),
        throwsException,
      );

      expect(locale.languageCode, 'en');
      expect(locale.cachedLanguageFor('student-auth-id'), 'en');
      expect(theme.isDark, isTrue);
      expect(theme.cachedThemeFor('student-auth-id'), isTrue);
    },
  );
}
