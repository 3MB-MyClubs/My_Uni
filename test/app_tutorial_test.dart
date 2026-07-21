import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/widgets/app_tutorial_overlay.dart';

void main() {
  test('tutorial completion is stored per user', () async {
    SharedPreferences.setMockInitialValues({});
    final service = TutorialService();
    await service.initialize();

    expect(service.isComplete('student-1'), isFalse);
    expect(service.isComplete('student-2'), isFalse);

    await service.complete('student-1');

    expect(service.isComplete('student-1'), isTrue);
    expect(service.isComplete('student-2'), isFalse);

    await service.reset('student-1');
    expect(service.isComplete('student-1'), isFalse);
  });

  Widget buildOverlay({
    required VoidCallback onComplete,
    required VoidCallback onSkip,
  }) {
    return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: AppTutorialOverlay(
          steps: const [
            AppTutorialStep(
              eyebrow: 'First',
              title: 'Welcome',
              description: 'First tutorial step.',
              icon: Icons.home,
              tabIndex: 0,
            ),
            AppTutorialStep(
              eyebrow: 'Second',
              title: 'Ready',
              description: 'Last tutorial step.',
              icon: Icons.check,
              tabIndex: 1,
            ),
          ],
          onStepChanged: (_) {},
          onComplete: onComplete,
          onSkip: onSkip,
        ),
      ),
    );
  }

  testWidgets('tutorial can be skipped from a non-final step', (tester) async {
    var skipped = false;

    await tester.pumpWidget(
      buildOverlay(onComplete: () {}, onSkip: () => skipped = true),
    );
    await tester.pump();

    expect(find.text('Skip tour'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.text('Skip tour'));
    expect(skipped, isTrue);
  });

  testWidgets('tutorial hides skip on the last step and completes', (
    tester,
  ) async {
    var completed = false;

    await tester.pumpWidget(
      buildOverlay(onComplete: () => completed = true, onSkip: () {}),
    );
    await tester.pump();

    await tester.tap(find.text('Next'));
    await tester.pump();

    // The last step intentionally hides "Skip tour"; the primary button
    // finishes the tour instead.
    expect(find.text('Skip tour'), findsNothing);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.text('Start exploring'));
    expect(completed, isTrue);
  });
}
