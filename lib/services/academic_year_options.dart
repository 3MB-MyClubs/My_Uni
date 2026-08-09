import 'package:flutter/painting.dart';

import '../l10n/app_localizations.dart';
import 'locale_service.dart';

// No BuildContext is available at every academic-year display site; these
// labels are resolved here via the current locale.
AppLocalizations get _l10n =>
    lookupAppLocalizations(Locale(localeService.languageCode));

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

/// Localised label for an academic-year name. Display only — the raw English
/// value is what continues to flow into storage and comparisons. Unknown names
/// (including every database row this list does not cover) pass through
/// unchanged.
String academicYearDisplayName(String value) {
  final l10n = _l10n;
  if (isPrepAcademicYear(value)) return l10n.academicYearPrep;
  return switch (value.trim().toLowerCase()) {
    '1st year' => l10n.academicYear1,
    '2nd year' => l10n.academicYear2,
    '3rd year' => l10n.academicYear3,
    '4th year' => l10n.academicYear4,
    '5th year' => l10n.academicYear5,
    'grad' => l10n.academicYearGrad,
    'graduate' => l10n.academicYearGraduate,
    _ => value,
  };
}

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
