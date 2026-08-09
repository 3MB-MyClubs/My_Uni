import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/screens/signup_steps/step_profile.dart';
import 'package:flutter_application_1/services/signup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget buildProfile({ValueChanged<bool>? onSubmitted}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: StepProfile(
          initialName: 'Alice Yılmaz',
          initialMajor: 'Computer Engineering',
          initialYear: 'Freshman',
          loadMajors: () async => const [
            SignupLookupItem(id: 'major-1', name: 'Computer Engineering'),
          ],
          loadAcademicYears: () async => const [
            SignupLookupItem(id: 'year-1', name: 'Freshman'),
          ],
          onNext: (_, _, _, _, _, _, termsAccepted) async {
            onSubmitted?.call(termsAccepted);
            return null;
          },
        ),
      ),
    );
  }

  testWidgets(
    'Terms are accepted only through I Accept and survive a rebuild',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      bool? submittedTermsAccepted;
      final profile = buildProfile(
        onSubmitted: (value) => submittedTermsAccepted = value,
      );
      await tester.pumpWidget(profile);
      await tester.pumpAndSettle();

      Checkbox termsCheckbox() =>
          tester.widget<Checkbox>(find.byType(Checkbox));
      ElevatedButton continueButton() => tester.widget<ElevatedButton>(
        find.byKey(const ValueKey('signup-profile-continue')),
      );

      expect(termsCheckbox().value, isFalse);
      expect(continueButton().onPressed, isNull);

      // A checkbox tap reviews the Terms; it cannot toggle acceptance itself.
      await tester.tapAt(tester.getCenter(find.byType(Checkbox)));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('signup-terms-accept')), findsOneWidget);
      expect(find.text('1. Agreement to these terms'), findsOneWidget);
      expect(find.text('8. Changes and contact'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(termsCheckbox().value, isFalse);
      expect(continueButton().onPressed, isNull);

      // The associated text follows the same review flow.
      await tester.tap(find.byKey(const ValueKey('signup-terms-review')));
      await tester.pumpAndSettle();
      final acceptButton = find.byKey(const ValueKey('signup-terms-accept'));
      // The acceptance action stays pinned below the scrollable legal text,
      // so students can proceed without discovering that they must scroll.
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      expect(termsCheckbox().value, isTrue);
      expect(continueButton().onPressed, isNotNull);

      // A normal parent rebuild must not reset the accepted sign-up state.
      await tester.pumpWidget(profile);
      await tester.pump();
      expect(termsCheckbox().value, isTrue);

      await tester.tap(find.byKey(const ValueKey('signup-profile-continue')));
      await tester.pump();
      expect(submittedTermsAccepted, isTrue);
    },
  );

  test('registration service rejects unaccepted Terms before signup', () async {
    final result = await SignupService().completeSignup(
      email: 'alice@ku.edu.tr',
      password: 'unused',
      fullName: 'Alice Yılmaz',
      majorId: 'major-1',
      academicYearId: 'year-1',
      interestIds: const [],
      termsAccepted: false,
    );

    expect(result.success, isFalse);
    expect(result.error, isNotEmpty);
  });
}
