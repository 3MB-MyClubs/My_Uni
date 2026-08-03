import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/app_motion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('reminder bell swings on a state change and settles', (
    tester,
  ) async {
    var active = false;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            body: GestureDetector(
              key: const ValueKey('toggle-reminder'),
              onTap: () => setState(() => active = !active),
              child: AnimatedReminderBell(active: active, color: Colors.red),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('toggle-reminder')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));

    final swinging = tester.widget<Transform>(
      find.byKey(const ValueKey('event-reminder-bell-motion')),
    );
    expect(swinging.transform.storage[1].abs(), greaterThan(0.01));

    await tester.pump(const Duration(milliseconds: 500));
    final settled = tester.widget<Transform>(
      find.byKey(const ValueKey('event-reminder-bell-motion')),
    );
    expect(settled.transform.storage[1].abs(), lessThan(0.001));
  });

  testWidgets('validation shake replays when its trigger changes', (
    tester,
  ) async {
    var trigger = 0;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: Center(
                child: ShakeOnChange(
                  trigger: trigger,
                  child: const SizedBox(width: 100, height: 40),
                ),
              ),
            );
          },
        ),
      ),
    );

    update(() => trigger++);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 45));

    final shaking = tester.widget<Transform>(
      find.byKey(const ValueKey('validation-shake-motion')),
    );
    expect(shaking.transform.storage[12].abs(), greaterThan(0.5));

    await tester.pump(const Duration(milliseconds: 400));
    final settled = tester.widget<Transform>(
      find.byKey(const ValueKey('validation-shake-motion')),
    );
    expect(settled.transform.storage[12].abs(), lessThan(0.001));
  });

  testWidgets('follow avatar ring expands briefly when active', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: FollowAvatarPulse(
            active: true,
            color: Colors.red,
            child: SizedBox(width: 48, height: 48),
          ),
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 110));
    final pulse = tester.widget<Transform>(
      find.byKey(const ValueKey('follow-avatar-ring-motion')),
    );
    expect(pulse.transform.getMaxScaleOnAxis(), greaterThan(1));

    await tester.pump(const Duration(milliseconds: 180));
    final settled = tester.widget<Transform>(
      find.byKey(const ValueKey('follow-avatar-ring-motion')),
    );
    expect(settled.transform.getMaxScaleOnAxis(), closeTo(1, 0.001));
  });

  testWidgets('rolling count transitions to its new value', (tester) async {
    var count = 1;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Scaffold(
              body: RollingCount(
                value: count,
                style: const TextStyle(fontSize: 14),
              ),
            );
          },
        ),
      ),
    );

    update(() => count++);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('2'), findsOneWidget);
    expect(find.text('1'), findsNothing);
  });
}
