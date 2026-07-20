import 'dart:io';

import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late ChatStore store;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('group_chat_store_test_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    store = ChatStore()..autoRepliesEnabled = false;
    await store.initialize();
  });

  tearDownAll(() async {
    await store.saveAll();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('requires two selected recipients and preserves direct chats', () {
    expect(
      store.createGroupThread(creatorId: 'u1', recipientIds: ['u2']),
      isNull,
    );
    expect(store.ensureDirectThread('u1', 'u2'), 'dm:u1|u2');
  });

  test('creates an accessible group with nullable trimmed custom name', () {
    final threadId = store.createGroupThread(
      creatorId: 'u1',
      recipientIds: ['u2', 'u3'],
      customName: '   ',
      photoPath: '/temporary/group-photo.jpg',
    )!;
    final group = store.groupForThread(threadId)!;

    expect(group.customName, isNull);
    expect(group.photoUrl, '/temporary/group-photo.jpg');
    expect(group.memberIds, ['u1', 'u2', 'u3']);
    expect(store.canAccessThread(threadId, 'u1'), isTrue);
    expect(store.canAccessThread(threadId, 'u2'), isTrue);
    expect(store.canAccessThread(threadId, 'u9'), isFalse);
    expect(
      store.threadsFor('u1').singleWhere((t) => t.threadId == threadId).isGroup,
      isTrue,
    );
    expect(store.setGroupPhoto(threadId, null), isTrue);
    expect(store.groupForThread(threadId)?.photoUrl, isNull);
  });

  test('unnamed groups react to members while custom names stay fixed', () {
    final threadId = store.createGroupThread(
      creatorId: 'u1',
      recipientIds: ['u2', 'u3'],
    )!;

    expect(store.groupDisplayName(threadId, 'u1'), 'Can, Emir');
    store.addGroupMembers(threadId, ['u4', 'u5']);
    expect(store.groupDisplayName(threadId, 'u1'), 'Can, Emir +2');

    store.setGroupCustomName(threadId, '  Study Crew  ');
    store.removeGroupMember(threadId, 'u5');
    expect(store.groupDisplayName(threadId, 'u1'), 'Study Crew');

    store.setGroupCustomName(threadId, '\t');
    expect(store.groupDisplayName(threadId, 'u1'), 'Can, Emir, Deniz');
  });

  test('group members can message and outsiders cannot', () {
    final threadId = store.createGroupThread(
      creatorId: 'u1',
      recipientIds: ['u2', 'u3'],
    )!;
    expect(
      store.sendMessage(threadId: threadId, senderId: 'u2', content: 'Hello'),
      isNotNull,
    );
    final groupNotifications = userState.dynamicNotifications
        .where((notification) => notification.targetId == threadId)
        .toList();
    expect(groupNotifications, isNotEmpty);
    expect(
      groupNotifications.every(
        (notification) =>
            notification.message.contains('Can Serbester sent a message'),
      ),
      isTrue,
    );
    expect(
      store.sendMessage(threadId: threadId, senderId: 'u9', content: 'Nope'),
      isNull,
    );
  });
}
