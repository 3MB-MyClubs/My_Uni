import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_pressable.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('compresses while pressed and invokes its action', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPressable(
            onTap: () => taps++,
            child: const SizedBox(
              key: ValueKey('target'),
              width: 100,
              height: 50,
            ),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('target'))),
    );
    await tester.pump();

    final pressedScale = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(pressedScale.scale, lessThan(1));

    await gesture.up();
    await tester.pumpAndSettle();

    expect(taps, 1);
    final releasedScale = tester.widget<AnimatedScale>(
      find.byType(AnimatedScale),
    );
    expect(releasedScale.scale, 1);
  });

  testWidgets('does not animate when disabled', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPressable(
            child: SizedBox(key: ValueKey('disabled'), width: 100, height: 50),
          ),
        ),
      ),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('disabled'))),
    );
    await tester.pump();

    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });
}
