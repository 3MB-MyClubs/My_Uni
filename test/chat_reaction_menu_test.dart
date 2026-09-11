import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/chats_design.dart';
import 'package:hive/hive.dart';

/// The long-press reaction menu: a pill that floats beside the bubble the way
/// WhatsApp's does, and a chip that carries no accent frame.
void main() {
  late Directory tempDir;
  late String myId;

  const peer = ('reaction-peer-1', 'Can Serbester');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_reaction_menu_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  tearDownAll(() async {
    // Deliberately no `chatStore.saveAll()`: outside `runAsync` it never
    // completes here and wedges the file in teardown. The box lives in a temp
    // dir that goes away on the next line anyway.
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(false);
    await authService.logout();
    users.removeWhere((user) => user.email.endsWith('@ku.edu.tr'));
    expect(
      authService.signUp('Reaction Tester', 'reaction@ku.edu.tr', '135790'),
      isTrue,
    );
    myId = authService.currentUser!.id;
    peopleService.cacheRegisteredUser(
      User(
        id: peer.$1,
        name: peer.$2,
        email: '${peer.$1}@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
  });

  tearDown(() async => authService.logout());

  testWidgets('reacting floats a pill beside the bubble, not a bottom sheet', (
    tester,
  ) async {
    final threadId = ChatStore.dmThreadId(myId, peer.$1);
    chatStore.ensureDirectThread(myId, peer.$1);
    // Somebody else's message: your own opens the message-info sheet instead.
    final message = chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'Reactable message',
    )!;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: threadId)),
      ),
    );
    await tester.pump();

    final bubble = find.byKey(ValueKey('chat-message-${message.id}'));
    final bubbleRect = tester.getRect(bubble);
    await tester.longPress(bubble);
    await tester.pumpAndSettle();

    final pill = find.byKey(const ValueKey('chat-reaction-sheet'));
    expect(pill, findsOneWidget);
    final pillRect = tester.getRect(pill);
    // Above the bubble and hugging its leading edge — a sheet would sit at the
    // bottom of the window, the whole width of the screen.
    expect(pillRect.bottom, lessThanOrEqualTo(bubbleRect.top));
    expect(pillRect.left, closeTo(bubbleRect.left, 1));
    expect(pillRect.width, lessThan(320)); // a sheet spans the window
    // The actions travel with it.
    expect(
      find.byKey(ValueKey('chat-reply-message-${message.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('chat-reaction-option-🎉')));
    await tester.pumpAndSettle();

    // The menu takes itself away and the chip lands on the bubble.
    expect(pill, findsNothing);
    final chip = find.byKey(ValueKey('chat-reaction-${message.id}-🎉'));
    expect(chip, findsOneWidget);

    // No burgundy frame: your own reaction is a wash, with no border at all.
    final decoration =
        tester
                .widgetList<Container>(
                  find.descendant(of: chip, matching: find.byType(Container)),
                )
                .first
                .decoration
            as BoxDecoration;
    expect(decoration.border, isNull);
    expect(decoration.color, isNot(ChatsColors.accent));

    // Let the store's one-second save debounce fire, or the test ends with a
    // pending timer. `saveAll()` is deliberately not called: it does not
    // complete under this suite's fake clock, and the box is in a temp dir.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
