import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/widgets/chat_reaction_strip.dart';
import 'package:hive/hive.dart';

/// One face per person per message, and what a busy row does about it.
void main() {
  const me = 'reaction-stack-me';

  final style = ChatReactionStyle(
    mineFill: const Color(0xFFF3E1E4),
    otherFill: const Color(0xFFFFFFFF),
    border: const Color(0xFFE4E4E7),
    label: const TextStyle(fontSize: 12),
  );

  Widget host(Map<String, List<String>> reactions, {int maxVisible = 3}) =>
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: ChatReactionStrip(
              messageId: 'm1',
              reactions: reactions,
              myId: me,
              maxVisible: maxVisible,
              style: style,
              onToggle: (_) {},
            ),
          ),
        ),
      );

  group('the store holds one face per person', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('chat_reaction_stack_');
      Hive.init(tempDir.path);
      await contentStore.initialize();
      await chatStore.initialize();
    });

    tearDownAll(() {
      // No `saveAll()`: it never completes outside `runAsync` and wedges the
      // teardown. The box lives in a temp dir that goes away here anyway.
      if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
    });

    test('a second emoji moves your reaction instead of adding one', () {
      const peer = 'reaction-stack-peer';
      final threadId = ChatStore.dmThreadId(me, peer);
      chatStore.ensureDirectThread(me, peer);
      final message = chatStore.sendMessage(
        threadId: threadId,
        senderId: peer,
        content: 'One face only',
      )!;

      expect(
        chatStore.toggleReaction(
          messageId: message.id,
          userId: me,
          emoji: '👍',
        ),
        isTrue,
      );
      expect(chatStore.messageById(message.id)!.reactions, {
        '👍': [me],
      });

      // Picking another face moves it: the thumb goes away with the key.
      chatStore.toggleReaction(messageId: message.id, userId: me, emoji: '❤️');
      final moved = chatStore.messageById(message.id)!;
      expect(moved.reactions, {
        '❤️': [me],
      });
      expect(moved.totalReactions, 1);

      // Somebody else's face is untouched by yours moving around.
      chatStore.toggleReaction(
        messageId: message.id,
        userId: peer,
        emoji: '👍',
      );
      chatStore.toggleReaction(messageId: message.id, userId: me, emoji: '🎉');
      expect(chatStore.messageById(message.id)!.reactions, {
        '👍': [peer],
        '🎉': [me],
      });

      // Re-picking the face you hold takes it back.
      chatStore.toggleReaction(messageId: message.id, userId: me, emoji: '🎉');
      expect(chatStore.messageById(message.id)!.reactions, {
        '👍': [peer],
      });
    });
  });

  testWidgets('three faces stay side by side', (tester) async {
    await tester.pumpWidget(
      host({
        '👍': const ['a'],
        '❤️': const [me],
        '🎉': const ['c'],
      }),
    );

    for (final emoji in ['👍', '❤️', '🎉']) {
      expect(find.byKey(ValueKey('chat-reaction-m1-$emoji')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('chat-reaction-stack-m1')), findsNothing);
  });

  testWidgets('a fourth face stacks the row, and a tap opens it', (
    tester,
  ) async {
    await tester.pumpWidget(
      host({
        '👍': const ['a', 'b'],
        '❤️': const [me],
        '🎉': const ['c'],
        '😂': const ['d'],
      }),
    );

    final stack = find.byKey(const ValueKey('chat-reaction-stack-m1'));
    expect(stack, findsOneWidget);
    // Collapsed: no individual chips, and the total counts people not faces.
    expect(find.byKey(const ValueKey('chat-reaction-m1-👍')), findsNothing);
    expect(find.text('5'), findsOneWidget);
    // Only the leading three faces are drawn, the busiest first.
    expect(find.text('👍'), findsOneWidget);
    expect(find.text('😂'), findsNothing);
    // Narrower than the four chips it replaces would have been.
    expect(tester.getSize(stack).width, lessThan(120));

    await tester.tap(stack);
    await tester.pumpAndSettle();

    for (final emoji in ['👍', '❤️', '🎉', '😂']) {
      expect(find.byKey(ValueKey('chat-reaction-m1-$emoji')), findsOneWidget);
    }
    // Opened rows carry the way back.
    final collapse = find.byKey(const ValueKey('chat-reaction-collapse-m1'));
    expect(collapse, findsOneWidget);
    await tester.tap(collapse);
    await tester.pumpAndSettle();
    expect(stack, findsOneWidget);
  });
}
