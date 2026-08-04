import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/chat_message.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/club_community_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// The Club Board + Chat surface: one club room, two lanes.
void main() {
  late Directory tempDir;

  const clubId = 'club-board-chat-fixture';
  final threadId = ChatStore.clubThreadId(clubId);

  final officer = User(
    id: 'board-officer',
    name: 'Deniz Şahin',
    email: 'deniz.officer@example.test',
    password: '111111',
    role: 'student',
    subscribedClubIds: const [clubId],
  );
  final member = User(
    id: 'plain-member',
    name: 'İpek Doğan',
    email: 'ipek.member@example.test',
    password: '111111',
    role: 'student',
    subscribedClubIds: const [clubId],
  );
  final club = Club(
    id: clubId,
    name: 'KU Robotics',
    description: 'Board + Chat fixture',
    adminUserIds: const [],
    boardMemberIds: [officer.id],
    boardMemberTitles: {officer.id: 'President'},
  );

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_board_chat_lanes_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
    clubs.add(club);
    users.addAll([officer, member]);
  });

  tearDownAll(() {
    clubs.remove(club);
    users.removeWhere((user) => user.id == officer.id || user.id == member.id);
    userState.followedClubIds.clear();
    authService.logout();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() {
    authService.logout();
    userState.followedClubIds
      ..clear()
      ..add(clubId);
  });

  Future<void> pumpRoom(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubCommunityScreen(threadId: threadId),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  /// Lets ChatStore's debounced Hive write fire before the tree is torn down.
  Future<void> settleStoreSave(WidgetTester tester) =>
      tester.pump(const Duration(seconds: 1));

  ChatMessage postNotice({bool pinned = false, String? title}) {
    final notice = chatStore.sendMessage(
      threadId: threadId,
      senderId: officer.id,
      content: 'Lab hours are extended to 22:00 all week.',
      kind: ChatMessageKind.announcement,
      title: title ?? 'Build sprint starts Monday',
      pinned: pinned,
    );
    expect(notice, isNotNull);
    return notice!;
  }

  testWidgets('a member lands on the Board and is routed into Chat', (
    tester,
  ) async {
    expect(authService.login(member.email, member.password), isTrue);
    final notice = postNotice();

    await pumpRoom(tester);

    // The Board is the landing lane, one grouped row per notice.
    expect(find.byKey(const ValueKey('club-lane-switch')), findsOneWidget);
    expect(find.byKey(ValueKey('club-notice-row-${notice.id}')), findsOneWidget);
    expect(find.text(notice.title!), findsOneWidget);

    // A headline only, until it is tapped.
    expect(find.text(notice.content), findsNothing);

    // No composer and no disabled button — the strip is the doorway to Chat.
    expect(find.byKey(const ValueKey('club-post-notice')), findsNothing);
    expect(
      find.byKey(const ValueKey('club-board-locked-strip')),
      findsOneWidget,
    );
    expect(find.text(S.boardOnlyBoardPosts), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await tester.tap(find.byKey(const ValueKey('club-board-locked-strip')));
    await tester.pumpAndSettle();

    // The room remains readable, but only the yönetim kurulu may post.
    expect(find.byType(TextField), findsNothing);
    expect(
      find.byKey(const ValueKey('club-chat-locked-strip')),
      findsOneWidget,
    );
    await settleStoreSave(tester);
  });

  testWidgets(
    'opening a notice reveals its body without a member reply route',
    (tester) async {
      expect(authService.login(member.email, member.password), isTrue);
      final notice = postNotice(title: 'Navigation-stack demo moved to Friday');

      await pumpRoom(tester);
      await tester.tap(
        find.byKey(ValueKey('club-notice-headline-${notice.id}')),
      );
      await tester.pumpAndSettle();

      expect(find.text(notice.content), findsOneWidget);
      // Non-board members can read the notice but cannot reply in the general
      // channel.
      expect(find.text(S.boardReplyInChat), findsNothing);
      expect(
        find.byKey(ValueKey('club-notice-reply-${notice.id}')),
        findsNothing,
      );
      await settleStoreSave(tester);
    },
  );

  testWidgets('a member holding a role gets the notice composer', (
    tester,
  ) async {
    expect(authService.login(officer.email, officer.password), isTrue);

    await pumpRoom(tester);

    expect(find.byKey(const ValueKey('club-post-notice')), findsOneWidget);
    expect(find.text(S.boardPostNotice), findsOneWidget);
    expect(find.byKey(const ValueKey('club-board-locked-strip')), findsNothing);
    // The reader's own role sits next to the club name.
    expect(find.text('PRESIDENT'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('club-post-notice')));
    await tester.pumpAndSettle();

    Finder fieldWithHint(String hint) => find.byWidgetPredicate(
      (widget) => widget is TextField && widget.decoration?.hintText == hint,
    );
    const title = 'Judges confirmed for Friday';
    await tester.enterText(fieldWithHint(S.announcementTitleHint), title);
    await tester.enterText(fieldWithHint(S.typeMessage), 'Read the run sheet.');
    await tester.tap(find.text(S.post));
    await tester.pumpAndSettle();

    // Published on the Board the author was standing on, and pinned by default.
    expect(find.text(title), findsOneWidget);
    expect(find.text(S.boardGroupPinned.toUpperCase()), findsOneWidget);
    await settleStoreSave(tester);
  });

  testWidgets('an empty Board still explains itself', (tester) async {
    expect(authService.login(member.email, member.password), isTrue);
    for (final notice in chatStore.noticesIn(threadId)) {
      chatStore.deleteMessage(messageId: notice.id, userId: officer.id);
    }

    await pumpRoom(tester);

    expect(find.byKey(const ValueKey('club-board-empty')), findsOneWidget);
    expect(find.text(S.boardEmptyTitle), findsOneWidget);
    expect(find.text(S.boardEmptyHintMember), findsOneWidget);
    await settleStoreSave(tester);
  });

  testWidgets('a non-member gets neither lane', (tester) async {
    expect(authService.login(member.email, member.password), isTrue);
    userState.followedClubIds.clear();

    await pumpRoom(tester);

    expect(find.byKey(const ValueKey('club-lane-switch')), findsNothing);
    expect(find.text(S.joinToChat), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    await settleStoreSave(tester);
  });
}
