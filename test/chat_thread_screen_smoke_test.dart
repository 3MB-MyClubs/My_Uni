import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/group_info_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/models/app_admin.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/widgets/club_avatar.dart';
import 'package:flutter_application_1/widgets/group_avatar_stack.dart';
import 'package:flutter_application_1/widgets/loading_skeleton.dart';
import 'package:flutter_application_1/widgets/presence_avatar.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:hive/hive.dart';

void expectNoVisibleFocusedBorder(TextField field) {
  final border = field.decoration?.focusedBorder;
  expect(border, isNotNull);
  if (border is OutlineInputBorder) {
    expect(border.borderSide, BorderSide.none);
  } else {
    expect(border, InputBorder.none);
  }
}

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'chat_thread_screen_smoke_test_',
    );
    final avatarFile = File('${tempDir.path}/test-avatar.png')
      ..writeAsBytesSync(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
        ),
      );
    for (var i = 1; i <= 15; i++) {
      userState.setProfilePhoto('u$i', avatarFile.path);
    }
    userState.setClubPhoto('c5', avatarFile.path);
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
    const names = {
      'u2': 'Can Serbester',
      'u3': 'Emir Karaarslan',
      'u4': 'Deniz Kaya',
      'u6': 'Elif Şahin',
    };
    for (final entry in names.entries) {
      peopleService.cacheRegisteredUser(
        User(
          id: entry.key,
          name: entry.value,
          email: '${entry.key}.real@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    }
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    authService.logout();
    userState.followedClubIds.clear();
    await themeService.setDark(true);
  });

  tearDown(() async {
    authService.logout();
    await themeService.setDark(true);
  });

  testWidgets('DM thread builds with a message input', (tester) async {
    authService.login('alice@ku.edu.tr', '111111'); // u1
    userState.setMajor('u2', 'Computer Engineering');
    userState.setYear('u2', '3rd Year');
    addTearDown(() {
      userState.majors.remove('u2');
      userState.years.remove('u2');
    });

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(threadId: ChatStore.dmThreadId('u1', 'u2')),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(ChatThreadScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-conversation-backdrop')),
      findsOneWidget,
    );
    expect(find.byType(TextField), findsOneWidget);
    expectNoVisibleFocusedBorder(
      tester.widget<TextField>(find.byType(TextField)),
    );
    expect(
      find.descendant(
        of: find.byType(PresenceAvatar),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.text('Can Serbester'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('Computer Engineering · 3rd Year'), findsOneWidget);
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DM header resolves the participant profile name', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    const peerId = 'u5';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(threadId: ChatStore.dmThreadId('u1', peerId)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Hakan Tuncay'), findsOneWidget);
    expect(find.text('Student'), findsNothing);
    expect(find.text('?'), findsNothing);
    expect(find.text(peerId), findsNothing);
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('unresolved DM avatar loads without showing a question mark', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    const peerId = 'fd6ee260-7327-4e51-9828-6885c4c90800';

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(threadId: ChatStore.dmThreadId('u1', peerId)),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SkeletonBox), findsWidgets);
    expect(find.text('?'), findsNothing);
    expect(find.text('Student'), findsNothing);
    expect(find.text(peerId), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty DM uses the warm patterned conversation canvas', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    final recipient = User(
      id: 'empty-canvas-recipient',
      name: 'Empty Canvas Test',
      email: 'empty.canvas@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(
            threadId: ChatStore.dmThreadId('u1', recipient.id),
            recipient: recipient,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey('chat-conversation-backdrop')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('chat-empty-conversation-card')),
      findsOneWidget,
    );
    expect(find.text(S.startConversation), findsOneWidget);
    expect(find.text(S.privateConversationHint), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('DM header uses a passed recipient outside the mock directory', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111'); // u1
    final recipient = User(
      id: 'remote-can-id',
      name: 'Can Serbester',
      email: 'can.remote@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(
            threadId: ChatStore.dmThreadId('u1', recipient.id),
            recipient: recipient,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Can Serbester'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('chat-empty-conversation-card')),
      findsOneWidget,
    );
    final avatar = tester.widget<UserAvatar>(find.byType(UserAvatar));
    expect(avatar.userId, recipient.id);
    expect(find.text('Student profile'), findsNothing);

    await tester.tap(find.text('Can Serbester'));
    await tester.pumpAndSettle();

    expect(find.byType(UserProfileScreen), findsOneWidget);
    expect(find.text('Can Serbester'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('group header shows its dynamic name and opens group info', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    final threadId = chatStore.createGroupThread(
      creatorId: 'u1',
      recipientIds: ['u2', 'u3', 'u4', 'u5', 'u6'],
    )!;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: threadId)),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('group-chat-header')), findsOneWidget);
    expect(find.text('Can, Emir +3'), findsOneWidget);
    expect(find.byType(GroupAvatarStack), findsOneWidget);
    expect(find.text(S.chatMembers(6)), findsNothing);

    chatStore.setGroupCustomName(threadId, '  Project Team  ');
    await tester.pump();
    expect(find.text('Project Team'), findsOneWidget);
    expect(find.text('Can, Emir +3'), findsNothing);
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.byKey(const ValueKey('group-chat-header')));
    await tester.pumpAndSettle();
    expect(find.byType(GroupInfoScreen), findsOneWidget);
    expect(find.byKey(const ValueKey('edit-group-name-field')), findsOneWidget);
    expectNoVisibleFocusedBorder(
      tester.widget<TextField>(
        find.byKey(const ValueKey('edit-group-name-field')),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('group-member-actions-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make group admin'));
    await tester.pumpAndSettle();
    expect(chatStore.groupForThread(threadId)?.isAdmin('u2'), isTrue);
    expect(find.text('Group admin'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('group-member-actions-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Can Serbester?'), findsOneWidget);
    expect(
      find.text(
        'Are you sure you want to remove Can Serbester from this group?',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(chatStore.groupParticipants(threadId), contains('u2'));

    await tester.tap(find.byKey(const ValueKey('group-member-actions-u2')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove member'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-remove-group-member')));
    await tester.pumpAndSettle();
    expect(chatStore.groupParticipants(threadId), isNot(contains('u2')));
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'group messages show the incoming sender photo and name on every bubble',
    (tester) async {
      authService.login('alice@ku.edu.tr', '111111');
      final threadId = chatStore.createGroupThread(
        creatorId: 'u1',
        recipientIds: ['u2', 'u3'],
      )!;
      final first = chatStore.sendMessage(
        threadId: threadId,
        senderId: 'u2',
        content: 'First message in the run',
      )!;
      final last = chatStore.sendMessage(
        threadId: threadId,
        senderId: 'u2',
        content: 'Last message in the run',
      )!;
      final mine = chatStore.sendMessage(
        threadId: threadId,
        senderId: 'u1',
        content: 'My message',
      )!;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: ChatThreadScreen(threadId: threadId)),
        ),
      );
      await tester.pump();

      for (final message in [first, last]) {
        final avatar = find.byKey(
          ValueKey('group-message-avatar-${message.id}'),
        );
        expect(avatar, findsOneWidget);
        expect(
          tester
              .widget<UserAvatar>(
                find.descendant(of: avatar, matching: find.byType(UserAvatar)),
              )
              .userId,
          'u2',
        );
        expect(
          find.descendant(of: avatar, matching: find.byType(Image)),
          findsOneWidget,
        );
      }
      expect(find.text('Can Serbester'), findsNWidgets(2));
      final myAvatar = find.byKey(ValueKey('group-message-avatar-${mine.id}'));
      expect(myAvatar, findsOneWidget);
      expect(
        tester
            .widget<UserAvatar>(
              find.descendant(of: myAvatar, matching: find.byType(UserAvatar)),
            )
            .userId,
        'u1',
      );
      await tester.runAsync(chatStore.saveAll);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('club thread shows the join prompt for non-members', (
    tester,
  ) async {
    authService.login('alice@ku.edu.tr', '111111');
    userState.followedClubIds.clear();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump();

    expect(find.text(S.joinToChat), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club thread shows the chat for members, light mode', (
    tester,
  ) async {
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');
    userState.followedClubIds.add('c5');
    final incomingFirst = chatStore.sendMessage(
      threadId: 'club:c5',
      senderId: 'u2',
      content: 'First incoming community message',
    )!;
    final incomingSecond = chatStore.sendMessage(
      threadId: 'club:c5',
      senderId: 'u2',
      content: 'Second incoming community message',
    )!;

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
    expectNoVisibleFocusedBorder(
      tester.widget<TextField>(find.byType(TextField)),
    );
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration?.hintText,
      S.communityComposerHint,
    );
    for (final message in [incomingFirst, incomingSecond]) {
      final messageRow = find.byKey(ValueKey('club-message-${message.id}'));
      expect(messageRow, findsOneWidget);
      expect(
        tester
            .widget<UserAvatar>(
              find.descendant(
                of: messageRow,
                matching: find.byType(UserAvatar),
              ),
            )
            .userId,
        'u2',
      );
      expect(
        find.descendant(of: messageRow, matching: find.text('Can Serbester')),
        findsOneWidget,
      );
    }
    expect(find.text(S.joinToChat), findsNothing);
    expect(
      find.text(S.communityMembers(clubMemberCount('c5'))),
      findsOneWidget,
    );
    expect(find.text(S.communityOnline(0)), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(ClubAvatar),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('club-members-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('club-member-row-u1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('club-member-row-u1')),
        matching: find.text(S.you),
      ),
      findsOneWidget,
    );
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club community header caps large member totals', (tester) async {
    authService.login('alice@ku.edu.tr', '111111');
    userState.followedClubIds.add('c5');
    supabaseClubMemberCounts['c5'] = 243;
    addTearDown(() => supabaseClubMemberCounts.remove('c5'));

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('club-community-header')), findsOneWidget);
    expect(find.text('100+ Members'), findsOneWidget);
    expect(find.text('243 Members'), findsNothing);
    expect(find.text('0 Online'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('database-linked club can publish rich community posts safely', (
    tester,
  ) async {
    authService.setClubAdmin(
      AppAdmin(
        id: 'c5',
        name: 'Database-linked club',
        email: 'database.club@ku.edu.tr',
        password: '',
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump();

    await tester.tap(find.byIcon(Icons.more_horiz_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text(S.postAsAnnouncement));
    await tester.pumpAndSettle();

    for (final field in tester.widgetList<TextField>(find.byType(TextField))) {
      expectNoVisibleFocusedBorder(field);
    }

    Finder fieldWithHint(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );

    const title = 'Community posting regression announcement';
    await tester.enterText(fieldWithHint(S.announcementTitleHint), title);
    await tester.enterText(fieldWithHint(S.typeMessage), 'Announcement body');
    await tester.tap(find.text(S.post));
    await tester.pumpAndSettle();

    // The default pinned announcement appears both in the stream and in the
    // pinned strip above it.
    expect(find.text(title), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('club-attach-button')));
    await tester.pump();
    await tester.tap(find.text(S.attachPoll));
    await tester.pumpAndSettle();

    const question = 'Which community activity should be next?';
    await tester.enterText(fieldWithHint(S.pollQuestion), question);
    await tester.enterText(fieldWithHint(S.pollOptionLabel(1)), 'Workshop');
    await tester.enterText(fieldWithHint(S.pollOptionLabel(2)), 'Social');
    await tester.tap(find.text(S.post));
    await tester.pumpAndSettle();

    expect(find.text(question), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('club-attach-button')));
    await tester.pump();
    await tester.tap(find.text(S.attachEvent));
    await tester.pumpAndSettle();

    expect(find.text(S.shareEvent), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('club-event-ev3')));
    await tester.pumpAndSettle();

    expect(find.text('Uludağ Kış Tırmanışı'), findsOneWidget);
    await tester.runAsync(chatStore.saveAll);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale admin DM route exposes no recipient or messages', (
    tester,
  ) async {
    authService.login('kuacm@ku.edu.tr', '11111111');
    final recipient = User(
      id: 'u2',
      name: 'Can Serbester',
      email: 'can@ku.edu.tr',
      password: '',
      role: 'student',
      subscribedClubIds: const [],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(
            threadId: ChatStore.dmThreadId('cadmin5', recipient.id),
            recipient: recipient,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('chat-unavailable')), findsOneWidget);
    expect(find.text('Can Serbester'), findsNothing);
    expect(find.byType(UserAvatar), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club admin cannot open another club community manually', (
    tester,
  ) async {
    authService.login('kuacm@ku.edu.tr', '11111111');

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('chat-unavailable')), findsOneWidget);
    expect(find.text('Dağcılık Kulübü (KUDAK)'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
