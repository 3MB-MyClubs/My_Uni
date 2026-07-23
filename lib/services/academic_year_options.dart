import 'app_strings.dart';

/// Stable lookup identity shared with the Supabase academic-years migration.
const String prepAcademicYearId = '00000000-0000-4000-8000-000000000001';
const String prepAcademicYearName = 'Prep';

const List<String> fallbackAcademicYearNames = [
  prepAcademicYearName,
  '1st Year',
  '2nd Year',
  '3rd Year',
  '4th Year',
  '5th Year',
  'Graduate',
];

bool isPrepAcademicYear(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized == 'prep' ||
      normalized == 'preparatory' ||
      normalized == 'preparatory year' ||
      normalized == 'hazırlık';
}

String academicYearDisplayName(String value) =>
    isPrepAcademicYear(value) ? S.prepYear : value;

/// Prep is supplied locally as well as by the database migration. This keeps
/// old or partially migrated environments usable while avoiding duplicates
/// when the backend already exposes Prep under a compatible label.
List<T> ensurePrepAcademicYear<T>(
  List<T> years, {
  required String Function(T item) nameOf,
  required T Function() createPrep,
}) {
  if (years.any((year) => isPrepAcademicYear(nameOf(year)))) return years;
  return [createPrep(), ...years];
}
