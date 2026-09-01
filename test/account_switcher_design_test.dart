import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/account_switcher_service.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/account_switcher_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `profile-switcher-light` / `profile-switcher-dark` (Figma `424:113` /
/// `424:6`) — the "Switch Account" sheet.
void main() {
  const uid = 'switcher-student';
  late List<Club> originalClubs;
  late List<User> originalUsers;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accountSwitcherService.clear();
    originalClubs = List<Club>.from(clubs);
    originalUsers = List<User>.from(users);

    users
      ..clear()
      ..add(
        User(
          id: uid,
          name: 'Alex Rivera',
          email: 'alex.rivera@ku.edu.tr',
          password: '135790',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    clubs
      ..clear()
      ..addAll(
        const [
          ('design-club', 'Design Club', 'President'),
          ('robotics-society', 'Robotics Society', 'Vice President'),
          ('debate-union', 'Debate Union', 'Treasurer'),
        ].map(
          (row) => Club(
            id: row.$1,
            name: row.$2,
            description: '',
            adminUserIds: const [],
            boardMemberIds: const [uid],
            boardMemberTitles: {uid: row.$3},
          ),
        ),
      );
    expect(authService.login('alex.rivera@ku.edu.tr', '135790'), isTrue);
  });

  tearDown(() async {
    accountSwitcherService.clear();
    authService.logout();
    await themeService.setDark(false);
    clubs
      ..clear()
      ..addAll(originalClubs);
    users
      ..clear()
      ..addAll(originalUsers);
  });

  Future<void> openSheet(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showAccountSwitcherSheet(context),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Finder rowFor(String name) => find.ancestor(
    of: find.text(name),
    matching: find.byWidgetPredicate((w) => w is SizedBox && w.height == 64),
  );

  /// The 20pt circle at the end of a row.
  BoxDecoration radioFor(WidgetTester tester, String name) {
    final finder = find.descendant(
      of: rowFor(name),
      matching: find.byWidgetPredicate(
        (w) =>
            w is Container &&
            w.constraints?.maxWidth == 20 &&
            (w.decoration as BoxDecoration?)?.shape == BoxShape.circle,
      ),
    );
    return tester.widget<Container>(finder).decoration! as BoxDecoration;
  }

  testWidgets('the sheet lists the personal account and each board club', (
    tester,
  ) async {
    await openSheet(tester);

    expect(find.text(S.switchAccountTitle), findsOneWidget);

    // Personal first, then one row per club the student sits on the board of.
    expect(find.text('Alex Rivera'), findsOneWidget);
    expect(find.text(S.switchAccountPersonal), findsOneWidget);
    expect(find.text('Design Club'), findsOneWidget);
    expect(find.text('Robotics Society'), findsOneWidget);
    expect(find.text('Debate Union'), findsOneWidget);

    // The role line is the student's real board title, localized — not a
    // generic "Club admin account".
    expect(find.text('President'), findsOneWidget);
    expect(find.text('Vice President'), findsOneWidget);
    expect(find.text('Treasurer'), findsOneWidget);

    expect(rowFor('Alex Rivera'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the selected row is burgundy, the rest are outlined', (
    tester,
  ) async {
    await openSheet(tester);

    // Personal is active until a club is chosen.
    expect(radioFor(tester, 'Alex Rivera').color, AccountSwitcherColors.accent);
    expect(
      find.descendant(
        of: rowFor('Alex Rivera'),
        matching: find.byIcon(Icons.check_rounded),
      ),
      findsOneWidget,
    );

    final unselected = radioFor(tester, 'Design Club');
    expect(unselected.color, Colors.transparent);
    expect(unselected.border!.top.color, AccountSwitcherColors.handle);
    expect(unselected.border!.top.width, 2);

    // The frame draws these in `#1DA1F2`; the app accent replaces it.
    expect(AccountSwitcherColors.accent, const Color(0xFF800020));
  });

  // The palette is read at build time, as in every other redesigned area, so
  // each theme needs its own pump — `main.dart` is what rebuilds the tree on a
  // live theme flip.
  for (final dark in const [false, true]) {
    testWidgets(
      'the sheet takes the frame palette in ${dark ? 'dark' : 'light'}',
      (tester) async {
        await themeService.setDark(dark);
        await openSheet(tester);

        final decoration =
            tester
                    .widget<Container>(
                      find.byKey(const ValueKey('account-switcher-sheet')),
                    )
                    .decoration!
                as BoxDecoration;

        expect(
          decoration.color,
          dark ? const Color(0xFF1C1C1E) : const Color(0xFFFFFFFF),
        );
        expect(
          decoration.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)),
        );
        expect(
          AccountSwitcherColors.hairline,
          dark ? const Color(0xFF2C2C2E) : const Color(0xFFE5E5EA),
        );
        expect(
          AccountSwitcherColors.handle,
          dark ? const Color(0xFF48484A) : const Color(0xFFD1D1D6),
        );
        expect(
          AccountSwitcherColors.text,
          dark ? const Color(0xFFFFFFFF) : const Color(0xFF1C1C1E),
        );

        // The two tokens that do not flip between the frames.
        expect(AccountSwitcherColors.muted, const Color(0xFF8E8E93));
        expect(AccountSwitcherColors.accent, const Color(0xFF800020));
      },
    );
  }

  testWidgets('tapping a club row selects it and closes the sheet', (
    tester,
  ) async {
    await openSheet(tester);
    expect(accountSwitcherService.isClubAccountActive, isFalse);

    await tester.tap(find.text('Debate Union'));
    await tester.pumpAndSettle();

    expect(accountSwitcherService.activeClub?.id, 'debate-union');
    expect(find.text(S.switchAccountTitle), findsNothing);
  });

  testWidgets('tapping the avatar selects the row, not the photo viewer', (
    tester,
  ) async {
    await openSheet(tester);

    // Both avatar widgets open a full-screen photo viewer on tap. Inside a
    // switcher row that would swallow the selection.
    final avatar = find.descendant(
      of: rowFor('Design Club'),
      matching: find.byType(IgnorePointer),
    );
    expect(avatar, findsOneWidget);

    await tester.tapAt(tester.getCenter(avatar));
    await tester.pumpAndSettle();

    // If the avatar's viewer had won the tap the sheet would still be up and
    // nothing would be selected.
    expect(find.text(S.switchAccountTitle), findsNothing);
    expect(accountSwitcherService.activeClub?.id, 'design-club');
  });
}
