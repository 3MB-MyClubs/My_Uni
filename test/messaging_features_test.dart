import 'dart:io';

import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late ChatStore store;
  late Club club;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('messaging_features_');
    Hive.init(tempDir.path);
    club = Club(
      id: 'club-feature-fixture',
      name: 'Feature Club',
      description: 'Messaging fixture',
      adminUserIds: const ['club-account'],
      boardMemberIds: const ['board-member'],
    );
    clubs.add(club);
    await contentStore.initialize();
    store = ChatStore();
    await store.initialize();
  });

  tearDownAll(() async {
    await store.saveAll();
    clubs.remove(club);
    userState.followedClubIds.clear();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(userState.followedClubIds.clear);

  test('club followers read while board members publish polls', () {
    final threadId = ChatStore.clubThreadId(club.id);
    userState.followedClubIds.add(club.id);

    expect(store.canAccessThread(threadId, 'regular-follower'), isTrue);
    expect(store.canWriteThread(threadId, 'regular-follower'), isFalse);
    expect(
      store.sendMessage(
        threadId: threadId,
        senderId: 'regular-follower',
        content: 'followers cannot broadcast',
      ),
      isNull,
    );

    expect(store.canWriteThread(threadId, 'board-member'), isTrue);
    final poll = store.sendMessage(
      threadId: threadId,
      senderId: 'board-member',
      content: '',
      kind: ChatMessageKind.poll,
      title: 'Which workshop?',
      pollOptions: const ['Flutter', 'Robotics'],
    );
    expect(poll, isNotNull);
    expect(poll!.pollOptions, const ['Flutter', 'Robotics']);

    expect(
      store.votePoll(
        messageId: poll.id,
        userId: 'regular-follower',
        optionIndex: 1,
      ),
      isTrue,
    );
    expect(store.messageById(poll.id)!.pollVotes, {'regular-follower': 1});

    // Selecting the same option retracts the vote, matching the remote
    // delete performed by the Supabase-backed store.
    expect(
      store.votePoll(
        messageId: poll.id,
        userId: 'regular-follower',
        optionIndex: 1,
      ),
      isTrue,
    );
    expect(store.messageById(poll.id)!.pollVotes, isEmpty);
  });

  test('shared posts survive message model serialization', () {
    final threadId = store.ensureDirectThread('student-a', 'student-b')!;
    final message = store.sendMessage(
      threadId: threadId,
      senderId: 'student-a',
      content: 'Campus update',
      kind: ChatMessageKind.postShare,
      sharedPostId: 'post-123',
    );

    expect(message, isNotNull);
    final restored = ChatMessage.fromMap(message!.toMap());
    expect(restored.kind, ChatMessageKind.postShare);
    expect(restored.sharedPostId, 'post-123');
  });

  test('normal users can create a group and exchange messages', () {
    final threadId = store.createGroupThread(
      creatorId: 'student-a',
      recipientIds: const ['student-b', 'student-c'],
      customName: 'Study group',
    );

    expect(threadId, isNotNull);
    expect(store.canAccessThread(threadId!, 'student-b'), isTrue);
    expect(
      store.sendMessage(
        threadId: threadId,
        senderId: 'student-b',
        content: 'Hello everyone',
      ),
      isNotNull,
    );
  });

  test('private club inbox thread identifiers are distinct', () {
    const inboxId = '11111111-1111-1111-1111-111111111111';
    final threadId = ChatStore.clubInboxThreadId(inboxId);
    expect(ChatStore.isClubInboxThread(threadId), isTrue);
    expect(ChatStore.clubInboxIdOf(threadId), inboxId);
    expect(ChatStore.isClubThread(threadId), isFalse);
  });
}
