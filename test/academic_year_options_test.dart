import 'package:flutter/material.dart';
import 'package:flutter_application_1/screens/signup_steps/step_profile.dart';
import 'package:flutter_application_1/services/academic_year_options.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/signup_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() => localeService.setLanguage('en'));

  test('Prep is the first fallback academic year before Year 1', () {
    expect(fallbackAcademicYearNames.first, prepAcademicYearName);
    expect(fallbackAcademicYearNames[1], '1st Year');
  });

  test('Prep is inserted once when a backend has not returned it yet', () {
    final years = ensurePrepAcademicYear<String>(
      const ['1st Year', '2nd Year'],
      nameOf: (year) => year,
      createPrep: () => prepAcademicYearName,
    );
    expect(years, const ['Prep', '1st Year', '2nd Year']);

    final existing = ensurePrepAcademicYear<String>(
      const ['Preparatory Year', '1st Year'],
      nameOf: (year) => year,
      createPrep: () => prepAcademicYearName,
    );
    expect(existing, const ['Preparatory Year', '1st Year']);
  });

  test(
    'Prep label is bilingual while its stored value stays canonical',
    () async {
      expect(academicYearDisplayName(prepAcademicYearName), 'Prep');
      await localeService.setLanguage('tr');
      expect(academicYearDisplayName(prepAcademicYearName), 'Hazırlık');
      expect(prepAcademicYearName, 'Prep');
    },
  );

  testWidgets('signup renders Prep and seven years without overflow', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 720);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StepProfile(
            initialMajor: 'Computer Engineering',
            loadMajors: () async => const [
              SignupLookupItem(id: 'major-1', name: 'Computer Engineering'),
            ],
            loadAcademicYears: () async => [
              for (
                var index = 0;
                index < fallbackAcademicYearNames.length;
                index++
              )
                SignupLookupItem(
                  id: 'year-$index',
                  name: fallbackAcademicYearNames[index],
                ),
            ],
            onNext: (_, _, _, _, _, _) {},
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('Prep'), findsOneWidget);
    expect(find.byKey(const ValueKey('signup-year-year-0')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
