import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/signup_steps/step_email.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pumpEmailStep(
    WidgetTester tester,
    Future<String?> Function(String email) onNext,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: StepEmail(onNext: onNext)),
      ),
    );
    await tester.pump();
  }

  testWidgets('local part is submitted as a complete KU email', (tester) async {
    String? submitted;
    await pumpEmailStep(tester, (email) async {
      submitted = email;
      return null;
    });

    expect(
      find.text(
        "Only @ku.edu.tr addresses are accepted. Personal emails won't work.",
      ),
      findsNothing,
    );

    await tester.enterText(find.byType(TextField), 'htuncay23');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(submitted, 'htuncay23@ku.edu.tr');
  });

  testWidgets('full KU email is accepted and normalized in the field', (
    tester,
  ) async {
    String? submitted;
    await pumpEmailStep(tester, (email) async {
      submitted = email;
      return null;
    });

    await tester.enterText(find.byType(TextField), 'HTUNCAY23@KU.EDU.TR');
    await tester.pump();

    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'HTUNCAY23',
    );

    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(submitted, 'htuncay23@ku.edu.tr');
  });

  testWidgets('non-KU email shows the restriction only after submission', (
    tester,
  ) async {
    var submissions = 0;
    await pumpEmailStep(tester, (email) async {
      submissions++;
      return null;
    });

    expect(find.text('Only @ku.edu.tr addresses are accepted.'), findsNothing);

    await tester.enterText(find.byType(TextField), 'student@gmail.com');
    await tester.tap(find.text('Continue'));
    await tester.pump();

    expect(
      find.text('Only @ku.edu.tr addresses are accepted.'),
      findsOneWidget,
    );
    expect(submissions, 0);
  });
}
