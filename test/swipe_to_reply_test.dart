import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/widgets/swipe_to_reply.dart';

void main() {
  Widget host({
    required VoidCallback onReply,
    bool enabled = true,
    ScrollController? controller,
  }) => MaterialApp(
    home: Scaffold(
      body: ListView(
        controller: controller,
        children: [
          const SizedBox(height: 400),
          SwipeToReply(
            enabled: enabled,
            onReply: onReply,
            child: Container(
              key: const ValueKey('bubble'),
              height: 60,
              color: Colors.blue,
              child: const Text('hello'),
            ),
          ),
          const SizedBox(height: 800),
        ],
      ),
    ),
  );

  testWidgets('right swipe past the threshold fires a reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    await tester.drag(find.byKey(const ValueKey('bubble')), const Offset(80, 0));
    await tester.pumpAndSettle();

    expect(replies, 1);
  });

  testWidgets('a short swipe does not fire, and the bubble settles back', (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    await tester.drag(find.byKey(const ValueKey('bubble')), const Offset(20, 0));
    await tester.pumpAndSettle();

    expect(replies, 0);
    // Back at rest — no residual offset left behind.
    final shifted = tester.widget<Transform>(
      find
          .descendant(
            of: find.byType(SwipeToReply),
            matching: find.byType(Transform),
          )
          .last,
    );
    expect(shifted.transform.getTranslation().x, 0);
  });

  testWidgets('dragging back under the threshold disarms the reply', (
    tester,
  ) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const ValueKey('bubble'))),
    );
    await gesture.moveBy(const Offset(70, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(-60, 0)); // pull it back and bail out
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    expect(replies, 0);
  });

  testWidgets('left swipe never fires a reply', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++));

    await tester.drag(
      find.byKey(const ValueKey('bubble')),
      const Offset(-90, 0),
    );
    await tester.pumpAndSettle();

    expect(replies, 0);
  });

  testWidgets('read-only threads ignore the gesture', (tester) async {
    var replies = 0;
    await tester.pumpWidget(host(onReply: () => replies++, enabled: false));

    await tester.drag(find.byKey(const ValueKey('bubble')), const Offset(90, 0));
    await tester.pumpAndSettle();

    expect(replies, 0);
  });

  testWidgets('vertical drags still scroll the thread', (tester) async {
    var replies = 0;
    final controller = ScrollController();
    await tester.pumpWidget(
      host(onReply: () => replies++, controller: controller),
    );
    final before = controller.offset;

    await tester.drag(
      find.byKey(const ValueKey('bubble')),
      const Offset(0, -220),
    );
    await tester.pumpAndSettle();

    expect(controller.offset, greaterThan(before));
    expect(replies, 0);
    controller.dispose();
  });
}
