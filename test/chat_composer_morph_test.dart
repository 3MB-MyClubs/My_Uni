import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/widgets/chats_design.dart';

void main() {
  testWidgets('composer trailing button morphs between camera and send', (tester) async {
    final controller = TextEditingController();
    addTearDown(controller.dispose);
    var sends = 0;
    var captures = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChatComposerBar(
            controller: controller,
            enabled: true,
            hint: 'Type…',
            onSend: () {
              sends++;
              controller.clear();
            },
            onCameraCapture: () => captures++,
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('chat-camera-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-send-button')), findsNothing);

    // Type, pump one frame, tap send immediately (mid-morph).
    await tester.enterText(find.byType(TextField), 'On my way');
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-send-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump();
    expect(sends, 1);
    expect(captures, 0);

    // Rapid re-send within the morph window: the timing that made the old
    // AnimatedSwitcher stack a second, still-fading send button. Every key
    // must stay unique at every step.
    await tester.pump(const Duration(milliseconds: 60));
    await tester.enterText(find.byType(TextField), 'Second');
    await tester.pump();
    final sendCount = find
        .byKey(const ValueKey('chat-send-button'))
        .evaluate()
        .length;
    final cameraCount = find
        .byKey(const ValueKey('chat-camera-button'))
        .evaluate()
        .length;
    expect(sendCount, 1);
    expect(cameraCount, lessThanOrEqualTo(1));
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump();
    expect(sends, 2);
    await tester.pump(const Duration(milliseconds: 16));
    await tester.enterText(find.byType(TextField), 'Third');
    await tester.pump();
    expect(find.byKey(const ValueKey('chat-send-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump();
    expect(sends, 3);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-camera-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-send-button')), findsNothing);
    // A tap mid-morph must reach the camera once the draft is gone.
    await tester.tap(find.byKey(const ValueKey('chat-camera-button')));
    expect(captures, 1);
  });
}
