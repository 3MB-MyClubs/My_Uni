import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/chats_screen.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late String userId;
  late String directThreadId;

  const peerId = 'unread-badge-peer';
  const clubId = 'unread-badge-club';
  const boardMemberId = 'unread-badge-board-member';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('chats_unread_badges_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    userState.followedClubIds.clear();

    expect(
      authService.signUp(
        'Unread Badge Reader',
        'unread.badge.reader@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    userId = authService.currentUser!.id;

    final peer = User(
      id: peerId,
      name: 'Unread Badge Peer',
      email: 'unread.badge.peer@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );
    users.add(peer);
    peopleService.cacheRegisteredUser(peer);
    clubs.add(
      Club(
        id: clubId,
        name: 'Unread Badge Club',
        description: 'Unread badge regression fixture',
        adminUserIds: const [],
        boardMemberIds: const [boardMemberId],
      ),
    );
    userState.followedClubIds.add(clubId);
    directThreadId = chatStore.ensureDirectThread(userId, peerId)!;
    for (final thread in chatStore.threadsFor(userId)) {
      chatStore.markThreadRead(thread.threadId, userId);
    }
  });

  tearDown(() async {
    userState.followedClubIds.clear();
    clubs.removeWhere((club) => club.id == clubId);
    users.removeWhere((user) => user.id == peerId || user.id == userId);
  });

  testWidgets('row badges show only unread activity and clear after opening', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    // `chats-light` 243:475 replaced the segmented Students/Clubs control
    // with a header dropdown, and the per-tab unread counts it carried with
    // the per-row badge at 243:498.
    Future<void> selectTab(String name) async {
      await tester.tap(find.byKey(const ValueKey('chats-filter-dropdown')));
      await tester.pump();
      await tester.tap(find.byKey(ValueKey('chats-filter-option-$name')));
      await tester.pumpAndSettle();
    }

    final directBadge = find.byKey(
      ValueKey('chat-thread-unread-$directThreadId'),
    );
    final clubBadge = find.byKey(
      ValueKey('chat-thread-unread-${ChatStore.clubThreadId(clubId)}'),
    );

    // Existing conversations are not badge-worthy until something new
    // arrives.
    expect(directBadge, findsNothing);

    chatStore.sendMessage(
      threadId: directThreadId,
      senderId: peerId,
      content: 'A new student message',
    );
    chatStore.sendMessage(
      threadId: ChatStore.clubThreadId(clubId),
      senderId: boardMemberId,
      content: 'The announcement body',
      kind: ChatMessageKind.announcement,
      title: 'A new club announcement',
    );
    await tester.pump();

    expect(directBadge, findsOneWidget);
    expect(
      find.descendant(of: directBadge, matching: find.text('1')),
      findsOneWidget,
    );

    await selectTab('clubs');
    expect(clubBadge, findsOneWidget);

    await tester.tap(
      find.byKey(
        const ValueKey('chat-thread-profile-name-club:unread-badge-club'),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      chatStore.unreadInClubLane(
        ChatStore.clubThreadId(clubId),
        userId,
        ClubChatLane.board,
      ),
      0,
    );

    // The club room has its own back button — `club-header` 221:355. Student
    // threads keep `chat-thread-back`.
    await tester.tap(find.byKey(const ValueKey('club-room-back')));
    await tester.pumpAndSettle();

    expect(clubBadge, findsNothing);

    await selectTab('students');
    expect(directBadge, findsOneWidget);

    await tester.tap(
      find.byKey(ValueKey('chat-thread-profile-name-$directThreadId')),
    );
    await tester.pumpAndSettle();

    expect(chatStore.unreadCountFor(directThreadId, userId), 0);

    await tester.tap(find.byKey(const ValueKey('chat-thread-back')));
    await tester.pumpAndSettle();

    expect(directBadge, findsNothing);
    // Let the immediate read-receipt writes and the debounced store save
    // complete before the test tears its temporary Hive directory down.
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('main nav badge counts unread messages, not conversations', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MainNavScreen(isAdmin: false),
        ),
      ),
    );
    await tester.pump();

    final nav = find.byKey(const ValueKey('mobile-bottom-navigation'));
    expect(nav, findsOneWidget);

    Finder navUnreadBadges() => find.descendant(
      of: nav,
      matching: find.byWidgetPredicate((widget) {
        final key = widget.key;
        return key is ValueKey<String> &&
            key.value.startsWith('nav-unread-badge-');
      }),
    );

    // The fixture already has both a direct conversation and a club room.
    // Their existence alone must not create a nav badge.
    expect(navUnreadBadges(), findsNothing);

    // Twelve unread messages in one conversation must show 12, not 1 for the
    // number of conversations and not a shortened 9+ label.
    for (var i = 0; i < 12; i++) {
      chatStore.sendMessage(
        threadId: directThreadId,
        senderId: peerId,
        content: 'Unread message ${i + 1}',
      );
    }
    await tester.pump();
    expect(chatStore.totalUnreadFor(userId), 12);
    expect(
      find.descendant(
        of: nav,
        matching: find.byKey(const ValueKey('nav-unread-badge-12')),
      ),
      findsOneWidget,
    );
    expect(find.descendant(of: nav, matching: find.text('12')), findsOneWidget);
    expect(find.descendant(of: nav, matching: find.text('9+')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
