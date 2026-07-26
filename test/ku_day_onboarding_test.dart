import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/screens/ku_day_onboarding_sheet.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';

void main() {
  tearDown(authService.logout);

  testWidgets('KU Day setup has a skip button on every step', (tester) async {
    authService.login(users.first.email, users.first.password);
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showKuDayOnboarding(context),
                  child: const Text('Open setup'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open setup'));
    await tester.pumpAndSettle();
    expect(find.text('What are you into?'), findsOneWidget);
    expect(find.text('Skip setup'), findsOneWidget);

    final firstNext = find.byKey(const ValueKey('ku-day-next-step-0'));
    await tester.ensureVisible(firstNext);
    await tester.tap(firstNext);
    await tester.pumpAndSettle();
    expect(find.text('What\'s your major?'), findsOneWidget);
    expect(find.text('Skip setup'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('ku-day-major-Engineering')));
    await tester.pump();
    final secondNext = find.byKey(const ValueKey('ku-day-next-step-1'));
    await tester.ensureVisible(secondNext);
    await tester.tap(secondNext);
    await tester.pumpAndSettle();
    expect(find.text('When do you usually have time?'), findsOneWidget);
    expect(find.text('Skip setup'), findsOneWidget);

    final thirdNext = find.byKey(const ValueKey('ku-day-next-step-2'));
    await tester.ensureVisible(thirdNext);
    await tester.tap(thirdNext);
    await tester.pumpAndSettle();
    expect(find.text('Clubs picked for you'), findsOneWidget);
    expect(find.text('Skip setup'), findsOneWidget);

    await tester.ensureVisible(find.text('Skip setup'));
    await tester.tap(find.text('Skip setup'));
    await tester.pumpAndSettle();
    expect(find.text('Open setup'), findsOneWidget);
  });
}
