import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/navigation/chat_page_route.dart';

void main() {
  testWidgets('chat routes can be popped with a leading-edge swipe', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () {
                Navigator.of(context).push(
                  ChatPageRoute<void>(
                    builder: (_) => const Scaffold(body: Text('Conversation')),
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
    expect((route! as PageRoute<void>).popGestureEnabled, isTrue);

    await tester.dragFrom(const Offset(1, 300), const Offset(700, 0));
    await tester.pumpAndSettle();

    expect(find.text('Conversation'), findsNothing);
    expect(find.text('Chats'), findsOneWidget);
  });
}
