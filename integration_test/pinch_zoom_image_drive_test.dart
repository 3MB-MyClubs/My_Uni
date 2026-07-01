import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/widgets/pinch_zoom_image.dart';

/// Drives the in-place, Instagram-style pinch-to-zoom widget inside a scrolling
/// list, verifying:
///  - a two-finger pinch lifts a zoomed copy of the child into an overlay,
///  - releasing (a finger lifts) snaps it back and removes the overlay,
///  - a single-finger vertical drag still scrolls the list (no zoom),
///  - the list does NOT scroll while a two-finger pinch is in progress.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const targetKey = ValueKey('pz-target');

  Widget harness({ScrollController? controller}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            Container(height: 400, color: const Color(0xFFEEEEEE)),
            PinchZoomImage(
              child: Container(
                key: targetKey,
                height: 300,
                color: const Color(0xFF1565C0),
                alignment: Alignment.center,
                child: const Text(
                  'PINCH ME',
                  style: TextStyle(color: Colors.white, fontSize: 28),
                ),
              ),
            ),
            Container(height: 1400, color: const Color(0xFFC8E6C9)),
          ],
        ),
      ),
    );
  }

  // Copies of the target: 1 at rest, 2 while a pinch has lifted an overlay copy.
  int targetCount() => find.byKey(targetKey).evaluate().length;

  Future<void> shot(WidgetTester t, String name) async {
    await t.pump(const Duration(milliseconds: 300));
    await binding.takeScreenshot(name);
  }

  testWidgets('Two-finger pinch lifts an overlay copy, then snaps back', (
    tester,
  ) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 100));
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await shot(tester, 'pz-01-rest');

    expect(targetCount(), 1);
    final center = tester.getCenter(find.byKey(targetKey));

    // Two fingers down, then spread apart to zoom.
    final g1 = await tester.startGesture(center + const Offset(-30, 0));
    final g2 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 12; i++) {
      await g1.moveBy(const Offset(-14, -7));
      await g2.moveBy(const Offset(14, 7));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, 'pz-02-zoomed');

    // The lifted overlay copy is mounted alongside the (hidden) original.
    expect(targetCount(), 2);

    // Lift one finger → pinch ends → snap-back animation runs.
    await g1.up();
    await tester.pump(const Duration(milliseconds: 16));
    await g2.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await shot(tester, 'pz-03-snapped-back');

    // Overlay removed → single copy again.
    expect(targetCount(), 1);
  });

  testWidgets('Single-finger drag scrolls the list (no zoom)', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pump(const Duration(milliseconds: 100));

    final beforeTop = tester.getTopLeft(find.byKey(targetKey)).dy;

    // Single-finger drag upward, starting on the pinch target.
    await tester.drag(find.byKey(targetKey), const Offset(0, -220));
    await tester.pump(const Duration(milliseconds: 300));

    final afterTop = tester.getTopLeft(find.byKey(targetKey)).dy;

    // It scrolled (target moved up) and no overlay copy was created.
    expect(afterTop, lessThan(beforeTop - 100));
    expect(targetCount(), 1);
  });

  testWidgets('List does not scroll while a two-finger pinch is active', (
    tester,
  ) async {
    final controller = ScrollController();
    await tester.pumpWidget(harness(controller: controller));
    await tester.pump(const Duration(milliseconds: 100));

    expect(controller.offset, 0);
    final center = tester.getCenter(find.byKey(targetKey));

    // Two fingers move upward together — this WOULD scroll the list if the
    // pinch didn't capture the pointers.
    final g1 = await tester.startGesture(center + const Offset(-30, 0));
    final g2 = await tester.startGesture(center + const Offset(30, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (var i = 0; i < 12; i++) {
      await g1.moveBy(const Offset(-6, -20));
      await g2.moveBy(const Offset(6, -20));
      await tester.pump(const Duration(milliseconds: 16));
    }

    // The pinch is active (overlay copy mounted) and the list did NOT scroll.
    expect(targetCount(), 2);
    expect(controller.offset, lessThan(1.0));

    await g1.up();
    await g2.up();
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  });
}
