import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/club_manage_board_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/content_store.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/club_profile_design.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

/// `board-members-light` / `-dark` — Figma `413:7` / `413:105`.
///
/// The Manage Board Members screen behind Settings ▸ Manage Board Members.
/// Everything it writes goes through `setBoardMembership`, which mutates the
/// in-memory [Club] and the Hive box — no Supabase client is configured in a
/// widget test, so the remote leg is a no-op and the local state is what these
/// tests assert on.
void main() {
  late Directory tempDir;
  const clubId = 'manage-board-club';
  const boardId = 'manage-board-president';
  const candidateId = 'manage-board-candidate';

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('club_manage_board_');
    Hive.init(tempDir.path);
    await contentStore.initialize();
  });

  tearDownAll(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  late Club club;

  setUp(() async {
    await themeService.setDark(false);
    await localeService.setLanguage('en');

    club = Club(
      id: clubId,
      name: 'Rooftop Collective',
      description: 'Deep grooves and sunset sessions.',
      adminUserIds: const ['manage-board-admin'],
      boardMemberIds: [boardId],
      boardMemberTitles: {boardId: 'President'},
    );
    clubs
      ..removeWhere((item) => item.id == clubId)
      ..add(club);
    users
      ..removeWhere((item) => item.id == boardId || item.id == candidateId)
      ..addAll([
        User(
          id: boardId,
          name: 'Liam Connor',
          email: 'liam@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [clubId],
        ),
        User(
          id: candidateId,
          name: 'Zeynep Aksu',
          email: 'zeynep@ku.edu.tr',
          password: '111111',
          role: 'student',
          subscribedClubIds: const [clubId],
        ),
      ]);
  });

  tearDown(() async {
    clubs.removeWhere((item) => item.id == clubId);
    users.removeWhere((item) => item.id == boardId || item.id == candidateId);
    await themeService.setDark(false);
  });

  Future<void> pumpScreen(WidgetTester tester, {double height = 900}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(393, height);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: Locale(localeService.languageCode),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ClubManageBoardScreen(club: club),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('draws the frame: header, both section cards, and the pill', (
    tester,
  ) async {
    await pumpScreen(tester);

    // `header` 413:21 — the same compact bar as `board-members-all`.
    expect(
      find.byKey(const ValueKey('club-manage-board-header')),
      findsOneWidget,
    );
    expect(find.text(S.clubProfileBoardMembersTitle), findsOneWidget);

    // `section-label` 413:29 / 413:52 — the second one carries the live count.
    expect(find.text(S.clubBoardAddSection), findsOneWidget);
    expect(find.text(S.clubBoardCurrentCount(1)), findsOneWidget);

    // `search-field` 413:31, `role-textfield` 413:46, `add-to-board-btn` 413:48.
    expect(
      find.byKey(const ValueKey('club-manage-board-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-manage-board-role')),
      findsOneWidget,
    );
    expect(find.text(S.clubBoardRoleLabel), findsOneWidget);
    expect(find.byKey(const ValueKey('club-manage-board-add')), findsOneWidget);
    expect(find.text(S.clubBoardAddToBoard), findsOneWidget);

    // `member-row` 413:54 — the sitting board member, with its remove control.
    expect(find.text('Liam Connor'), findsOneWidget);
    expect(find.text('President'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('club-manage-board-remove-$boardId')),
      findsOneWidget,
    );

    // The frame's bottom nav is mockup context and is not drawn.
    expect(find.text('Insights'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dropdown lists members who are not on the board yet', (
    tester,
  ) async {
    await pumpScreen(tester);

    // `search-results-dropdown` 413:35 — the candidate is there, the sitting
    // board member is filtered out of it.
    expect(
      find.byKey(const ValueKey('club-manage-board-candidate-$candidateId')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('club-manage-board-candidate-$boardId')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const ValueKey('club-manage-board-search')),
      'nobody-by-this-name',
    );
    await tester.pump();
    expect(find.text(S.clubBoardNoCandidateMatch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('picking someone, typing a role and adding them to the board', (
    tester,
  ) async {
    await pumpScreen(tester);

    // The Add pill needs a picked row: tapping it first only nudges.
    await tester.tap(find.byKey(const ValueKey('club-manage-board-add')));
    await tester.pump();
    expect(club.boardMemberIds, hasLength(1));

    await tester.tap(
      find.byKey(const ValueKey('club-manage-board-candidate-$candidateId')),
    );
    await tester.pump();
    // `select-btn` 416:23 marks the picked row.
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);

    await tester.enterText(
      find.byKey(const ValueKey('club-manage-board-role')),
      'Sponsorship Lead',
    );
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('club-manage-board-add')));
    await tester.pumpAndSettle();

    // Did the reset half of _addSelected run at all?
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    expect(club.boardMemberIds, contains(candidateId));
    expect(club.boardMemberTitles[candidateId], 'Sponsorship Lead');
    // The count label and the list both follow.
    expect(find.text(S.clubBoardCurrentCount(2)), findsOneWidget);
    expect(find.text('Zeynep Aksu'), findsOneWidget);
    expect(find.text('Sponsorship Lead'), findsOneWidget);

    // The composer resets: both fields empty and the pick released.
    for (final key in const [
      ValueKey('club-manage-board-role'),
      ValueKey('club-manage-board-search'),
    ]) {
      final field = tester.widget<TextField>(
        find.descendant(of: find.byKey(key), matching: find.byType(TextField)),
      );
      expect(field.controller!.text, isEmpty);
    }
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    // …and the picked row leaves the dropdown.
    expect(
      find.byKey(const ValueKey('club-manage-board-candidate-$candidateId')),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a board member cannot be added without a written role', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const ValueKey('club-manage-board-candidate-$candidateId')),
    );
    await tester.pump();

    final addButton = find.byKey(const ValueKey('club-manage-board-add'));
    Opacity buttonOpacity() => tester.widget<Opacity>(
      find.descendant(of: addButton, matching: find.byType(Opacity)),
    );

    expect(buttonOpacity().opacity, lessThan(1));
    await tester.enterText(
      find.byKey(const ValueKey('club-manage-board-role')),
      '   ',
    );
    await tester.pump();
    await tester.tap(addButton);
    await tester.pump();

    expect(find.text(S.clubBoardRoleRequired), findsOneWidget);
    expect(club.boardMemberIds, isNot(contains(candidateId)));
    expect(club.boardMemberTitles, isNot(contains(candidateId)));
    expect(buttonOpacity().opacity, lessThan(1));

    await tester.enterText(
      find.byKey(const ValueKey('club-manage-board-role')),
      'Treasurer',
    );
    await tester.pump();
    expect(buttonOpacity().opacity, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the trash button removes a member behind one confirmation', (
    tester,
  ) async {
    await pumpScreen(tester);

    await tester.tap(
      find.byKey(const ValueKey('club-manage-board-remove-$boardId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('club-manage-board-remove-confirm')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey('club-manage-board-remove-confirm-yes')),
    );
    await tester.pumpAndSettle();

    expect(club.boardMemberIds, isEmpty);
    expect(club.boardMemberTitles, isEmpty);
    expect(find.text(S.clubBoardCurrentCount(0)), findsOneWidget);
    // Removed members fall back into the dropdown.
    expect(
      find.byKey(const ValueKey('club-manage-board-candidate-$boardId')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('a long press opens the retitle action the frame does not draw', (
    tester,
  ) async {
    await pumpScreen(tester);

    expect(find.text(S.clubBoardManageHint), findsOneWidget);

    await tester.longPress(
      find.byKey(const ValueKey('club-manage-board-member-$boardId')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('club-board-member-edit')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('club-board-member-edit')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('club-manage-board-title-dialog')),
        matching: find.byType(TextField),
      ),
      'Vice President',
    );
    await tester.tap(
      find.byKey(const ValueKey('club-manage-board-title-save')),
    );
    await tester.pumpAndSettle();

    expect(club.boardMemberTitles[boardId], 'Vice President');
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark uses the club ramp and the burgundy accent, not the blue', (
    tester,
  ) async {
    await themeService.setDark(true);
    await pumpScreen(tester);

    expect(ClubProfileColors.page, const Color(0xFF0A0A0A));
    expect(ClubProfileColors.card, const Color(0xFF121212));
    expect(ClubProfileColors.field, const Color(0xFF1E1E1E));

    // The frame draws every accent `#1DA1F2`; the screen uses the section's.
    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF0A0A0A));
    expect(ClubProfileColors.accent, const Color(0xFF800020));
    expect(ClubProfileColors.accentText, const Color(0xFFFA526B));
    expect(ClubProfileColors.danger, const Color(0xFFDC2626));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the whole screen fits a real 393pt frame in Turkish', (
    tester,
  ) async {
    await localeService.setLanguage('tr');
    await pumpScreen(tester, height: 852);

    expect(find.text(S.clubBoardAddSection), findsOneWidget);
    expect(find.text(S.clubBoardAddToBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
