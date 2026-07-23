import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/chat_store.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    authService.logout();
    authService.login('alice@ku.edu.tr', '111111');
    userState.followedClubIds.clear();
  });

  tearDown(() {
    authService.logout();
    userState.followedClubIds.clear();
  });

  testWidgets('club profile chat action opens its canonical community', (
    tester,
  ) async {
    final club = clubForId('c5')!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClubProfileScreen(club: club, color: Colors.green),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final communityButton = find.byKey(
      const ValueKey('club-community-button-c5'),
    );
    await tester.ensureVisible(communityButton);
    await tester.pump(const Duration(milliseconds: 200));
    tester.widget<GestureDetector>(communityButton).onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final thread = tester.widget<ChatThreadScreen>(
      find.byType(ChatThreadScreen),
    );
    expect(thread.threadId, ChatStore.clubThreadId(club.id));
    expect(find.text(S.joinToChat), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club member opens the selected club community conversation', (
    tester,
  ) async {
    final club = clubForId('c5')!;
    userState.followedClubIds.add(club.id);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClubProfileScreen(club: club, color: Colors.green),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final communityButton = find.byKey(
      ValueKey('club-community-button-${club.id}'),
    );
    await tester.ensureVisible(communityButton);
    await tester.tap(communityButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final thread = tester.widget<ChatThreadScreen>(
      find.byType(ChatThreadScreen),
    );
    expect(thread.threadId, ChatStore.clubThreadId(club.id));
    expect(find.byKey(const ValueKey('club-community-header')), findsOneWidget);
    expect(find.text(club.name), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('owning club admin opens only their canonical community', (
    tester,
  ) async {
    authService.logout();
    authService.login('kuacm@ku.edu.tr', '11111111');
    final club = clubForId('c4')!;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClubProfileScreen(club: club, color: Colors.red),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));

    final communityButton = find.byKey(
      ValueKey('club-community-button-${club.id}'),
    );
    await tester.ensureVisible(communityButton);
    await tester.tap(communityButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final thread = tester.widget<ChatThreadScreen>(
      find.byType(ChatThreadScreen),
    );
    expect(thread.threadId, ChatStore.clubThreadId(club.id));
    expect(find.byKey(const ValueKey('club-community-header')), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
