import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/language_choice_screen.dart';
import 'package:flutter_application_1/screens/theme_choice_screen.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';

Widget _app(Widget home) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('theme picker saves only when Continue is pressed', (
    tester,
  ) async {
    await themeService.setDark(false, persistToAccount: false);
    bool? saved;
    await tester.pumpWidget(
      _app(ThemeChoiceScreen(onChoose: (isDark) async => saved = isDark)),
    );

    await tester.tap(find.text('Dark').first);
    await tester.pump();
    expect(saved, isNull);

    await tester.tap(find.textContaining('Continue').first);
    await tester.pump();
    expect(saved, isTrue);
  });

  testWidgets('language picker saves the selected language on Continue', (
    tester,
  ) async {
    await localeService.setLanguage('en', persistToAccount: false);
    String? saved;
    await tester.pumpWidget(
      _app(LanguageChoiceScreen(onChoose: (code) async => saved = code)),
    );

    await tester.tap(find.text('Türkçe').first);
    await tester.pump();
    expect(saved, isNull);

    await tester.tap(find.text('Continue'));
    await tester.pump();
    expect(saved, 'tr');
  });
}
