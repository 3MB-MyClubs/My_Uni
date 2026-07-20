import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/notification.dart';
import 'package:flutter_application_1/screens/chat_thread_screen.dart';
import 'package:flutter_application_1/screens/club_profile_screen.dart';
import 'package:flutter_application_1/screens/notifications_screen.dart';
import 'package:flutter_application_1/screens/user_profile_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    authService.logout();
    authService.login('kuacm@ku.edu.tr', '11111111');
  });

  tearDown(() {
    authService.logout();
    userState.dynamicNotifications.removeWhere(
      (notification) => notification.id == 'legacy-admin-dm-notification',
    );
  });

  testWidgets('club admin student profiles have no Message action', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(home: UserProfileScreen(user: users.first)),
      ),
    );
    await tester.pump();

    expect(find.text(S.message), findsNothing);
    expect(find.byType(ChatThreadScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('club admin unrelated club profiles have no chat action', (
    tester,
  ) async {
    final unrelatedClub = clubForId('c5')!;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: ClubProfileScreen(club: unrelatedClub, color: Colors.green),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(S.clubChat), findsNothing);
    expect(find.byType(ChatThreadScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('stale DM notifications are hidden for club admins', (
    tester,
  ) async {
    userState.dynamicNotifications.add(
      AppNotification(
        id: 'legacy-admin-dm-notification',
        userId: 'cadmin5',
        message: 'Can Serbester sent you a message',
        createdAt: DateTime.now(),
        targetType: 'message',
        targetId: 'u2',
        fromId: 'u2',
      ),
    );

    await tester.pumpWidget(
      const ProviderScope(child: MaterialApp(home: NotificationsScreen())),
    );
    await tester.pump();

    expect(find.text('Can Serbester sent you a message'), findsNothing);
    expect(find.byType(ChatThreadScreen), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
