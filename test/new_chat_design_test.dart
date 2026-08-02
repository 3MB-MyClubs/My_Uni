import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/chat_campus_backdrop.dart';
import 'package:flutter_application_1/widgets/group_avatar_stack.dart';
import 'package:flutter_application_1/widgets/presence_avatar.dart';
import 'package:hive/hive.dart';

/// Verifies the "New chat" design (campus wallpaper, intro card, composer) on
/// student threads — direct messages and student-created groups.
void main() {
  late Directory tempDir;
  late String myId;

  const peer = ('design-peer-1', 'Can Serbester');
  const second = ('design-peer-2', 'Emir Karaarslan');

  User buildPeer((String, String) person) => User(
    id: person.$1,
    name: person.$2,
    email: '${person.$1}@ku.edu.tr',
    password: '',
    role: 'student',
    subscribedClubIds: const [],
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('new_chat_design_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await themeService.setDark(true);
    await authService.logout();
    // The mock directory ships empty, so register the session and its peers
    // directly instead of signing in as a seeded user.
    users.removeWhere((user) => user.email.endsWith('@ku.edu.tr'));
    expect(
      authService.signUp('Design Tester', 'design.tester@ku.edu.tr', '135790'),
      isTrue,
    );
    myId = authService.currentUser!.id;
    for (final person in [peer, second]) {
      peopleService.cacheRegisteredUser(buildPeer(person));
    }
  });

  tearDown(() async => authService.logout());

  Future<void> pumpThread(WidgetTester tester, String threadId) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: threadId)),
      ),
    );
    await tester.pump();
  }

  testWidgets('empty DM shows the campus canvas, intro card and composer', (
    tester,
  ) async {
    final threadId = ChatStore.dmThreadId(myId, peer.$1);
    chatStore.ensureDirectThread(myId, peer.$1);

    await pumpThread(tester, threadId);

    // Canvas: flat body under the wallpaper + bloom layer.
    expect(
      find.byKey(const ValueKey('chat-conversation-backdrop')),
      findsOneWidget,
    );
    expect(find.byType(ChatCampusBackdrop), findsOneWidget);

    // Intro: the peer's name heads it, over a single quiet context line.
    expect(
      find.byKey(const ValueKey('chat-empty-conversation-card')),
      findsOneWidget,
    );
    expect(find.text(peer.$2), findsNWidgets(2)); // header + intro headline
    // Nothing in common yet, so the line falls back to naming the state.
    expect(find.text(S.chatNoMessagesYet), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-starter-chips')), findsNothing);

    // Composer: attach, camera, and a disabled send affordance until typing.
    expect(find.byKey(const ValueKey('chat-attach-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-camera-button')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-send-button')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    final messageField = tester.widget<TextField>(find.byType(TextField));
    expect(messageField.maxLines, 1);
    expect(messageField.textInputAction, TextInputAction.send);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Draft');
    await tester.pump();
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
    expect(find.byIcon(Icons.mic_none_rounded), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(
      chatStore
          .messagesFor(threadId, viewerId: myId)
          .map((message) => message.content),
      contains('Draft'),
    );

    // Flush the store's debounced save on the real event loop, so no fake-async
    // timer survives the test.
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty group chat uses the group copy and member count', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;

    await pumpThread(tester, threadId);

    // Header: stacked member avatars plus "N people".
    expect(find.byKey(const ValueKey('group-chat-header')), findsOneWidget);
    expect(find.text(S.chatPeopleCount(3)), findsOneWidget);

    // Intro: stacked avatars over the "N people · created by you" line.
    expect(
      find.byKey(const ValueKey('chat-empty-conversation-card')),
      findsOneWidget,
    );
    expect(find.byType(GroupAvatarStack), findsNWidgets(2));
    expect(
      find.text('${S.chatPeopleCount(3)} · ${S.chatCreatedByYou}'),
      findsOneWidget,
    );

    // Flush the store's debounced save on the real event loop, so no fake-async
    // timer survives the test.
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('chat attachment sheet only offers photos and camera', (
    tester,
  ) async {
    final threadId = ChatStore.dmThreadId(myId, second.$1);
    chatStore.ensureDirectThread(myId, second.$1);

    await pumpThread(tester, threadId);
    await tester.tap(find.byKey(const ValueKey('chat-attach-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('chat-attach-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-attach-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-attach-camera')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-attach-file')), findsNothing);

    Navigator.of(
      tester.element(find.byKey(const ValueKey('chat-attach-sheet'))),
    ).pop();
    await tester.pumpAndSettle();
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('thread header keeps both kinds on the same metrics', (
    tester,
  ) async {
    // Direct message: grounded back button, no drill-in chevron.
    chatStore.ensureDirectThread(myId, peer.$1);
    await pumpThread(tester, ChatStore.dmThreadId(myId, peer.$1));

    final back = find.byKey(const ValueKey('chat-thread-back'));
    expect(back, findsOneWidget);
    expect(tester.getSize(back), const Size(44, 44));
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    final dmHeaderHeight = tester.getSize(find.byType(PresenceAvatar).first);
    expect(dmHeaderHeight.height, 38);

    // Group: same back button and avatar box, plus the drill-in chevron. The
    // stacked avatars get a reserved slot so they cannot collide with either.
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;
    await pumpThread(tester, threadId);

    expect(
      tester.getSize(find.byKey(const ValueKey('chat-thread-back'))),
      const Size(44, 44),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsOneWidget);
    final stack = tester.getSize(find.byType(GroupAvatarStack).first);
    expect(stack.height, 38);
    // Reserved slot is wider than the stack's own box, absorbing its bleed.
    final slot = tester.getSize(
      find
          .ancestor(
            of: find.byType(GroupAvatarStack).first,
            matching: find.byType(Stack),
          )
          .first,
    );
    expect(slot.width, greaterThan(stack.width));

    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pushed chat keeps its back button below the device inset', (
    tester,
  ) async {
    final threadId = ChatStore.dmThreadId(myId, peer.$1);
    chatStore.ensureDirectThread(myId, peer.$1);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          builder: (context, child) => MediaQuery(
            data: const MediaQueryData(
              size: Size(390, 844),
              padding: EdgeInsets.only(top: 59),
              viewPadding: EdgeInsets.only(top: 59),
            ),
            child: child!,
          ),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-chat'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ChatThreadScreen(threadId: threadId),
                    ),
                  ),
                  child: const Text('Open chat'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-chat')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final back = find.byKey(const ValueKey('chat-thread-back'));
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back).dy, greaterThanOrEqualTo(59));

    await tester.tap(back);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('open-chat')), findsOneWidget);

    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-pressing a message adds a reaction chip', (tester) async {
    final threadId = ChatStore.dmThreadId(myId, peer.$1);
    chatStore.ensureDirectThread(myId, peer.$1);
    final message = chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'Reactable message',
    )!;

    await pumpThread(tester, threadId);

    await tester.longPress(find.byKey(ValueKey('chat-message-${message.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('chat-reaction-sheet')), findsOneWidget);
    expect(
      find.byKey(ValueKey('chat-delete-message-${message.id}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('chat-reaction-option-🎉')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('chat-reaction-${message.id}-🎉')),
      findsOneWidget,
    );
    // Flush the store's debounced save on the real event loop, so no fake-async
    // timer survives the test.
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });
}
