import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/group_chat_service.dart';
import 'package:flutter_application_1/services/message_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/tutorial_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Phase 2: group chats survive in Hive and followers can open club channels.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Group chats persist to Hive and channel opens from club page', (
    tester,
  ) async {
    authService.logout();
    await messageService.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await groupChatService.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await tutorialService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(false);
    authService.login('alice@ku.edu.tr', '111111');

    // ── Group chat persistence ──
    final group = groupChatService.createGroup(
      creatorId: 'u1',
      memberIds: const ['u2', 'u3'],
      initialContent: 'Study group for finals!',
      groupName: 'Finals Crew',
    );
    await tester.pump(const Duration(milliseconds: 300));

    final stored = Hive.box<dynamic>('group_chats_v1').get('groups') as List?;
    expect(stored, isNotNull);
    expect(
      stored!.any((raw) => (raw as Map)['id'] == group.id),
      isTrue,
      reason: 'created group must be written to the Hive box',
    );

    // ── Club channel entry from the club profile ──
    final club = clubs.firstWhere((c) => c.id == 'c1');
    if (!userState.isFollowing(club.id)) userState.toggleFollow(club.id);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClubProfileScreen(club: club, color: const Color(0xFF8C1D40)),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 800));

    final channelButton = find.byIcon(Icons.forum_outlined);
    expect(channelButton, findsOneWidget);
    await tester.tap(channelButton);
    await tester.pump(const Duration(milliseconds: 800));

    // Channel screen shows the club name in its header.
    expect(find.textContaining(club.name.split(' ').first), findsWidgets);

    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
    await binding.takeScreenshot('phase2-club-channel');

    groupChatService.closeGroup(group.id, 'u1');
    expect(tester.takeException(), isNull);
  });
}
