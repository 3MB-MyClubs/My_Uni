import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/locale_service.dart';
import 'package:flutter_application_1/services/presence_status.dart';

void main() {
  final now = DateTime.utc(2026, 8, 1, 12);

  test('uses the generic state when no last-seen timestamp is known', () {
    expect(relativeLastSeen(null, now: now).period, LastSeenPeriod.unknown);
  });

  test('buckets last seen into just-now, minutes, hours, and days', () {
    expect(
      relativeLastSeen(
        now.subtract(const Duration(seconds: 59)),
        now: now,
      ).period,
      LastSeenPeriod.justNow,
    );

    final minutes = relativeLastSeen(
      now.subtract(const Duration(minutes: 17)),
      now: now,
    );
    expect(minutes.period, LastSeenPeriod.minutes);
    expect(minutes.value, 17);

    final hours = relativeLastSeen(
      now.subtract(const Duration(hours: 5)),
      now: now,
    );
    expect(hours.period, LastSeenPeriod.hours);
    expect(hours.value, 5);

    final days = relativeLastSeen(
      now.subtract(const Duration(days: 3)),
      now: now,
    );
    expect(days.period, LastSeenPeriod.days);
    expect(days.value, 3);
  });

  test('future timestamps safely render as just now', () {
    expect(
      relativeLastSeen(now.add(const Duration(minutes: 2)), now: now).period,
      LastSeenPeriod.justNow,
    );
  });

  test('renders localized minute, hour, and day labels', () async {
    await localeService.setLanguage('en');
    expect(
      S.lastOnlineLabel(now.subtract(const Duration(minutes: 8)), now: now),
      'Last online 8 min ago',
    );
    expect(
      S.lastOnlineLabel(now.subtract(const Duration(hours: 1)), now: now),
      'Last online 1 hour ago',
    );
    expect(
      S.lastOnlineLabel(now.subtract(const Duration(days: 2)), now: now),
      'Last online 2 days ago',
    );

    await localeService.setLanguage('tr');
    expect(
      S.lastOnlineLabel(now.subtract(const Duration(minutes: 8)), now: now),
      'Son çevrimiçi: 8 dk önce',
    );
    expect(
      S.lastOnlineLabel(now.subtract(const Duration(hours: 1)), now: now),
      'Son çevrimiçi: 1 saat önce',
    );
    expect(
      S.lastOnlineLabel(now.subtract(const Duration(days: 2)), now: now),
      'Son çevrimiçi: 2 gün önce',
    );
  });
}
