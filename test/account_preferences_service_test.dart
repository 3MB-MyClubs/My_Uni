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

    expect(firstDevice.hasLanguagePreference, isFalse);
    expect(firstDevice.hasThemePreference, isFalse);

    await firstDevice.saveLanguage('en');
    await firstDevice.saveTheme(true);

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
}
