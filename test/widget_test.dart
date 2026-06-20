import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

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
        home: LoginScreen(
          onLogin: () {},
          onSignUp: () => signUpTapped = true,
          onAdminLogin: () {},
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('Sign up'));
    await tester.pump();

    expect(signUpTapped, isTrue);
  });
}
