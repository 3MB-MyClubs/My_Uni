import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/club_follow_helper.dart';
import 'package:flutter_application_1/services/guest_session.dart';
import 'package:flutter_application_1/services/guest_world.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const clubId = 'board-unfollow-test-club';
  const otherClubId = 'other-board-club';

  setUp(() async {
    await authService.logout();
    guestSession.begin();
    authService.enterGuestSession();
  });

  tearDown(() async {
    await authService.logout();
  });

  void addClub({required bool currentStudentIsBoardMember}) {
    clubs.add(
      Club(
        id: clubId,
        name: 'Design Society',
        description: 'Test club',
        adminUserIds: const [],
        boardMemberIds: currentStudentIsBoardMember
            ? const [kGuestUserId]
            : const [],
      ),
    );
    userState.replaceFollowedClubs(const [clubId]);
  }

  Future<void> pumpFollowControl(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              key: const ValueKey('unfollow-club'),
              onPressed: () => handleFollowTap(context, clubId, () {}),
              child: const Text('Unfollow club'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('board member must confirm before unfollowing their club', (
    tester,
  ) async {
    addClub(currentStudentIsBoardMember: true);
    await pumpFollowControl(tester);

    await tester.tap(find.byKey(const ValueKey('unfollow-club')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('board-member-unfollow-confirm')),
      findsOneWidget,
    );
    expect(userState.isFollowing(clubId), isTrue);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(userState.isFollowing(clubId), isTrue);
  });

  testWidgets('board member can confirm the unfollow', (tester) async {
    addClub(currentStudentIsBoardMember: true);
    await pumpFollowControl(tester);

    await tester.tap(find.byKey(const ValueKey('unfollow-club')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Unfollow'));
    await tester.pumpAndSettle();

    expect(userState.isFollowing(clubId), isFalse);
  });

  testWidgets('board membership in another club does not show confirmation', (
    tester,
  ) async {
    addClub(currentStudentIsBoardMember: false);
    clubs.add(
      Club(
        id: otherClubId,
        name: 'Another Club',
        description: 'The student is a board member here instead',
        adminUserIds: const [],
        boardMemberIds: const [kGuestUserId],
      ),
    );
    await pumpFollowControl(tester);

    await tester.tap(find.byKey(const ValueKey('unfollow-club')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('board-member-unfollow-confirm')),
      findsNothing,
    );
    expect(userState.isFollowing(clubId), isFalse);
  });
}
