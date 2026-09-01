import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/club_community_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late String myId;

  User peer(String id, String name) => User(
    id: id,
    name: name,
    email: '$id@ku.edu.tr',
    password: '',
    role: 'student',
    subscribedClubIds: const [],
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_typing_widget_');
    Hive.init(tempDir.path);
    await chatStore.initialize();
    expect(
      authService.signUp(
        'Typing Widget Viewer',
        'typing.widget.viewer@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    myId = authService.currentUser!.id;
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pump(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: home)));
    await tester.pump();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await tester.runAsync(chatStore.saveAll);
  }

  testWidgets(
    'DM typing replaces the empty introduction with the peer avatar',
    (tester) async {
      final other = peer('typing-widget-dm-peer', 'Deniz Kaya');
      peopleService.cacheRegisteredUser(other);
      final threadId = ChatStore.dmThreadId(myId, other.id);
      chatStore.ensureDirectThread(myId, other.id);
      chatStore.setTyping(threadId, other.id);
      addTearDown(() => chatStore.clearTyping(threadId, other.id));

      await pump(
        tester,
        ChatThreadScreen(threadId: threadId, recipient: other),
      );

      expect(find.byKey(const ValueKey('chat-typing-bubble')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('chat-empty-conversation-card')),
        findsNothing,
      );
      expect(find.bySemanticsLabel(S.typingOne('Deniz Kaya')), findsOneWidget);

      chatStore.clearTyping(threadId, other.id);
      await tester.pump();
      expect(find.byKey(const ValueKey('chat-typing-bubble')), findsNothing);
      expect(
        find.byKey(const ValueKey('chat-empty-conversation-card')),
        findsOneWidget,
      );
      await finish(tester);
    },
  );

  testWidgets('group renders one bubble with two stacked typers', (
    tester,
  ) async {
    final first = peer('typing-widget-group-one', 'Elif Şahin');
    final second = peer('typing-widget-group-two', 'Can Serbester');
    peopleService.cacheRegisteredUser(first);
    peopleService.cacheRegisteredUser(second);
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [first.id, second.id],
    )!;
    chatStore.setTyping(threadId, first.id);
    chatStore.setTyping(threadId, second.id);
    addTearDown(() {
      chatStore.clearTyping(threadId, first.id);
      chatStore.clearTyping(threadId, second.id);
    });

    await pump(tester, ChatThreadScreen(threadId: threadId));

    expect(find.byKey(const ValueKey('chat-typing-bubble')), findsOneWidget);
    expect(
      find.bySemanticsLabel(S.typingMany('Elif Şahin & Can Serbester')),
      findsOneWidget,
    );
    chatStore.clearTyping(threadId, first.id);
    chatStore.clearTyping(threadId, second.id);
    await finish(tester);
  });

  testWidgets('current-user typing is excluded', (tester) async {
    final other = peer('typing-widget-self-peer', 'Peer');
    peopleService.cacheRegisteredUser(other);
    final threadId = ChatStore.dmThreadId(myId, other.id);
    chatStore.ensureDirectThread(myId, other.id);
    chatStore.setTyping(threadId, myId);
    addTearDown(() => chatStore.clearTyping(threadId, myId));

    await pump(tester, ChatThreadScreen(threadId: threadId, recipient: other));

    expect(find.byKey(const ValueKey('chat-typing-bubble')), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-empty-conversation-card')),
      findsOneWidget,
    );
    chatStore.clearTyping(threadId, myId);
    await finish(tester);
  });

  testWidgets('club chat uses one multi-user typing history row', (
    tester,
  ) async {
    const clubId = 'typing-widget-club';
    final first = peer('typing-widget-board-one', 'Board One');
    final second = peer('typing-widget-board-two', 'Board Two');
    peopleService.cacheRegisteredUser(first);
    peopleService.cacheRegisteredUser(second);
    clubs.removeWhere((club) => club.id == clubId);
    clubs.add(
      Club(
        id: clubId,
        name: 'Typing Club',
        description: 'Typing fixture',
        adminUserIds: const [],
        boardMemberIds: [myId, first.id, second.id],
      ),
    );
    userState.followedClubIds.add(clubId);
    final threadId = ChatStore.clubThreadId(clubId);
    chatStore.setTyping(threadId, first.id);
    chatStore.setTyping(threadId, second.id);
    addTearDown(() {
      chatStore.clearTyping(threadId, first.id);
      chatStore.clearTyping(threadId, second.id);
      userState.followedClubIds.remove(clubId);
      clubs.removeWhere((club) => club.id == clubId);
    });

    await pump(
      tester,
      ClubCommunityScreen(threadId: threadId, initialLane: ClubChatLane.chat),
    );

    expect(find.byKey(const ValueKey('club-typing-row')), findsOneWidget);
    expect(
      find.bySemanticsLabel(S.typingMany('Board & Board')),
      findsOneWidget,
    );
    chatStore.clearTyping(threadId, first.id);
    chatStore.clearTyping(threadId, second.id);
    await finish(tester);
  });

  testWidgets('private club inbox shows its peer typing', (tester) async {
    const clubId = 'typing-widget-inbox-club';
    final board = peer('typing-widget-inbox-board', 'Inbox Board');
    peopleService.cacheRegisteredUser(board);
    clubs.removeWhere((club) => club.id == clubId);
    clubs.add(
      Club(
        id: clubId,
        name: 'Inbox Club',
        description: 'Inbox fixture',
        adminUserIds: const [],
        boardMemberIds: [board.id],
      ),
    );
    final inbox = ClubInboxConversation(
      id: 'typing-widget-inbox',
      clubId: clubId,
      profileId: myId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    chatStore.debugCacheClubInboxConversation(inbox);
    chatStore.setTyping(inbox.threadId, board.id);
    addTearDown(() {
      chatStore.clearTyping(inbox.threadId, board.id);
      clubs.removeWhere((club) => club.id == clubId);
    });

    await pump(tester, ChatThreadScreen(threadId: inbox.threadId));

    expect(find.byKey(const ValueKey('chat-typing-bubble')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-empty-conversation-card')),
      findsNothing,
    );
    chatStore.clearTyping(inbox.threadId, board.id);
    await finish(tester);
  });
}
