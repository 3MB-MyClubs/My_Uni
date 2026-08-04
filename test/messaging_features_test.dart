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

  test('club members read Chat while only the board can post', () {
    final threadId = ChatStore.clubThreadId(club.id);
    userState.followedClubIds.add(club.id);

    // Every member can read the room, but only the yönetim kurulu may post.
    expect(store.canAccessThread(threadId, 'regular-follower'), isTrue);
    expect(store.canWriteThread(threadId, 'regular-follower'), isFalse);
    expect(
      store.sendMessage(
        threadId: threadId,
        senderId: 'regular-follower',
        content: 'see you at the build session',
      ),
      isNull,
    );

    // The Board lane is the notice area: a member without a role cannot
    // publish one, nor pin anything, however the UI is driven.
    expect(store.canPostNotice(threadId, 'regular-follower'), isFalse);
    expect(
      store.sendMessage(
        threadId: threadId,
        senderId: 'regular-follower',
        content: 'lab hours extended',
        kind: ChatMessageKind.announcement,
        title: 'Not an officer',
      ),
      isNull,
    );
    expect(
      store.sendMessage(
        threadId: threadId,
        senderId: 'regular-follower',
        content: 'pin me',
        pinned: true,
      ),
      isNull,
    );

    expect(store.canPostNotice(threadId, 'board-member'), isTrue);
    final notice = store.sendMessage(
      threadId: threadId,
      senderId: 'board-member',
      content: 'Lab hours are extended to 22:00 all week.',
      kind: ChatMessageKind.announcement,
      title: 'Build sprint starts Monday',
      pinned: true,
    );
    expect(notice, isNotNull);
    expect(ChatStore.laneOf(notice!), ClubChatLane.board);
    expect(
      store.noticesIn(threadId).map((message) => message.id),
      contains(notice.id),
    );

    // Replies never live under a notice: only a board member may quote it in
    // the room, and that count is the signal the Board shows.
    final reply = store.sendMessage(
      threadId: threadId,
      senderId: 'board-member',
      content: 'I can take the camera rig',
      replyToMessageId: notice.id,
    );
    expect(reply, isNotNull);
    expect(ChatStore.laneOf(reply!), ClubChatLane.chat);
    expect(store.replyCountFor(notice.id), 1);

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

  test('a club room counts its two lanes separately', () async {
    final other = Club(
      id: 'club-lane-fixture',
      name: 'Lane Club',
      description: 'Board + Chat fixture',
      adminUserIds: const ['club-account'],
      boardMemberIds: const ['board-member'],
    );
    clubs.add(other);
    addTearDown(() => clubs.remove(other));

    final threadId = ChatStore.clubThreadId(other.id);
    userState.followedClubIds.add(other.id);
    const reader = 'lane-reader';

    store.sendMessage(
      threadId: threadId,
      senderId: 'board-member',
      content: 'Bring your own goggles.',
      kind: ChatMessageKind.announcement,
      title: 'Build sprint starts Monday',
    );
    store.sendMessage(
      threadId: threadId,
      senderId: 'board-member',
      content: 'servo order arrived',
    );
    store.sendMessage(
      threadId: threadId,
      senderId: 'board-member',
      content: 'unboxing in B-14 now',
    );

    expect(
      store.unreadInClubLane(threadId, reader, ClubChatLane.board),
      1,
    );
    expect(store.unreadInClubLane(threadId, reader, ClubChatLane.chat), 2);
    // The inbox row shows the sum of the two segments.
    expect(store.unreadCountFor(threadId, reader), 3);

    // Reading the Board leaves what is waiting in Chat exactly where it was.
    store.markClubLaneRead(threadId, reader, ClubChatLane.board);
    expect(
      store.unreadInClubLane(threadId, reader, ClubChatLane.board),
      0,
    );
    expect(store.unreadInClubLane(threadId, reader, ClubChatLane.chat), 2);
    expect(store.unreadCountFor(threadId, reader), 2);

    store.markClubLaneRead(threadId, reader, ClubChatLane.chat);
    expect(store.unreadCountFor(threadId, reader), 0);

    // The Messages row previews Chat, never the Board's own object.
    expect(
      store.lastChatLaneMessageIn(threadId)?.content,
      'unboxing in B-14 now',
    );

    // Lane receipts survive a restart the same way thread receipts do.
    await store.saveAll();
    final reopened = ChatStore();
    await reopened.initialize();
    expect(reopened.unreadCountFor(threadId, reader), 0);
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
