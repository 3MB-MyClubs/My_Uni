import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/group_info_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
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
import 'package:flutter_application_1/widgets/presence_avatar.dart';
import 'package:flutter_application_1/widgets/user_avatar.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'chat_thread_screen_smoke_test_',
    );
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
    const names = {
      'u2': 'Can Serbester',
      'u3': 'Emir Karaarslan',
      'u4': 'Deniz Kaya',
      'u5': 'Hakan Tuncay',
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
    await Hive.close();
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
    expect(
      find.descendant(
        of: find.byType(PresenceAvatar),
        matching: find.byType(Image),
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    expect(find.text('Computer Engineering · 3rd Year'), findsOneWidget);
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
    'group message runs show sender avatars beside final bubbles on both sides',
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

      expect(
        find.byKey(ValueKey('group-message-avatar-${first.id}')),
        findsNothing,
      );
      final avatar = find.byKey(ValueKey('group-message-avatar-${last.id}'));
      expect(avatar, findsOneWidget);
      expect(
        tester
            .widget<UserAvatar>(
              find.descendant(of: avatar, matching: find.byType(UserAvatar)),
            )
            .userId,
        'u2',
      );
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
      await tester.pump(const Duration(seconds: 1));
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

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump();

    expect(find.byType(TextField), findsOneWidget);
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
