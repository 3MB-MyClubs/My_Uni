import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/navigation/chat_page_route.dart';

void main() {
  Future<PageRoute<void>> openConversation(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  ChatPageRoute<void>(
                    builder: (_) => const Scaffold(
                      body: ColoredBox(
                        color: Colors.white,
                        child: Center(child: Text('Conversation')),
                      ),
                    ),
                  ),
                );
              },
              child: const Text('Chats'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Chats'));
    await tester.pumpAndSettle();

    final route = ModalRoute.of(tester.element(find.text('Conversation')));
    expect(route, isA<ChatPageRoute<void>>());
    return route! as PageRoute<void>;
  }

  testWidgets('chat routes can be popped with a leading-edge swipe', (
    tester,
  ) async {
    final route = await openConversation(tester);
    expect(route.popGestureEnabled, isTrue);

    await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Conversation'), findsNothing);
    expect(find.text('Chats'), findsOneWidget);
  });

  testWidgets('chat routes track and cancel an incomplete edge swipe', (
    tester,
  ) async {
    final route = await openConversation(tester);
    final gesture = await tester.startGesture(const Offset(1, 300));

    await gesture.moveBy(const Offset(80, 0));
    await tester.pump();

    expect(route.popGestureInProgress, isTrue);
    expect(route.animation!.value, lessThan(1));
    expect(find.text('Chats'), findsOneWidget);

    await gesture.up();
    await tester.pumpAndSettle();

    expect(route.popGestureInProgress, isFalse);
    expect(route.animation!.value, 1);
    expect(find.text('Conversation'), findsOneWidget);
  });
}
