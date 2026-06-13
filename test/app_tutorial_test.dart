import 'package:flutter/material.dart';
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

  testWidgets('tutorial keeps skip visible and moves through its steps', (
    tester,
  ) async {
    var skipped = false;
    var completed = false;

    await tester.pumpWidget(
      MaterialApp(
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
            onComplete: () => completed = true,
            onSkip: () => skipped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Skip tour'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Welcome'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pump();

    expect(find.text('Skip tour'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('Ready'), findsOneWidget);

    await tester.tap(find.text('Start exploring'));
    expect(completed, isTrue);

    await tester.tap(find.text('Skip tour'));
    expect(skipped, isTrue);
  });
}
