import 'package:flutter/material.dart';
import 'package:flutter_application_1/widgets/pinch_zoom_image.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('pinch zoom does not swallow an ancestor double tap', (
    tester,
  ) async {
    var doubleTapCount = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: GestureDetector(
              key: const ValueKey('double-tap-target'),
              onDoubleTap: () => doubleTapCount++,
              child: const SizedBox(
                width: 240,
                height: 240,
                child: PinchZoomImage(child: ColoredBox(color: Colors.red)),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('double-tap-target')));
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tap(find.byKey(const ValueKey('double-tap-target')));
    await tester.pump(const Duration(milliseconds: 400));

    expect(doubleTapCount, 1);
  });
}
