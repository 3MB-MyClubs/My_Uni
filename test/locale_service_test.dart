import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_application_1/services/locale_service.dart';

void main() {
  test(
    'defaults to Turkish and preserves explicit choices across launches',
    () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'locale_service_test_',
      );
      Hive.init(tempDir.path);
      addTearDown(() async {
        await Hive.close();
        if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
      });

      final firstLaunch = LocaleService();
      await firstLaunch.initialize();

      expect(firstLaunch.languageCode, LocaleService.defaultLanguageCode);

      // The first-run, login, and sign-up language controls all use
      // setLanguage, so this exercises the real explicit-choice path.
      await firstLaunch.setLanguage('en');

      expect(firstLaunch.languageCode, 'en');

      await Hive.close();
      Hive.init(tempDir.path);

      final nextLaunch = LocaleService();
      await nextLaunch.initialize();

      expect(nextLaunch.languageCode, 'en');

      // Settings uses setLanguage, so changing it there must replace the
      // persisted choice for every later launch.
      await nextLaunch.setLanguage('tr');

      await Hive.close();
      Hive.init(tempDir.path);

      final afterSettingsChange = LocaleService();
      await afterSettingsChange.initialize();

      expect(afterSettingsChange.languageCode, 'tr');
    },
  );
}
