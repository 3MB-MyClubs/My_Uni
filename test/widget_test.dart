import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/main.dart';
import 'package:flutter_application_1/screens/login_screen.dart';

void main() {
  testWidgets('app shows auth choice screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Koç University'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
    expect(find.text('I already have one'), findsOneWidget);
  });

  testWidgets('login quick email does not fill password', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MaterialApp(home: LoginScreen(onLogin: () {})));

    final passwordField = find.byType(TextField).at(1);
    await tester.enterText(passwordField, '11111111');
    await tester.tap(find.text('htuncay23@ku.edu.tr'));
    await tester.pump();

    final passwordTextField = tester.widget<TextField>(passwordField);
    expect(passwordTextField.controller?.text, isEmpty);
  });
}
