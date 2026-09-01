import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/chats_screen.dart';
import 'package:flutter_application_1/screens/club_community_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/widgets/club_chat_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers CLUB CHATS (Figma section label `543:32`) — the club's own side of a
/// room the student pass already redesigned:
///
/// * `admin-chats-list` `331:136` / `331:235` — the Board lane, whose composer
///   the student frame draws only as a locked strip.
/// * `admin-board-chat` `331:10` / `331:73` — the Chats lane.
/// * `admin-dm-list` `335:6` / `335:127` — the Direct lane as an inbox.
/// * `admin-direct-messages` `335:255` / `331:438` — one private thread.
/// * `club-detail-dropdown` `329:1156` / `329:1254` — the lane menu.
void main() {
  late Directory tempDir;
  const clubId = 'club-admin-design-club';
  const students = [
    ('club-admin-design-sarah', 'Sarah Chen'),
    ('club-admin-design-jordan', 'Jordan Miller'),
  ];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_chats_admin_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  var session = 0;

  setUp(() {
    session++;
    for (final person in students) {
      peopleService.cacheRegisteredUser(
        User(
          id: person.$1,
          name: person.$2,
          email: '${person.$1}@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [clubId],
        ),
      );
    }
    clubs.removeWhere((club) => club.id == clubId);
    clubs.add(
      Club(
        id: clubId,
        name: 'Rooftop Collective',
        description: 'Sunset sessions and rooftop dinners.',
        adminUserIds: const [clubId],
      ),
    );
    // A dedicated club login: the admin id *is* the club id, which is how
    // `managedClubForAdmin` and `managedCommunityThreadId` tie the session to
    // one room.
    authService.setClubAdmin(
      AppAdmin(
        id: clubId,
        name: 'Rooftop Collective',
        email: 'rooftop@ku.edu.tr',
        password: '',
      ),
    );
  });

  tearDown(() {
    clubs.removeWhere((club) => club.id == clubId);
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2400);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: home,
        ),
      ),
    );
    await tester.pump();
  }

  ChatThreadScreen room() => ChatThreadScreen(
    key: ValueKey('club-admin-room-$session'),
    threadId: ChatStore.clubThreadId(clubId),
    embedded: true,
  );

  ClubInboxConversation seedInbox(String profileId, String body) {
    final inbox = ClubInboxConversation(
      id: 'club-admin-inbox-$profileId-$session',
      clubId: clubId,
      profileId: profileId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    chatStore.debugCacheClubInboxConversation(inbox);
    expect(
      chatStore.sendMessage(
        threadId: inbox.threadId,
        senderId: profileId,
        content: body,
      ),
      isNotNull,
    );
    return inbox;
  }

  Future<void> openDirect(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-direct')));
    await tester.pumpAndSettle();
  }

  testWidgets('the club Chats tab opens the redesigned room, not the old one', (
    tester,
  ) async {
    await pumpApp(tester, const ChatsScreen());
    await tester.pump(const Duration(seconds: 1));

    expect(find.byType(ClubCommunityScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('club-lane-pill')), findsOneWidget);
    expect(find.text('Rooftop Collective'), findsWidgets);
    // The old chrome's segmented lane switch. `S.clubBoardTab` and
    // `S.clubLaneBoard` are both "Pano" in Turkish, so the third segment is
    // the one that can tell the two apart.
    expect(find.text(S.clubSoloChatTab), findsNothing);
    // A root tab has nowhere to go back to.
    expect(find.byKey(const ValueKey('club-room-back')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Board lane composer publishes a notice inline', (
    tester,
  ) async {
    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));

    final composer = find.byKey(const ValueKey('club-design-notice-composer'));
    expect(composer, findsOneWidget);
    expect(
      find.descendant(of: composer, matching: find.byType(TextField)),
      findsOneWidget,
    );
    // The primary button the student pass invented for this footer is gone.
    expect(find.text(S.boardPostNotice), findsNothing);
    expect(find.byKey(const ValueKey('club-board-locked-strip')), findsNothing);

    final body = 'Doors open at 7 PM on Thursday #$session';
    await tester.enterText(
      find.descendant(of: composer, matching: find.byType(TextField)),
      body,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump(const Duration(seconds: 1));

    // One card, drawn body-only: an inline notice has no headline of its own.
    expect(find.text(body), findsOneWidget);
    expect(find.byType(ClubNoticeCard), findsWidgets);
  });

  testWidgets('announcement attachments offer media and camera', (
    tester,
  ) async {
    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('chat-attach-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-share-sheet')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-announcement-share-media')),
      findsOneWidget,
    );
    expect(find.text(S.attachMedia), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-announcement-share-camera')),
      findsOneWidget,
    );
    expect(find.text(S.takePhoto), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-announcement-details')),
      findsOneWidget,
    );

    Navigator.of(
      tester.element(find.byKey(const ValueKey('club-share-sheet'))),
    ).pop();
    await tester.pumpAndSettle();

    final notice = chatStore.sendMessage(
      threadId: ChatStore.clubThreadId(clubId),
      senderId: clubId,
      content: 'Photo announcement',
      kind: ChatMessageKind.announcement,
      attachmentPath: '/tmp/club-announcement.jpg',
      attachmentName: 'club-announcement.jpg',
      attachmentSize: 128,
    );
    expect(notice, isNotNull);
    await tester.pump();

    expect(
      find.byKey(ValueKey('club-notice-attachment-${notice!.id}')),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('club chat attachments offer library media and camera', (
    tester,
  ) async {
    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-attach-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-share-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-share-photo')), findsOneWidget);
    expect(find.text(S.attachMedia), findsOneWidget);
    expect(find.byKey(const ValueKey('club-share-camera')), findsOneWidget);
    expect(find.text(S.takePhoto), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the single pinned chat banner jumps to its original message', (
    tester,
  ) async {
    final threadId = ChatStore.clubThreadId(clubId);
    final target = chatStore.sendMessage(
      threadId: threadId,
      senderId: clubId,
      content: 'Pinned message target #$session',
    )!;
    for (var index = 0; index < 45; index++) {
      chatStore.sendMessage(
        threadId: threadId,
        senderId: clubId,
        content: 'Later message $index #$session',
      );
    }
    final replacement = chatStore.sendMessage(
      threadId: threadId,
      senderId: clubId,
      content: 'Temporary pinned message #$session',
    )!;
    expect(chatStore.setPinned(target.id, true), isTrue);
    expect(chatStore.setPinned(replacement.id, true), isTrue);
    expect(chatStore.messageById(target.id)!.pinned, isFalse);
    expect(chatStore.pinnedMessageIn(threadId)?.id, replacement.id);
    expect(chatStore.setPinned(target.id, true), isTrue);
    expect(chatStore.messageById(replacement.id)!.pinned, isFalse);
    expect(chatStore.pinnedMessageIn(threadId)?.id, target.id);

    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    final pinnedStrip = find.byKey(const ValueKey('club-pinned-strip'));
    final chatHistory = find.byKey(const ValueKey('club-chat-history-stack'));
    expect(pinnedStrip, findsOneWidget);
    expect(
      find.descendant(of: chatHistory, matching: pinnedStrip),
      findsOneWidget,
    );
    await tester.tap(pinnedStrip);
    await tester.pumpAndSettle();

    final flash = find.byKey(ValueKey('club-pinned-flash-${target.id}'));
    expect(flash, findsOneWidget);
    final activeFlash = tester.widget<AnimatedContainer>(flash);
    final activeDecoration = activeFlash.foregroundDecoration! as BoxDecoration;
    expect(activeDecoration.color, isNot(Colors.transparent));

    final targetBubble = find.byKey(
      ValueKey('club-message-bubble-${target.id}'),
    );
    expect(targetBubble, findsOneWidget);
    final targetTop = tester.getTopLeft(targetBubble).dy;
    expect(targetTop, greaterThanOrEqualTo(0));
    expect(targetTop, lessThan(tester.view.physicalSize.height));
    await tester.pump(const Duration(seconds: 1));
    final restingFlash = tester.widget<AnimatedContainer>(flash);
    final restingDecoration =
        restingFlash.foregroundDecoration! as BoxDecoration;
    expect(restingDecoration.color, Colors.transparent);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('a pinned announcement replaces the previous chat pin', (
    tester,
  ) async {
    final threadId = ChatStore.clubThreadId(clubId);
    final previous = chatStore.sendMessage(
      threadId: threadId,
      senderId: clubId,
      content: 'Previously pinned chat message #$session',
      pinned: true,
    )!;
    final notice = chatStore.sendMessage(
      threadId: threadId,
      senderId: clubId,
      content: 'Pinned Board announcement #$session',
      kind: ChatMessageKind.announcement,
      title: 'Pinned announcement',
      pinned: true,
    )!;
    final pinnedItems = chatStore
        .messagesFor(threadId)
        .where((message) => message.pinned)
        .toList();
    expect(chatStore.messageById(previous.id)!.pinned, isFalse);
    expect(pinnedItems, hasLength(1));
    expect(pinnedItems.single.id, notice.id);

    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-pinned-strip')), findsOneWidget);
    final chatAnnouncement = find.byKey(
      ValueKey('club-chat-announcement-${notice.id}'),
    );
    expect(chatAnnouncement, findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('club-pinned-strip')));
    await tester.pumpAndSettle();

    expect(chatAnnouncement, findsOneWidget);
    expect(find.text(S.clubLaneChats), findsOneWidget);
    expect(chatStore.pinnedMessageIn(threadId)?.id, notice.id);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Direct is an inbox with a title, a search field and rows', (
    tester,
  ) async {
    final sarah = seedInbox(
      students[0].$1,
      'We finalized the schedule #$session',
    );
    final jordan = seedInbox(
      students[1].$1,
      'Can you double check the RSVP list #$session',
    );

    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));
    await openDirect(tester);

    expect(find.text(S.clubDirectInboxTitle), findsOneWidget);
    // The club identity belongs to the other two lanes.
    expect(find.text(S.clubMembersAndUnread(0, 0)), findsNothing);
    final search = find.byKey(const ValueKey('club-direct-search-field'));
    expect(search, findsOneWidget);

    // 335:73 draws the message alone — the row is already named after the
    // student — while the club's own last word keeps its "You:" prefix.
    expect(find.textContaining('Jordan Miller:'), findsNothing);
    expect(
      find.text('Can you double check the RSVP list #$session'),
      findsOneWidget,
    );

    final sarahRow = find.byKey(
      ValueKey('club-direct-inbox-row-${sarah.threadId}'),
    );
    final jordanRow = find.byKey(
      ValueKey('club-direct-inbox-row-${jordan.threadId}'),
    );
    expect(sarahRow, findsOneWidget);
    expect(jordanRow, findsOneWidget);
    // 48pt avatar + 12pt above and below.
    expect(tester.getSize(sarahRow).height, 72);

    await tester.enterText(search, 'Jordan');
    await tester.pumpAndSettle();
    expect(sarahRow, findsNothing);
    expect(jordanRow, findsOneWidget);

    await tester.enterText(search, 'nobody at all');
    await tester.pumpAndSettle();
    expect(find.text(S.clubDirectNoMatches), findsOneWidget);

    // The chevron beside "Messages" goes back to the lane it was opened from.
    await tester.tap(find.byKey(const ValueKey('club-direct-inbox-back')));
    await tester.pumpAndSettle();
    expect(find.text(S.clubDirectInboxTitle), findsNothing);
    expect(find.byKey(const ValueKey('club-lane-pill')), findsOneWidget);
  });

  testWidgets('the club side of a private thread draws the design chrome', (
    tester,
  ) async {
    final inbox = seedInbox(
      students[0].$1,
      'Is the rooftop session open to non-members #$session',
    );

    await pumpApp(
      tester,
      ChatThreadScreen(
        key: ValueKey('club-admin-inbox-$session'),
        threadId: inbox.threadId,
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('club-inbox-lane-badge')), findsOneWidget);
    expect(find.text(S.chatsDmWithAdmins), findsOneWidget);
    expect(find.text('Sarah Chen'), findsWidgets);
    // The empty composer parks the camera in the trailing slot.
    expect(find.byKey(const ValueKey('chat-camera-button')), findsOneWidget);
    expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-attach-button')));
    await tester.pumpAndSettle();

    // Library media only — a live capture is the composer camera's job.
    expect(find.byKey(const ValueKey('chat-attach-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-attach-photo')), findsOneWidget);
    expect(find.text(S.attachMedia), findsOneWidget);
    expect(find.byKey(const ValueKey('chat-attach-camera')), findsNothing);
    expect(find.text(S.takePhoto), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a poll sent into the Chats lane renders and takes a vote', (
    tester,
  ) async {
    final question = 'Which activity should be next #$session';
    final poll = chatStore.sendMessage(
      threadId: ChatStore.clubThreadId(clubId),
      senderId: clubId,
      content: '',
      kind: ChatMessageKind.poll,
      title: question,
      pollOptions: const ['Workshop', 'Social'],
    );
    expect(poll, isNotNull);

    await pumpApp(tester, room());
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    // Before CLUB CHATS put the club account on this lane, a poll rendered as
    // an empty bubble here: the lane only drew `message.content`.
    final bubble = find.byKey(ValueKey('club-bubble-poll-${poll!.id}'));
    expect(bubble, findsOneWidget);
    expect(find.text(question), findsOneWidget);
    expect(find.text('Workshop'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: bubble,
        matching: find.byKey(const ValueKey('club-bubble-poll-option-1')),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    final stored = chatStore
        .messagesFor(ChatStore.clubThreadId(clubId), viewerId: clubId)
        .firstWhere((message) => message.id == poll.id);
    expect(stored.votesForOption(1), 1);
  });
}
