import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/main_nav_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/hive_bootstrap.dart';
import 'package:flutter_application_1/services/personalization_service.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/onboarding/onboarding_service.dart';
import 'package:flutter_application_1/services/user_prefs_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/services/view_tracker.dart';

/// Throwaway visual verification for local messaging and membership gates.
void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Chats: inbox, club room, DM, membership gate', (tester) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await peopleService.initialize();
    await contentStore.initialize();
    await chatStore.initialize();
    await viewTracker.initialize();
    await personalizationService.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    contentStore.applyToLists();
    await themeService.setDark(true);

    expect(
      authService.signUp(
        'Alice Local',
        'alice.local.drive@ku.edu.tr',
        '135790',
      ),
      isTrue,
    );
    final aliceId = authService.currentUser!.id;
    authService.logout();
    await Future<void>.delayed(const Duration(milliseconds: 2));
    expect(
      authService.signUp('Can Local', 'can.local.drive@ku.edu.tr', '135790'),
      isTrue,
    );
    final canId = authService.currentUser!.id;
    userPrefsService.load(canId);
    userState.followedClubIds.add('c4');
    final localThreadId = chatStore.ensureDirectThread(canId, aliceId)!;
    chatStore.sendMessage(
      threadId: localThreadId,
      senderId: aliceId,
      content: 'A real on-device message',
    );
    await onboardingService.complete(canId);

    await binding.convertFlutterSurfaceToImage();

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainNavScreen(isAdmin: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    await binding.takeScreenshot('chats-01-home-topbar');

    // ── Chats tab: only the locally registered contact is present ──
    await tester.tap(find.text('Chats'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(S.searchPeople), findsOneWidget);
    await binding.takeScreenshot('chats-02-inbox');

    // ── Club room: open KUACM, send a message ──
    await tester.tap(find.byKey(const ValueKey('chat-filter-clubs')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text(S.onlineNow.toUpperCase()), findsNothing);
    await tester.tap(find.text('Bilgisayar Kulübü (KUACM)').first);
    await tester.pump(const Duration(milliseconds: 700));
    await binding.takeScreenshot('chats-03-club-room');

    await tester.enterText(
      find.byType(TextField),
      'Looking forward to the hackathon! 🚀',
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot('chats-04-club-room-sent');

    // Back to the inbox (custom v5 header back button).
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pump(const Duration(milliseconds: 500));

    // ── DM: open the real local contact and send a persisted message ──
    await tester.tap(find.byKey(const ValueKey('chat-filter-students')));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Alice Local').first);
    await tester.pump(const Duration(milliseconds: 700));
    await binding.takeScreenshot('chats-05-dm-thread');

    // Tapping the DM header identity opens that person's profile directly.
    await tester.tap(find.text('Alice Local').first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(UserProfileScreen), findsOneWidget);
    await binding.takeScreenshot('chats-05b-recipient-profile');
    await tester.tap(find.byIcon(Icons.chevron_left_rounded).first);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField), 'Hey! See you at 11 then?');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 500));
    await binding.takeScreenshot('chats-06-dm-sent');

    await tester.tap(find.byIcon(Icons.arrow_back_ios_new_rounded).first);
    await tester.pump(const Duration(milliseconds: 400));

    // ── Members-only gate: u2 does not follow c5 (KUDAK) ──
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ChatThreadScreen(threadId: 'club:c5')),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await binding.takeScreenshot('chats-07-join-gate');

    await chatStore.saveAll();
  });

  testWidgets('Club admin: Chats is only the managed community', (
    tester,
  ) async {
    authService.logout();
    await hiveBootstrap.initialize();
    await userPrefsService.initialize();
    await contentStore.initialize();
    await chatStore.initialize();
    await themeService.initialize();
    await onboardingService.initialize();
    await themeService.setDark(true);

    authService.login('kuacm@ku.edu.tr', '11111111');
    userPrefsService.load('cadmin5');
    await onboardingService.complete('cadmin5');

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: MainNavScreen(isAdmin: true)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 700));

    await tester.tap(find.text('Chats'));
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Bilgisayar Kulübü (KUACM)'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Search students'), findsNothing);
    expect(find.byIcon(Icons.edit_square), findsNothing);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsNothing);

    const announcement = 'Admin community integration message';
    await tester.enterText(find.byType(TextField), announcement);
    await tester.tap(find.byIcon(Icons.send_rounded));
    await tester.pump(const Duration(milliseconds: 400));
    final sent = chatStore.messagesFor('club:c4', viewerId: 'cadmin5').last;
    expect(sent.senderId, 'cadmin5');
    expect(sent.content, announcement);
    expect(chatStore.ensureDirectThread('cadmin5', 'u2'), isNull);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ChatThreadScreen(
            threadId: ChatStore.dmThreadId('cadmin5', 'u2'),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('chat-unavailable')), findsOneWidget);
    expect(find.byType(TextField), findsNothing);

    await chatStore.saveAll();
    authService.logout();
  });
}
