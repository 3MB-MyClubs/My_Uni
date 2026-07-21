import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/terms_acceptance_screen.dart';
import 'package:flutter_application_1/services/locale_service.dart';

void main() {
  testWidgets('app opens on the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Brand header + the design's login affordances are the root UI.
    expect(find.text('Koç University'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('login screen "Sign up" hands off to the sign-up flow', (
    WidgetTester tester,
  ) async {
    var signUpTapped = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(
          onLogin: () {},
          onSignUp: () => signUpTapped = true,
          onAdminLogin: () {},
        ),
      ),
    );
    await tester.pump();

    final cta = find.text('Sign up');
    await tester.ensureVisible(cta);
    await tester.pump();
    await tester.tap(cta);
    await tester.pump();

    expect(signUpTapped, isTrue);
  });

  testWidgets('community safety agreement can switch to Turkish', (
    WidgetTester tester,
  ) async {
    await localeService.setLanguage('en');
    await tester.pumpWidget(
      ListenableBuilder(
        listenable: localeService,
        builder: (context, _) => MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale(localeService.languageCode),
          home: TermsAcceptanceScreen(onAccepted: () async {}),
        ),
      ),
    );

    await tester.tap(find.text('TR'));
    await tester.pumpAndSettle();

    expect(find.text('TOPLULUK GÜVENLİĞİ KOŞULLARI'), findsOneWidget);
    expect(find.text('Kabul et ve devam et'), findsOneWidget);
    await localeService.setLanguage('en');
  });
}
