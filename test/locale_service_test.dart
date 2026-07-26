import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:flutter_application_1/services/locale_service.dart';

void main() {
  test(
    'selected language and user choice persist across app launches',
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
      await firstLaunch.markLanguageChosen('student-1', 'tr');

      expect(firstLaunch.languageCode, 'tr');
      expect(firstLaunch.hasChosenLanguage('student-1'), isTrue);

      await Hive.close();
      Hive.init(tempDir.path);

      final nextLaunch = LocaleService();
      await nextLaunch.initialize();

      expect(nextLaunch.languageCode, 'tr');
      expect(nextLaunch.hasChosenLanguage('student-1'), isTrue);
    },
  );
}
