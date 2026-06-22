import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/login_screen.dart';

/// The campus-email field needs only the local part ("htuncay23"); the
/// "@ku.edu.tr" domain is shown as a fixed suffix and never typed. Pasting a
/// full email is normalised back down to the local part.
void main() {
  testWidgets('Email field only needs the username, not @ku.edu.tr', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LoginScreen(onLogin: () {}, onSignUp: () {}, onAdminLogin: () {}),
      ),
    );
    await tester.pump();

    // The domain is presented for the user — they don't type it.
    expect(find.text('@ku.edu.tr'), findsOneWidget);

    final emailField = find.byType(TextField).first;

    // Typing just the username keeps it as-is.
    await tester.enterText(emailField, 'htuncay23');
    await tester.pump();
    expect(tester.widget<TextField>(emailField).controller!.text, 'htuncay23');

    // Even if a full email is pasted, the domain is stripped automatically.
    await tester.enterText(emailField, 'htuncay23@ku.edu.tr');
    await tester.pump();
    expect(tester.widget<TextField>(emailField).controller!.text, 'htuncay23');
  });
}
