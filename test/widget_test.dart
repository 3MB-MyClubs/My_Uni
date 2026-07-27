import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/terms_acceptance_screen.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/onboarding_intro_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'fresh install is not gated by the full-screen terms screen',
    (WidgetTester tester) async {
      // A brand-new device has never reached an authenticated state, so the
      // full-screen gate must yield to the first-run experience — new users
      // accept the Terms via the checkbox on the sign-up flow's last step.
      SharedPreferences.setMockInitialValues({});
      await onboardingIntroService.initialize();
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      expect(find.text('COMMUNITY SAFETY TERMS'), findsNothing);
      expect(find.text('Agree and continue'), findsNothing);
    },
  );

  testWidgets(
    'returning user with unaccepted terms still sees the re-accept gate',
    (WidgetTester tester) async {
      // A device that has completed onboarding (i.e. reached an authenticated
      // state before) is a returning user; when the Terms version is bumped,
      // the full-screen gate must re-appear and block until accepted.
      SharedPreferences.setMockInitialValues({
        'has_completed_onboarding_intro': true,
      });
      await onboardingIntroService.initialize();
      await tester.pumpWidget(const MyApp());
      await tester.pump();

      expect(find.text('COMMUNITY SAFETY TERMS'), findsOneWidget);
      expect(find.text('Agree and continue'), findsOneWidget);
      expect(find.text('Log in'), findsNothing);
    },
  );

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
