import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/add_members_screen.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/chats_screen.dart';
import 'package:flutter_application_1/screens/edit_group_info_screen.dart';
import 'package:flutter_application_1/screens/group_info_screen.dart';
import 'package:flutter_application_1/screens/shared_media_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_group_prefs.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/club_chat_prefs.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/widgets/chats_design.dart';
import 'package:flutter_application_1/widgets/sent_message_entrance.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// Covers the CHATS area of the ClubUp-Desings handoff: the inbox
/// (`chats-light` 243:462), the DM and group threads (`102:7` / `102:123`),
/// in-thread search (`search-results` 110:84) and the group-management screens
/// (`group-info` 104:6 and the sheets it opens).
void main() {
  late Directory tempDir;
  late String myId;

  const peer = ('chats-design-peer', 'Sarah Chen');
  const second = ('chats-design-second', 'Marcus Rivera');
  const third = ('chats-design-third', 'Jake Thompson');

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chats_design_');
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
    // `users` is empty at runtime, so signUp is the only way to get a student
    // session in a widget test. Each test signs up a fresh address: signUp
    // rejects an address it has already seen, and `authService.logout()` hangs
    // forever in a plain widget test.
    session++;
    expect(
      authService.signUp(
        'Chats Design Reader',
        'chats.design.reader.$session@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    myId = authService.currentUser!.id;
    for (final person in [peer, second, third]) {
      peopleService.cacheRegisteredUser(
        User(
          id: person.$1,
          name: person.$2,
          email: '${person.$1}@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    }
  });

  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    // A tall viewport, so a card at the bottom of `group-info` or the Save
    // button at the bottom of `edit-group-info` is built rather than left
    // off-stage, and so the people pickers show every fixture row.
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

  // ── tokens ────────────────────────────────────────────────────────────────

  test('chat tokens match the values sampled from the frames', () {
    // Light is shared with the rest of the handoff; the dark ramp is this
    // area's own — #121212 page / #1A1A1A card / #2D2D2D fill and hairline.
    expect(ChatsColors.background, const Color(0xFFFAF9F6));
    expect(ChatsColors.card, const Color(0xFFFFFFFF));
    expect(ChatsColors.fill, const Color(0xFFEFEEEF));
    expect(ChatsColors.border, const Color(0xFFE4E4E7));
    expect(ChatsColors.text, const Color(0xFF18181B));
    expect(ChatsColors.muted, const Color(0xFF71717A));
    expect(ChatsColors.accent, const Color(0xFF800020));
    expect(ChatsColors.unreadRow, const Color(0xFFF8F4F2));
    expect(ChatsColors.danger, const Color(0xFFDC2626));
    expect(kChatBubbleRadius, 16);
  });

  test('speaker colors are stable per user', () {
    expect(chatSenderAccent(peer.$1), chatSenderAccent(peer.$1));
    expect(chatSenderAccent(''), ChatsColors.muted);
  });

  // ── inbox ─────────────────────────────────────────────────────────────────

  testWidgets('inbox header carries the dropdown, not a segmented control', (
    tester,
  ) async {
    await pumpApp(tester, const ChatsScreen());

    final dropdown = find.byKey(const ValueKey('chats-filter-dropdown'));
    final compose = find.byKey(const ValueKey('chats-compose-button'));
    expect(find.byKey(const ValueKey('chats-student-header')), findsOneWidget);
    final filterLabel = tester.widget<Text>(
      find.descendant(of: dropdown, matching: find.text(S.chatsTabFriends)),
    );
    final pen = tester.widget<Icon>(
      find.descendant(of: compose, matching: find.byIcon(Icons.edit_rounded)),
    );
    expect(find.text(S.chats), findsNothing);
    expect(dropdown, findsOneWidget);
    expect(compose, findsOneWidget);
    expect(find.text(S.chatsTabFriends), findsOneWidget);
    expect(find.text(S.searchConversations), findsOneWidget);
    // The title is intentionally omitted: the switcher owns the left side,
    // while the pen uses a 44pt target placed 8pt from the right edge.
    expect(tester.getRect(dropdown).left, 20);
    expect(tester.getRect(compose).right, 412);
    expect(tester.getSize(compose), const Size(44, 44));
    expect(
      tester.widget<Scaffold>(find.byType(Scaffold).first).backgroundColor,
      ChatsColors.background,
    );
    expect(filterLabel.style?.color, ChatsColors.text);
    expect(filterLabel.style?.fontSize, 18);
    expect(filterLabel.style?.fontWeight, FontWeight.w800);
    expect(pen.color, ChatsColors.text);
    expect(pen.size, 26);
    // The old chrome: a two-up filter with a sliding indicator, and a
    // hand-painted campus backdrop behind the list.
    expect(find.byKey(const ValueKey('chat-filter-students')), findsNothing);
    expect(
      find.byKey(const ValueKey('chat-filter-liquid-indicator')),
      findsNothing,
    );
    expect(find.byType(CustomPaint), findsWidgets); // icons only, no backdrop
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dropdown switches to Clubs and closes on the scrim', (
    tester,
  ) async {
    await pumpApp(tester, const ChatsScreen());

    await tester.tap(find.byKey(const ValueKey('chats-filter-dropdown')));
    await tester.pump();
    final menu = find.byKey(const ValueKey('chats-filter-menu-card'));
    final menuTransition = tester.widget<AnimatedSwitcher>(
      find.byKey(const ValueKey('chats-filter-menu-transition')),
    );
    expect(menuTransition.duration, const Duration(milliseconds: 460));
    final startTop = tester.getTopLeft(menu).dy;
    await tester.pump(const Duration(milliseconds: 120));
    final middleTop = tester.getTopLeft(menu).dy;
    await tester.pumpAndSettle();
    final settledTop = tester.getTopLeft(menu).dy;
    expect(startTop, lessThan(middleTop));
    expect(middleTop, lessThan(settledTop));
    expect(
      find.byKey(const ValueKey('chats-filter-dropdown-scrim')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('chats-filter-option-clubs')));
    await tester.pumpAndSettle();
    expect(find.text(S.chatsTabClubs), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chats-filter-dropdown-scrim')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('chats-filter-dropdown')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chats-filter-dropdown-scrim')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('chats-filter-option-clubs')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('an inbox row is 72pt tall and tints only when unread', (
    tester,
  ) async {
    final threadId = chatStore.ensureDirectThread(myId, peer.$1)!;
    chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'Thanks for sharing those color palette refs',
    );
    await pumpApp(tester, const ChatsScreen());

    final row = find.byKey(ValueKey('chat-thread-row-$threadId'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, 72);
    expect(
      find.byKey(ValueKey('chat-thread-unread-$threadId')),
      findsOneWidget,
    );
    final unreadMaterial = tester.widget<Material>(
      find.ancestor(of: row, matching: find.byType(Material)).first,
    );
    expect(unreadMaterial.color, ChatsColors.unreadRow);
    // Badge-clearing on open is covered by chats_unread_badges_test; reading
    // the thread here would start the read-receipt writes, which never settle
    // under `runAsync` in a plain widget test.
    // Let the store's debounced save run before the fixture tears down.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a search hit pulses once, then settles back to the plain row', (
    tester,
  ) async {
    // Not in the handoff — the frames are static. This is the Instagram
    // behaviour the inbox was missing: the row a query lands on lights up for
    // a beat so the eye can find it, then goes quiet again.
    final threadId = chatStore.ensureDirectThread(myId, peer.$1)!;
    chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'Sending the palette refs over now',
    );
    await pumpApp(tester, const ChatsScreen());

    final row = find.byKey(ValueKey('chat-thread-row-$threadId'));
    Color? rowColor() => tester
        .widget<Material>(
          find.ancestor(of: row, matching: find.byType(Material)).first,
        )
        .color;

    // A read row with no query is untouched: the pulse never runs.
    expect(rowColor(), Colors.transparent);

    await tester.enterText(
      find.byKey(const ValueKey('chat-search-students')),
      'Sarah',
    );
    // The pulse starts during this rebuild, and a ticker's first tick always
    // reports zero elapsed — so the wash only shows from the frame after.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    final lit = rowColor()!;
    expect(row, findsOneWidget);
    expect(lit, isNot(Colors.transparent));
    // Blended into the page rather than laid over the row, so the ink splash
    // and the text still sit on top of it.
    expect(lit.a, 1.0);
    expect(lit, isNot(ChatsColors.background));

    await tester.pump(const Duration(milliseconds: 900));
    expect(rowColor(), Colors.transparent);

    // Clearing the field leaves nothing behind either.
    await tester.enterText(
      find.byKey(const ValueKey('chat-search-students')),
      '',
    );
    await tester.pump(const Duration(milliseconds: 200));
    expect(rowColor(), Colors.transparent);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  // ── thread ────────────────────────────────────────────────────────────────

  testWidgets('DM bubbles are flat, and only mine take the accent', (
    tester,
  ) async {
    final threadId = chatStore.ensureDirectThread(myId, peer.$1)!;
    final incoming = chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'Are you still down to study for the mid-term later?',
    )!;
    final outgoing = chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'Yeah definitely!',
    )!;

    await pumpApp(tester, ChatThreadScreen(threadId: threadId));

    for (final (message, mine) in [(incoming, false), (outgoing, true)]) {
      final bubble = tester.widget<ChatBubbleShell>(
        find.byKey(ValueKey('chat-message-bubble-${message.id}')),
      );
      final timestamp = find.byKey(ValueKey('chat-message-time-${message.id}'));
      expect(bubble.mine, mine);
      expect(bubble.showTail, isTrue);
      expect(
        bubble.padding,
        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      );
      expect(timestamp, findsOneWidget);
      expect(
        find.descendant(of: find.byWidget(bubble), matching: timestamp),
        findsOneWidget,
      );
      expect(tester.widget<Container>(timestamp).decoration, isNull);
    }
    // The day divider keeps messages scannable while each bubble now carries
    // its own compact sent time.
    expect(find.byType(ChatDayDivider), findsOneWidget);
    expect(find.text(S.today.toUpperCase()), findsOneWidget);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('only the bottom bubble in a consecutive sender run has a tail', (
    tester,
  ) async {
    final threadId = chatStore.ensureDirectThread(myId, peer.$1)!;
    final firstMine = chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'First outgoing bubble',
    )!;
    final lastMine = chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'Last outgoing bubble',
    )!;
    final firstIncoming = chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'First incoming bubble',
    )!;
    final lastIncoming = chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'Last incoming bubble',
    )!;

    await pumpApp(tester, ChatThreadScreen(threadId: threadId));

    ChatBubbleShell bubbleFor(ChatMessage message) => tester.widget(
      find.byKey(ValueKey('chat-message-bubble-${message.id}')),
    );

    expect(bubbleFor(firstMine).showTail, isFalse);
    expect(bubbleFor(lastMine).showTail, isTrue);
    expect(bubbleFor(firstIncoming).showTail, isFalse);
    expect(bubbleFor(lastIncoming).showTail, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('rapid sends keep both bubble entrances running smoothly', (
    tester,
  ) async {
    final threadId = chatStore.ensureDirectThread(myId, peer.$1)!;
    await pumpApp(tester, ChatThreadScreen(threadId: threadId));

    await tester.enterText(find.byType(TextField), 'First rapid message');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 60));
    final first = chatStore
        .messagesFor(threadId)
        .where((message) => message.content == 'First rapid message')
        .last;

    await tester.enterText(find.byType(TextField), 'Second rapid message');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('chat-send-button')));
    await tester.pump(const Duration(milliseconds: 16));
    final second = chatStore
        .messagesFor(threadId)
        .where((message) => message.content == 'Second rapid message')
        .last;

    SentMessageEntrance entranceFor(ChatMessage message) => tester.widget(
      find.byKey(
        ValueKey('sent-message-entrance-${message.id}'),
        skipOffstage: false,
      ),
    );

    expect(entranceFor(first).animate, isTrue);
    expect(entranceFor(second).animate, isTrue);

    await tester.pumpAndSettle();
    expect(entranceFor(first).animate, isFalse);
    expect(entranceFor(second).animate, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('group messages repeat the sender name and avatar', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;
    final first = chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: "Who's free this weekend?",
    )!;
    final again = chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'We should do a movie night.',
    )!;
    final mine = chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'I can bring popcorn.',
    )!;

    await pumpApp(tester, ChatThreadScreen(threadId: threadId));

    // The frame does not group runs: both consecutive messages from the same
    // speaker keep their own name and avatar.
    for (final message in [first, again]) {
      expect(
        find.byKey(ValueKey('chat-sender-profile-name-${message.id}')),
        findsOneWidget,
      );
      expect(
        find.byKey(ValueKey('group-message-avatar-${message.id}')),
        findsOneWidget,
      );
    }
    // Outgoing messages get neither.
    expect(
      find.byKey(ValueKey('chat-sender-profile-name-${mine.id}')),
      findsNothing,
    );
    expect(
      find.byKey(ValueKey('group-message-avatar-${mine.id}')),
      findsNothing,
    );
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('in-thread search counts matches and steps through them', (
    tester,
  ) async {
    final threadId = chatStore.ensureDirectThread(myId, peer.$1)!;
    chatStore.sendMessage(
      threadId: threadId,
      senderId: peer.$1,
      content: 'Library at 4 PM, do not be late!',
    );
    chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'Meet at the library entrance.',
    );
    chatStore.sendMessage(
      threadId: threadId,
      senderId: myId,
      content: 'Bringing my laptop.',
    );

    await pumpApp(tester, ChatThreadScreen(threadId: threadId));
    await tester.tap(find.byKey(const ValueKey('chat-thread-search-button')));
    await tester.pump();

    // The composer gives way to the field, as on `search-results` 110:95.
    expect(find.byKey(const ValueKey('chat-send-button')), findsNothing);
    await tester.enterText(
      find.byKey(const ValueKey('chat-thread-search-field')),
      'library',
    );
    await tester.pump();

    expect(find.text(S.chatsResultsFound(2)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('chat-thread-search-next')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('chat-thread-search-field')),
      'zzz',
    );
    await tester.pump();
    expect(find.text(S.chatsNoResultsFound), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('chat-thread-search-cancel')));
    await tester.pump();
    // The composer returns with an empty pill, so its trailing slot is the
    // camera rather than the send arrow.
    expect(find.byKey(const ValueKey('chat-camera-button')), findsOneWidget);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  // ── group info and its sheets ─────────────────────────────────────────────

  testWidgets('group info shows the cards, and Mute persists per device', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;
    addTearDown(() => clubChatPrefs.setMuted(threadId, false));

    await pumpApp(tester, GroupInfoScreen(threadId: threadId, myId: myId));

    expect(find.text(S.chatsDescriptionLabel.toUpperCase()), findsOneWidget);
    expect(find.text(S.chatsMembersLabel.toUpperCase()), findsOneWidget);
    expect(find.byKey(const ValueKey('group-info-mute')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-info-media')), findsOneWidget);
    // The creator manages the group, so the frame's Add-member row is there.
    expect(find.byKey(const ValueKey('group-info-add-member')), findsOneWidget);

    expect(clubChatPrefs.isMuted(threadId), isFalse);
    await tester.tap(find.byKey(const ValueKey('group-info-mute')));
    await tester.pump();
    expect(clubChatPrefs.isMuted(threadId), isTrue);
    expect(find.text(S.chatsUnmuteAction), findsOneWidget);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the overflow sheet carries the group-menu rows', (tester) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;
    addTearDown(() => chatGroupPrefs.setFavourite(threadId, false));

    await pumpApp(tester, GroupInfoScreen(threadId: threadId, myId: myId));
    await tester.tap(find.byKey(const ValueKey('group-info-overflow')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('group-menu-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-menu-edit')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-menu-mute')), findsOneWidget);
    expect(find.byKey(const ValueKey('group-menu-report')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-menu-favourite')));
    await tester.pumpAndSettle();
    expect(chatGroupPrefs.isFavourite(threadId), isTrue);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Search quick action asks the thread to open its search', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;
    GroupInfoOutcome? outcome;

    await pumpApp(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async {
            outcome = await Navigator.push<GroupInfoOutcome>(
              context,
              MaterialPageRoute(
                builder: (_) => GroupInfoScreen(threadId: threadId, myId: myId),
              ),
            );
          },
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('group-info-search')));
    await tester.pumpAndSettle();

    expect(outcome, GroupInfoOutcome.search);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing saves the name on the group and the description locally',
    (tester) async {
      final threadId = chatStore.createGroupThread(
        creatorId: myId,
        recipientIds: [peer.$1, second.$1],
      )!;
      addTearDown(() => chatGroupPrefs.setDescription(threadId, ''));

      await pumpApp(
        tester,
        EditGroupInfoScreen(threadId: threadId, myId: myId),
      );

      await tester.enterText(
        find.byKey(const ValueKey('edit-group-name-field')),
        'Study Squad',
      );
      await tester.enterText(
        find.byKey(const ValueKey('edit-group-description-field')),
        'Weekend hangouts and study sessions.',
      );
      await tester.tap(find.byKey(const ValueKey('edit-group-save')));
      await tester.pumpAndSettle();

      expect(chatStore.groupForThread(threadId)?.customName, 'Study Squad');
      expect(
        chatGroupPrefs.descriptionFor(threadId),
        'Weekend hangouts and study sessions.',
      );
      // Let the store's debounced save run on the fake clock rather than
      // `runAsync`, which wedges once read receipts are in flight.
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('member actions offer message, profile and removal', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;

    await pumpApp(tester, EditGroupInfoScreen(threadId: threadId, myId: myId));
    await tester.tap(find.byKey(ValueKey('edit-group-member-${peer.$1}')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(ValueKey('member-actions-sheet-${peer.$1}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('member-action-admin-${peer.$1}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('member-action-message-${peer.$1}')),
      findsOneWidget,
    );
    expect(
      find.byKey(ValueKey('member-action-remove-${peer.$1}')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(ValueKey('member-action-admin-${peer.$1}')));
    await tester.pumpAndSettle();
    expect(chatStore.groupForThread(threadId)?.isAdmin(peer.$1), isTrue);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('add members batches a selection behind Done', (tester) async {
    // createGroupThread needs at least two recipients, so `third` is the one
    // left to add.
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;

    await pumpApp(tester, AddMembersScreen(threadId: threadId, myId: myId));

    final row = find.byKey(ValueKey('add-members-row-${third.$1}'));
    expect(row, findsOneWidget);
    expect(tester.getSize(row).height, 54);
    await tester.tap(row);
    await tester.pump();
    // The picked person becomes a chip, `selected-track` 105:352.
    expect(
      find.byKey(ValueKey('add-members-chip-remove-${third.$1}')),
      findsOneWidget,
    );
    expect(chatStore.groupParticipants(threadId).contains(third.$1), isFalse);

    await tester.tap(find.byKey(const ValueKey('add-members-done')));
    await tester.pumpAndSettle();
    expect(chatStore.groupParticipants(threadId).contains(third.$1), isTrue);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared media tabs fall back to their own empty lines', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: myId,
      recipientIds: [peer.$1, second.$1],
    )!;

    await pumpApp(tester, SharedMediaScreen(threadId: threadId, myId: myId));

    expect(find.text(S.chatsNoSharedMedia), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shared-media-tab-links')));
    await tester.pump();
    expect(find.text(S.chatsNoSharedLinks), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('shared-media-tab-docs')));
    await tester.pump();
    expect(find.text(S.chatsNoSharedDocs), findsOneWidget);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('leaving asks first, in the frame\'s destructive dialog', (
    tester,
  ) async {
    final threadId = chatStore.createGroupThread(
      creatorId: peer.$1,
      recipientIds: [myId, second.$1],
    )!;

    await pumpApp(tester, GroupInfoScreen(threadId: threadId, myId: myId));
    // Not the creator, so the frame's Exit Group row (`104:85`) is the one on
    // offer.
    expect(find.byKey(const ValueKey('leave-group-button')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('leave-group-button')));
    await tester.pumpAndSettle();

    expect(find.text(S.chatsLeaveGroupQuestion), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('confirm-leave-group')));
    await tester.pumpAndSettle();

    expect(chatStore.groupParticipants(threadId).contains(myId), isFalse);
    // Let the store's debounced save run on the fake clock rather than
    // `runAsync`, which wedges once read receipts are in flight.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });
}
