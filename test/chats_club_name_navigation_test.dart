import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/chats_screen.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late String userId;
  const clubId = 'chat-name-navigation-club';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'chats_club_name_navigation_',
    );
    Hive.init(tempDir.path);
    await contentStore.initialize();
    await chatStore.initialize();
  });

  tearDownAll(() async {
    await chatStore.saveAll();
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await authService.logout();
    expect(
      authService.signUp(
        'Chat Route Tester',
        'chat.route.tester@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    userId = authService.currentUser!.id;
    clubs.add(
      Club(
        id: clubId,
        name: 'Chat Route Club',
        description: '',
        adminUserIds: const [],
      ),
    );
    userState.followedClubIds.add(clubId);
  });

  tearDown(() async {
    userState.followedClubIds.remove(clubId);
    clubs.removeWhere((club) => club.id == clubId);
    users.removeWhere((user) => user.id == userId);
    await authService.logout();
  });

  testWidgets('club name in Chats opens its chat instead of its profile', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: ChatsScreen())),
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('chat-filter-clubs')));
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey('chat-thread-profile-name-club:$clubId')),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ChatThreadScreen), findsOneWidget);
    expect(
      tester.widget<ChatThreadScreen>(find.byType(ChatThreadScreen)).threadId,
      ChatStore.clubThreadId(clubId),
    );
    expect(find.byType(ClubProfileScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
