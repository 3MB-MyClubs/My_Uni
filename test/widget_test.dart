import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';
import 'package:flutter_application_1/screens/terms_acceptance_screen.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app requires terms before opening the login screen', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('COMMUNITY SAFETY TERMS'), findsOneWidget);
    expect(find.text('Agree and continue'), findsOneWidget);
    expect(find.text('Log in'), findsNothing);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.text('Agree and continue'));
    await tester.pumpAndSettle();

    // Authentication is inaccessible until the agreement is accepted.
    expect(find.text('KOÇ UNIVERSITY'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('login screen "Sign up" hands off to the sign-up flow', (
    WidgetTester tester,
  ) async {
    var signUpTapped = false;
    await tester.pumpWidget(
      MaterialApp(
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
      MaterialApp(home: TermsAcceptanceScreen(onAccepted: () async {})),
    );

    await tester.tap(find.text('TR'));
    await tester.pumpAndSettle();

    expect(find.text('TOPLULUK GÜVENLİĞİ KOŞULLARI'), findsOneWidget);
    expect(find.text('Kabul et ve devam et'), findsOneWidget);
    await localeService.setLanguage('en');
  });
}
