import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/chats_screen.dart';
import 'package:flutter_application_1/screens/club_community_screen.dart';
import 'package:flutter_application_1/screens/club_members_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_group_prefs.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/chats_design.dart';
import 'package:flutter_application_1/widgets/club_chat_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers CLUB CHATS INSIDE (Figma section `483:31`): the Clubs-tab states
/// (`140:3`, `140:94`, `141:3`), the club room's Board and Chats lanes
/// (`143:188`, `143:3`), the lane menu (`219:6`), the two sheets (`146:3`,
/// `146:298`) and the Members screen (`142:231`).
void main() {
  late Directory tempDir;
  late String myId;
  const clubId = 'club-design-club';

  const cast = [
    ('club-design-sarah', 'Sarah Chen'),
    ('club-design-marcus', 'Marcus Rivera'),
  ];

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_chats_design_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  var session = 0;

  setUp(() {
    // A fresh address per test: signUp rejects a repeat, and
    // `authService.logout()` hangs in a plain widget test.
    session++;
    expect(
      authService.signUp(
        'Club Design Reader',
        'club.design.reader.$session@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    myId = authService.currentUser!.id;
    for (final person in cast) {
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
        adminUserIds: const ['club-design-sarah'],
        boardMemberIds: ['club-design-marcus', myId],
        boardMemberTitles: {'club-design-marcus': 'Secretary', myId: 'Member'},
      ),
    );
    userState.followedClubIds.add(clubId);
  });

  tearDown(() {
    userState.followedClubIds.remove(clubId);
    clubs.removeWhere((club) => club.id == clubId);
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(420, 2600);
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

  /// `chatStore` persists across the tests in this file, so every notice needs
  /// its own body — otherwise `find.text` matches an earlier test's card too.
  String seedNotice(String body) {
    final sent = chatStore.sendMessage(
      threadId: ChatStore.clubThreadId(clubId),
      senderId: 'club-design-marcus',
      content: '$body #$session',
      kind: ChatMessageKind.announcement,
      title: '',
    );
    return sent!.id;
  }

  // ── the club room ─────────────────────────────────────────────────────────

  testWidgets('the room header carries the lane pill, not a segmented switch', (
    tester,
  ) async {
    seedNotice('Thursday rooftop session is confirmed.');
    await pumpApp(
      tester,
      ClubCommunityScreen(threadId: ChatStore.clubThreadId(clubId)),
    );

    expect(find.byKey(const ValueKey('club-lane-pill')), findsOneWidget);
    expect(find.text('Rooftop Collective'), findsOneWidget);
    expect(find.text(S.clubLaneBoard), findsOneWidget);
    // The old chrome: a three-up lane switch below the header. Its Board
    // segment shares a label with the new pill in Turkish, so the Solo Chat
    // segment is the one that proves it is gone.
    expect(find.text(S.clubSoloChatTab), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the lane menu offers Board, Chats and Direct', (tester) async {
    seedNotice('Thursday rooftop session is confirmed.');
    await pumpApp(
      tester,
      MediaQuery(
        data: const MediaQueryData(viewPadding: EdgeInsets.only(top: 47)),
        child: ClubCommunityScreen(threadId: ChatStore.clubThreadId(clubId)),
      ),
    );

    final pill = find.byKey(const ValueKey('club-lane-pill'));
    final pillRect = tester.getRect(pill);
    await tester.tap(pill);
    await tester.pumpAndSettle();

    final menuRect = tester.getRect(
      find.byKey(const ValueKey('club-lane-menu-card')),
    );
    expect(menuRect.top, closeTo(pillRect.bottom + 6, 0.5));
    expect(menuRect.right, closeTo(pillRect.right, 0.5));

    for (final lane in ClubRoomLane.values) {
      expect(
        find.byKey(ValueKey('club-lane-option-${lane.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();
    expect(find.text(S.clubLaneChats), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('Direct lists a regular member conversation like Friends', (
    tester,
  ) async {
    final club = clubs.firstWhere((club) => club.id == clubId);
    club.boardMemberIds.remove(myId);
    club.boardMemberTitles.remove(myId);
    final inbox = ClubInboxConversation(
      id: 'club-design-member-inbox-$session',
      clubId: clubId,
      profileId: myId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    chatStore.debugCacheClubInboxConversation(inbox);
    expect(
      chatStore.sendMessage(
        threadId: inbox.threadId,
        senderId: myId,
        content: 'Could you share the meeting time?',
      ),
      isNotNull,
    );

    await pumpApp(
      tester,
      ClubCommunityScreen(threadId: ChatStore.clubThreadId(clubId)),
    );
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-direct')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-direct-chat-list')), findsOneWidget);
    final row = find.byKey(ValueKey('club-solo-chat-row-${inbox.threadId}'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, 72);
    await tester.tap(row);
    await tester.pumpAndSettle();

    final thread = tester.widget<ChatThreadScreen>(
      find.byType(ChatThreadScreen),
    );
    expect(thread.threadId, inbox.threadId);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('board members can answer students from the Direct list', (
    tester,
  ) async {
    const studentId = 'club-design-questioner';
    peopleService.cacheRegisteredUser(
      User(
        id: studentId,
        name: 'Taylor Questioner',
        email: 'taylor.questioner@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: [],
      ),
    );
    final inbox = ClubInboxConversation(
      id: 'club-design-board-inbox-$session',
      clubId: clubId,
      profileId: studentId,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    chatStore.debugCacheClubInboxConversation(inbox);
    expect(
      chatStore.sendMessage(
        threadId: inbox.threadId,
        senderId: studentId,
        content: 'Can non-members attend the workshop?',
      ),
      isNotNull,
    );

    await pumpApp(
      tester,
      ClubCommunityScreen(threadId: ChatStore.clubThreadId(clubId)),
    );
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-direct')));
    await tester.pumpAndSettle();

    expect(find.text('Taylor Questioner'), findsOneWidget);
    await tester.tap(find.text('Taylor Questioner'));
    await tester.pumpAndSettle();
    expect(chatStore.canWriteThread(inbox.threadId, myId), isTrue);
    // An empty pill parks the camera in the trailing slot; the send button
    // only takes over once a draft exists.
    expect(find.byKey(const ValueKey('chat-camera-button')), findsOneWidget);

    await tester.enterText(
      find.byType(TextField),
      'Yes, registration is open.',
    );
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Yes, registration is open.',
    );
    expect(
      tester
          .widget<GestureDetector>(
            find.byKey(const ValueKey('chat-send-button')),
          )
          .onTap,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );

    final reply = chatStore
        .messagesFor(inbox.threadId, viewerId: myId)
        .where((message) => message.content == 'Yes, registration is open.')
        .single;
    expect(reply.senderAuthId, myId);
    expect(reply.senderClubId, clubId);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a Board notice renders as a card with its reply count', (
    tester,
  ) async {
    final noticeId = seedNotice('Thursday rooftop session is confirmed.');
    chatStore.toggleReaction(
      messageId: noticeId,
      userId: 'club-design-sarah',
      emoji: '🎉',
    );
    // Only board members may write this club's Chat lane, so the reply comes
    // from Marcus rather than the admin id.
    expect(
      chatStore.sendMessage(
        threadId: ChatStore.clubThreadId(clubId),
        senderId: 'club-design-marcus',
        content: 'Noted! #$session',
        replyToMessageId: noticeId,
      ),
      isNotNull,
    );

    await pumpApp(
      tester,
      ClubCommunityScreen(threadId: ChatStore.clubThreadId(clubId)),
    );

    expect(find.byKey(ValueKey('club-notice-card-$noticeId')), findsOneWidget);
    expect(
      find.text('Thursday rooftop session is confirmed. #$session'),
      findsOneWidget,
    );
    // `143:236` prints a count beside every emoji, and `143:240` the replies.
    // The chip draws them as two spans, so match the chip and its count.
    final chip = find.byKey(const ValueKey('club-reaction-🎉'));
    expect(chip, findsOneWidget);
    expect(find.descendant(of: chip, matching: find.text('1')), findsOneWidget);
    expect(find.text(S.clubReplyCount(1)), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Chats lane draws sender names, a pin strip and a receipt', (
    tester,
  ) async {
    final threadId = ChatStore.clubThreadId(clubId);
    final incoming = chatStore.sendMessage(
      threadId: threadId,
      senderId: 'club-design-marcus',
      content: 'Who is bringing speakers?',
    )!;
    chatStore.setPinned(incoming.id, true);
    final mine = chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'I will handle the playlist.',
    )!;

    await pumpApp(tester, ClubCommunityScreen(threadId: threadId));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-pinned-strip')), findsOneWidget);
    // Earlier tests in this file left their own messages in the same thread,
    // so the name appears once per bubble Marcus sent.
    expect(find.text('Marcus Rivera'), findsWidgets);
    final incomingBubble = tester.widget<ChatBubbleShell>(
      find.byKey(ValueKey('club-message-bubble-${incoming.id}')),
    );
    expect(incomingBubble.mine, isFalse);
    final mineBubble = tester.widget<ChatBubbleShell>(
      find.byKey(ValueKey('club-message-bubble-${mine.id}')),
    );
    expect(mineBubble.mine, isTrue);
    // A board member may write, so the frame's composer is there.
    expect(find.byKey(const ValueKey('chat-attach-button')), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long-pressing a club message opens the actions sheet', (
    tester,
  ) async {
    final threadId = ChatStore.clubThreadId(clubId);
    final message = chatStore.sendMessage(
      threadId: threadId,
      senderId: 'club-design-marcus',
      content: 'Who is bringing speakers?',
    )!;
    addTearDown(() => chatGroupPrefs.setMessageSaved(message.id, false));

    await pumpApp(tester, ClubCommunityScreen(threadId: threadId));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    await tester.longPress(find.byKey(ValueKey('club-message-${message.id}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('club-message-actions-sheet')),
      findsOneWidget,
    );
    expect(find.text(S.clubSaveMessage), findsOneWidget);
    expect(find.text(S.clubReportMessage), findsOneWidget);
    // Edit Message and Forward are on the frame but have nowhere to go.
    expect(find.text('Edit Message'), findsNothing);

    await tester.tap(find.byKey(ValueKey('club-save-message-${message.id}')));
    await tester.pumpAndSettle();
    expect(chatGroupPrefs.isMessageSaved(message.id), isTrue);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the share sheet names the club and its audience', (
    tester,
  ) async {
    final threadId = ChatStore.clubThreadId(clubId);
    chatStore.sendMessage(
      threadId: threadId,
      senderId: 'club-design-marcus',
      content: 'Who is bringing speakers?',
    );

    await pumpApp(tester, ClubCommunityScreen(threadId: threadId));
    await tester.tap(find.byKey(const ValueKey('club-lane-pill')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('club-lane-option-chats')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('chat-attach-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('club-share-sheet')), findsOneWidget);
    expect(find.text(S.clubShareToTitle('Rooftop Collective')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-share-photo')), findsOneWidget);
    expect(find.byKey(const ValueKey('club-share-poll')), findsOneWidget);
    // File / Event / Location have nowhere to go in this app.
    expect(find.byKey(const ValueKey('club-share-file')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  // ── Members ───────────────────────────────────────────────────────────────

  testWidgets('members group into Admins, Moderators and Members', (
    tester,
  ) async {
    await pumpApp(
      tester,
      ClubMembersScreen(
        club: clubs.firstWhere((club) => club.id == clubId),
        myId: myId,
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text(S.clubSectionAdmins.toUpperCase()), findsOneWidget);
    expect(find.text(S.clubSectionModerators.toUpperCase()), findsOneWidget);
    expect(find.text(S.clubCreatedTheClub), findsOneWidget);
    expect(find.text(S.clubRoleMod), findsWidgets);
    expect(find.text(S.clubRoleYou), findsOneWidget);
    // The frame's activity lines and Invite control have no data behind them.
    expect(find.textContaining('Active '), findsNothing);
    expect(find.textContaining('Joined '), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  // ── Clubs-tab states ──────────────────────────────────────────────────────

  testWidgets('the Clubs tab search gets its own results layout', (
    tester,
  ) async {
    chatStore.sendMessage(
      threadId: ChatStore.clubThreadId(clubId),
      senderId: 'club-design-marcus',
      content: 'Who is bringing speakers?',
    );
    await pumpApp(tester, const ChatsScreen());
    await tester.tap(find.byKey(const ValueKey('chats-filter-dropdown')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chats-filter-option-clubs')));
    await tester.pump();

    await tester.enterText(
      find.byKey(const ValueKey('chat-search-clubs')),
      'rooftop',
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('club-search-cancel')), findsOneWidget);
    expect(find.text(S.clubSearchSectionLabel.toUpperCase()), findsOneWidget);
    expect(
      find.byKey(
        ValueKey('club-search-result-${ChatStore.clubThreadId(clubId)}'),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('club-search-cancel')));
    await tester.pump();
    expect(find.byKey(const ValueKey('club-search-cancel')), findsNothing);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty Clubs tab offers the two routes out of it', (
    tester,
  ) async {
    userState.followedClubIds.remove(clubId);
    final tapped = <int>[];
    await pumpApp(tester, ChatsScreen(onSelectTab: tapped.add));
    await tester.tap(find.byKey(const ValueKey('chats-filter-dropdown')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chats-filter-option-clubs')));
    await tester.pump();

    expect(find.text(S.clubChatsEmptyTitle), findsOneWidget);
    expect(find.text(S.clubChatsFriendsHint), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('club-chats-explore-clubs')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('club-chats-browse-events')));
    await tester.pump();
    // Search is tab 2 and This Week is tab 1 in the main navigation.
    expect(tapped, [2, 1]);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  test('club lane labels and icons stay in step', () {
    expect(clubLaneLabel(ClubRoomLane.board), S.clubLaneBoard);
    expect(clubLaneLabel(ClubRoomLane.chats), S.clubLaneChats);
    expect(clubLaneLabel(ClubRoomLane.direct), S.clubLaneDirect);
    expect(clubLaneIcon(ClubRoomLane.direct), Icons.lock_outline_rounded);
  });
}
