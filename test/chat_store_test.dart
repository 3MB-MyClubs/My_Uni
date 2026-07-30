import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/user_state.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chat_store_test_');
    Hive.init(tempDir.path);
    await chatStore.initialize();
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    await Hive.close();
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    userState.followedClubIds.clear();
  });

  group('thread identity', () {
    test('dmThreadId is canonical regardless of argument order', () {
      expect(ChatStore.dmThreadId('u5', 'u2'), 'dm:u2|u5');
      expect(
        ChatStore.dmThreadId('u2', 'u5'),
        ChatStore.dmThreadId('u5', 'u2'),
      );
    });

    test('club/dm helpers parse thread ids', () {
      expect(ChatStore.isClubThread('club:c4'), isTrue);
      expect(ChatStore.isClubThread('dm:u2|u5'), isFalse);
      expect(ChatStore.clubIdOf('club:c4'), 'c4');
      expect(ChatStore.clubIdOf('dm:u2|u5'), isNull);
      expect(ChatStore.dmPeerOf('dm:u2|u5', 'u2'), 'u5');
      expect(ChatStore.dmPeerOf('dm:u2|u5', 'u5'), 'u2');
      expect(ChatStore.dmPeerOf('dm:u2|u5', 'u9'), isNull);
    });

    test(
      'opening a new DM registers an empty conversation by participant IDs',
      () {
        final threadId = chatStore.ensureDirectThread(
          'new-conversation-owner',
          'new-conversation-recipient',
        );

        expect(
          threadId,
          ChatStore.dmThreadId(
            'new-conversation-owner',
            'new-conversation-recipient',
          ),
        );
        final thread = chatStore
            .threadsFor('new-conversation-owner')
            .where((item) => item.threadId == threadId)
            .single;
        expect(thread.peerId, 'new-conversation-recipient');
        expect(thread.lastMessage, isNull);
        expect(chatStore.messagesFor(threadId!), isEmpty);
      },
    );
  });

  group('real-data-only initialization', () {
    test('does not create scripted direct or club messages', () {
      expect(chatStore.messagesFor('club:c4'), isEmpty);
      expect(chatStore.messagesFor('club:c1'), isEmpty);
      expect(chatStore.threadsFor('brand-new-user'), isEmpty);
    });
  });

  group('membership gating', () {
    test('club rooms appear and disappear with followedClubIds', () {
      userState.followedClubIds.add('c4');
      expect(
        chatStore.threadsFor('u2').any((t) => t.threadId == 'club:c4'),
        isTrue,
      );
      userState.followedClubIds.remove('c4');
      expect(
        chatStore.threadsFor('u2').any((t) => t.threadId == 'club:c4'),
        isFalse,
      );
    });

    test('followed clubs with no seed history still get an empty room', () {
      userState.followedClubIds.add('c9'); // no seeded messages
      final threads = chatStore.threadsFor('u2');
      final room = threads.where((t) => t.threadId == 'club:c9').toList();
      expect(room, hasLength(1));
      expect(room.single.lastMessage, isNull);
    });

    test('sendMessage into a club room is blocked for non-members', () {
      final before = chatStore.messagesFor('club:c5').length;
      final sent = chatStore.sendMessage(
        threadId: 'club:c5',
        senderId: 'u2',
        content: 'should not land',
      );
      expect(sent, isNull);
      expect(chatStore.messagesFor('club:c5').length, before);
    });

    test('members can post; DMs are limited to participants', () {
      userState.followedClubIds.add('c5');
      final sent = chatStore.sendMessage(
        threadId: 'club:c5',
        senderId: 'u2',
        content: 'hello mountain people',
      );
      expect(sent, isNotNull);

      expect(
        chatStore.sendMessage(
          threadId: ChatStore.dmThreadId('u3', 'u9'),
          senderId: 'u7', // not a participant
          content: 'intruder',
        ),
        isNull,
      );
    });

    test('club admin can access only their own club room', () {
      // cadmin5 manages c4 (KUACM).
      expect(chatStore.canAccessThread('club:c4', 'cadmin5'), isTrue);
      expect(chatStore.canAccessThread('club:c5', 'cadmin5'), isFalse);
      expect(chatStore.managedCommunityThreadId('cadmin5'), 'club:c4');
      expect(chatStore.threadsFor('cadmin5').map((thread) => thread.threadId), [
        'club:c4',
      ]);
      final sent = chatStore.sendMessage(
        threadId: 'club:c4',
        senderId: 'cadmin5',
        content: 'announcement from the board',
      );
      expect(sent, isNotNull);
    });

    test('another club admin resolves only their own community', () {
      expect(chatStore.managedCommunityThreadId('cadmin6'), 'club:c5');
      expect(chatStore.threadsFor('cadmin6').map((thread) => thread.threadId), [
        'club:c5',
      ]);
      expect(chatStore.canAccessThread('club:c4', 'cadmin6'), isFalse);
    });

    test('database-linked club admin resolves only its own community', () {
      // Real Supabase club sessions use the linked club id itself, rather than
      // one of the local cadmin* fixture ids, as the in-app admin identity.
      authService.setClubAdmin(
        AppAdmin(
          id: 'c5',
          name: 'Database-linked club',
          email: 'database.club@ku.edu.tr',
          password: '',
        ),
      );
      addTearDown(authService.logout);

      expect(ChatStore.isAdminAccountId('c5'), isTrue);
      expect(chatStore.managedCommunityThreadId('c5'), 'club:c5');
      expect(chatStore.canAccessThread('club:c5', 'c5'), isTrue);
      expect(chatStore.canAccessThread('club:c4', 'c5'), isFalse);
      expect(chatStore.ensureDirectThread('c5', 'u2'), isNull);
      expect(chatStore.threadsFor('c5').map((thread) => thread.threadId), [
        'club:c5',
      ]);
      expect(
        chatStore.sendMessage(
          threadId: 'club:c4',
          senderId: 'c5',
          content: 'must not cross into another club',
        ),
        isNull,
      );
      expect(
        chatStore.sendMessage(
          threadId: 'club:c5',
          senderId: 'c5',
          content: 'stays in the linked club community',
        ),
        isNotNull,
      );
    });

    test('admin accounts cannot create, read, or send direct messages', () {
      final adminDm = ChatStore.dmThreadId('cadmin5', 'u2');
      expect(chatStore.ensureDirectThread('cadmin5', 'u2'), isNull);
      expect(chatStore.ensureDirectThread('u2', 'cadmin5'), isNull);
      expect(chatStore.canAccessThread(adminDm, 'cadmin5'), isFalse);
      expect(chatStore.canAccessThread(adminDm, 'u2'), isFalse);
      expect(chatStore.messagesFor(adminDm, viewerId: 'cadmin5'), isEmpty);
      expect(
        chatStore.sendMessage(
          threadId: adminDm,
          senderId: 'cadmin5',
          content: 'blocked admin DM',
        ),
        isNull,
      );
    });

    test('super admin has no chat access', () {
      userState.followedClubIds.add('c4');
      expect(chatStore.canAccessThread('club:c4', 'admin1'), isFalse);
      expect(chatStore.managedCommunityThreadId('admin1'), isNull);
      expect(chatStore.threadsFor('admin1'), isEmpty);
    });
  });

  group('unread + ordering', () {
    test('new direct messages remain Delivered until recipient opens', () {
      final thread = ChatStore.dmThreadId('delivery-sender', 'delivery-peer');
      final sent = chatStore.sendMessage(
        threadId: thread,
        senderId: 'delivery-sender',
        content: 'status check',
      )!;

      expect(sent.status, MessageDeliveryStatus.delivered);
      expect(sent.seenAt, isNull);
      expect(chatStore.unreadCountFor(thread, 'delivery-peer'), 1);

      // Creating/listing the conversation is not proof that it was viewed.
      chatStore.ensureDirectThread('delivery-peer', 'delivery-sender');
      chatStore.threadsFor('delivery-peer');
      expect(
        chatStore.messagesFor(thread).single.status,
        MessageDeliveryStatus.delivered,
      );
    });

    test('opening a DM marks every incoming message Seen in one update', () {
      final thread = ChatStore.dmThreadId('batch-sender', 'batch-recipient');
      chatStore.sendMessage(
        threadId: thread,
        senderId: 'batch-sender',
        content: 'first unread',
      );
      chatStore.sendMessage(
        threadId: thread,
        senderId: 'batch-sender',
        content: 'second unread',
      );
      final recipientMessage = chatStore.sendMessage(
        threadId: thread,
        senderId: 'batch-recipient',
        content: 'my own message',
      )!;

      var notifications = 0;
      void listener() => notifications++;
      chatStore.addListener(listener);
      addTearDown(() => chatStore.removeListener(listener));

      chatStore.markThreadRead(thread, 'batch-recipient');

      final fromSender = chatStore
          .messagesFor(thread)
          .where((message) => message.senderId == 'batch-sender')
          .toList();
      expect(
        fromSender.map((message) => message.status),
        everyElement(MessageDeliveryStatus.seen),
      );
      expect(fromSender.map((message) => message.seenAt).toSet(), hasLength(1));
      expect(recipientMessage.status, MessageDeliveryStatus.delivered);
      expect(chatStore.unreadCountFor(thread, 'batch-recipient'), 0);
      expect(notifications, 1);

      // Reopening an already-seen conversation performs no mutation/write.
      chatStore.markThreadRead(thread, 'batch-recipient');
      expect(notifications, 1);
    });

    test('unread counts ignore own messages and clear on markThreadRead', () {
      final thread = ChatStore.dmThreadId('u3', 'u9');
      chatStore.sendMessage(
        threadId: thread,
        senderId: 'u3',
        content: 'hey, up for the hike?',
      );
      expect(chatStore.unreadCountFor(thread, 'u9'), 1);
      expect(chatStore.unreadCountFor(thread, 'u3'), 0);

      chatStore.markThreadRead(thread, 'u9');
      expect(chatStore.unreadCountFor(thread, 'u9'), 0);
      expect(chatStore.totalUnreadFor('u9'), 0);
    });

    test('empty and whitespace-only messages are rejected', () {
      final thread = ChatStore.dmThreadId('u3', 'u9');
      final before = chatStore.messagesFor(thread).length;
      expect(
        chatStore.sendMessage(threadId: thread, senderId: 'u3', content: '   '),
        isNull,
      );
      expect(chatStore.messagesFor(thread).length, before);
    });

    test('most recently active thread sorts first', () {
      userState.followedClubIds.add('c4');
      final dm = ChatStore.dmThreadId('u2', 'u9');
      chatStore.sendMessage(
        threadId: dm,
        senderId: 'u2',
        content: 'newest message anywhere',
      );
      final threads = chatStore.threadsFor('u2');
      expect(threads.first.threadId, dm);
    });
  });

  test('a local DM never fabricates a reply from its recipient', () async {
    final thread = ChatStore.dmThreadId('local-sender', 'local-recipient');
    final before = chatStore.messagesFor(thread).length;
    final sent = chatStore.sendMessage(
      threadId: thread,
      senderId: 'local-sender',
      content: 'A genuine local message',
    );
    expect(sent, isNotNull);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final messages = chatStore.messagesFor(thread);
    expect(messages, hasLength(before + 1));
    expect(messages.last.senderId, 'local-sender');
  });

  test('messages survive a Hive round-trip', () async {
    final thread = ChatStore.dmThreadId('u6', 'u10');
    chatStore.sendMessage(
      threadId: thread,
      senderId: 'u6',
      content: 'persist me',
    );
    await chatStore.saveAll();

    final box = await Hive.openBox<dynamic>('chat_v1');
    final raw = (box.get('messages') as List)
        .map((m) => Map<String, dynamic>.from(m as Map))
        .toList();
    expect(raw.any((m) => m['content'] == 'persist me'), isTrue);
    final persisted = raw.singleWhere((m) => m['content'] == 'persist me');
    expect(persisted['deliveredAt'], isNotNull);
    expect(persisted.containsKey('seenAt'), isTrue);
  });
}
