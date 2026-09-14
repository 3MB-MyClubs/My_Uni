import 'package:flutter_application_1/l10n/app_localizations_en.dart';
import 'package:flutter_application_1/services/post_timestamp_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = AppLocalizationsEn();
  final now = DateTime(2026, 9, 14, 12);

  test('keeps post timestamps in days through day six', () {
    expect(
      formatPostTimestamp(
        l10n,
        now.subtract(const Duration(days: 6)),
        now: now,
      ),
      '6d ago',
    );
  });

  test('uses completed weeks from day seven until the one-month mark', () {
    expect(
      formatPostTimestamp(
        l10n,
        now.subtract(const Duration(days: 7)),
        now: now,
      ),
      '1w ago',
    );
    expect(
      formatPostTimestamp(
        l10n,
        now.subtract(const Duration(days: 27)),
        now: now,
      ),
      '3w ago',
    );
    expect(
      formatPostTimestamp(
        l10n,
        now.subtract(const Duration(days: 29)),
        now: now,
      ),
      '4w ago',
    );
  });

  test('switches post timestamps to months at 30 days', () {
    expect(
      formatPostTimestamp(
        l10n,
        now.subtract(const Duration(days: 30)),
        now: now,
      ),
      '1mo ago',
    );
    expect(
      formatPostTimestamp(
        l10n,
        now.subtract(const Duration(days: 75)),
        now: now,
      ),
      '2mo ago',
    );
  });
}
