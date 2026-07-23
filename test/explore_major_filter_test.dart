import 'package:flutter/material.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/explore_screen.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/people_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engineeringId = 'major-filter-engineering';
  const economicsId = 'major-filter-economics';
  const missingMajorId = 'major-filter-missing';

  setUpAll(() {
    for (final user in [
      User(
        id: engineeringId,
        name: 'Ada Engineering',
        email: 'ada.engineering@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: economicsId,
        name: 'Bora Economics',
        email: 'bora.economics@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
      User(
        id: missingMajorId,
        name: 'Cem Undeclared',
        email: 'cem.undeclared@ku.edu.tr',
        password: '',
        role: 'student',
        subscribedClubIds: const [],
      ),
    ]) {
      peopleService.cacheRegisteredUser(user);
    }
  });

  setUp(() async {
    authService.logout();
    await localeService.setLanguage('en');
    await themeService.setDark(true);
    userState.setMajor(engineeringId, 'Computer Engineering');
    userState.setMajor(economicsId, 'Economics');
    userState.setMajor(missingMajorId, '');
  });

  tearDown(() async {
    authService.logout();
    await localeService.setLanguage('en');
    await themeService.setDark(true);
  });

  Future<void> pumpFindPeople(WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: ExploreScreen(initialTabIndex: 2)),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> selectMajor(WidgetTester tester, String major) async {
    await tester.tap(find.byKey(const ValueKey('people-major-filter')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('academic-program-picker-search')),
      major,
    );
    await tester.pump();
    await tester.tap(find.byKey(ValueKey('academic-program-$major')));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'major-only filtering includes only exact primary-major matches',
    (tester) async {
      await pumpFindPeople(tester);

      expect(find.text('Ada Engineering'), findsOneWidget);
      expect(find.text('Bora Economics'), findsOneWidget);
      expect(find.text('Cem Undeclared'), findsOneWidget);

      await selectMajor(tester, 'Computer Engineering');

      expect(find.text('Ada Engineering'), findsOneWidget);
      expect(find.text('Bora Economics'), findsNothing);
      expect(find.text('Cem Undeclared'), findsNothing);
      expect(find.textContaining('1 RESULT'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('name search intersects with the selected major and can clear', (
    tester,
  ) async {
    await pumpFindPeople(tester);
    await selectMajor(tester, 'Computer Engineering');

    final search = find.widgetWithText(TextField, S.searchPeople);
    await tester.enterText(search, 'Bora');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bora Economics'), findsNothing);
    expect(find.text(S.noPeopleInSelectedMajor), findsOneWidget);

    await tester.enterText(search, 'Ada');
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Ada Engineering'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('clear-people-major-filter')));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(search, 'Bora');
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Bora Economics'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('major filter and empty state are localized in Turkish', (
    tester,
  ) async {
    await localeService.setLanguage('tr');
    await themeService.setDark(false);
    await pumpFindPeople(tester);

    expect(find.text(S.filterByMajor), findsOneWidget);
    await selectMajor(tester, 'Medicine');

    expect(find.text(S.noPeopleInSelectedMajor), findsOneWidget);
    expect(find.text(S.tryAnotherMajorOrName), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
