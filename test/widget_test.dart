import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/onboarding_carousel_screen.dart';
import 'package:flutter_application_1/screens/terms_acceptance_screen.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/onboarding_intro_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('fresh install is not gated by the full-screen terms screen', (
    WidgetTester tester,
  ) async {
    // A brand-new device has never reached an authenticated state, so the
    // full-screen gate must yield to the first-run experience — new users
    // accept the Terms via the checkbox on the sign-up flow's last step.
    SharedPreferences.setMockInitialValues({});
    await onboardingIntroService.initialize();
    await tester.pumpWidget(const MyApp(minimumLaunchDuration: Duration.zero));
    await tester.pump();

    expect(find.text('COMMUNITY SAFETY TERMS'), findsNothing);
    expect(find.text('Agree and continue'), findsNothing);
  });

  testWidgets('returning user never sees the first-run intro again', (
    WidgetTester tester,
  ) async {
    // The legacy authenticated flag migrates to the new intro-seen flag.
    SharedPreferences.setMockInitialValues({
      'has_completed_onboarding_intro_v2': true,
    });
    await onboardingIntroService.initialize();
    await tester.pumpWidget(const MyApp(minimumLaunchDuration: Duration.zero));
    await tester.pump();

    expect(find.byType(OnboardingCarouselScreen), findsNothing);
    expect(find.text('COMMUNITY SAFETY TERMS'), findsOneWidget);
    expect(find.text('Agree and continue'), findsOneWidget);
    expect(find.text('Log in'), findsNothing);
  });

  testWidgets('showing intro once persists across a second app launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await onboardingIntroService.initialize();
    await tester.pumpWidget(const MyApp(minimumLaunchDuration: Duration.zero));
    await tester.pump();

    expect(find.byType(OnboardingCarouselScreen), findsOneWidget);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final preferences = await SharedPreferences.getInstance();
    expect(preferences.getBool('has_seen_onboarding_intro_v1'), isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await onboardingIntroService.initialize();
    await tester.pumpWidget(const MyApp(minimumLaunchDuration: Duration.zero));
    await tester.pump();

    expect(find.byType(OnboardingCarouselScreen), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('app shows branded launch UI before its first destination', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await onboardingIntroService.initialize();
    await tester.pumpWidget(
      const MyApp(minimumLaunchDuration: Duration(milliseconds: 2000)),
    );

    expect(find.byKey(const Key('app_launch_logo')), findsOneWidget);
    expect(find.byKey(const Key('app_launch_progress')), findsOneWidget);
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor,
      const Color(0xFF4A0F24),
    );
    expect(find.text('COMMUNITY SAFETY TERMS'), findsNothing);

    await tester.pump(const Duration(milliseconds: 2000));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 325));

    // The outgoing launch screen and incoming destination overlap mid-flight.
    expect(find.byKey(const Key('app_launch_logo')), findsOneWidget);
    expect(find.byType(OnboardingCarouselScreen), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 326));
    await tester.pump();

    expect(find.byKey(const Key('app_launch_logo')), findsNothing);
    expect(find.byType(OnboardingCarouselScreen), findsOneWidget);
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
