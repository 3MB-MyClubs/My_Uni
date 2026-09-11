import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/account_switcher_service.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/event_cover_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One event state, written once.
///
/// The hero used to carry a `HAPPENING NOW` pill of its own on the cover
/// photo while the time badge above the title said the same thing a few
/// hundred pixels lower — the user read the pair as a bug rather than as
/// emphasis. The pill (and the `PAST` variant beside it) is gone; these
/// assertions keep it gone, and keep the surviving badge above the title
/// rather than back inside the photo.
void main() {
  const phone = Size(393, 852);
  const clubId = 'live-badge-club';
  const eventId = 'live-badge-event';

  late List<Club> originalClubs;
  late List<Event> originalEvents;
  late List<User> originalUsers;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accountSwitcherService.clear();
    originalClubs = List<Club>.from(clubs);
    originalEvents = List<Event>.from(events);
    originalUsers = List<User>.from(users);
    clubs.add(
      Club(
        id: clubId,
        name: 'Rooftop Collective',
        description: '',
        adminUserIds: const [],
      ),
    );
  });

  tearDown(() async {
    accountSwitcherService.clear();
    authService.logout();
    await themeService.setDark(false, persistToAccount: false);
    clubs
      ..clear()
      ..addAll(originalClubs);
    events
      ..clear()
      ..addAll(originalEvents);
    users
      ..clear()
      ..addAll(originalUsers);
  });

  /// [startOffset] and [endOffset] are relative to now, so a negative start
  /// with a positive end is the live window `_isLive` looks for.
  Future<AppLocalizations> pumpDetail(
    WidgetTester tester, {
    required Duration startOffset,
    required Duration endOffset,
  }) async {
    tester.view.physicalSize = phone * tester.view.devicePixelRatio;
    addTearDown(tester.view.resetPhysicalSize);

    final event = Event(
      id: eventId,
      clubId: clubId,
      title: 'Sunset Rooftop Sessions',
      description: 'An evening of DJ sets and city views.',
      dateTime: DateTime.now().add(startOffset),
      endTime: DateTime.now().add(endOffset),
      location: 'Sky Terrace',
      attendeeUserIds: const [],
    );
    events.add(event);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventDetailScreen(event: event, color: const Color(0xFF9E2045)),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    return AppLocalizations.delegate.load(const Locale('en'));
  }

  testWidgets('a live event says so once, above the title', (tester) async {
    final l10n = await pumpDetail(
      tester,
      startOffset: const Duration(minutes: -30),
      endOffset: const Duration(hours: 2),
    );

    // The hero's pill was the uppercase variant; the badge above the title is
    // the sentence-case one. So the uppercase string is the exact thing that
    // must not come back, and the other must appear exactly once.
    expect(find.text(l10n.happeningNowBadge), findsNothing);
    final badge = find.text(l10n.happeningNow);
    expect(badge, findsOneWidget);

    // Above the title, and clear of the cover photo — the two properties the
    // user asked for, in the order they read them.
    final title = find.text('Sunset Rooftop Sessions');
    expect(tester.getTopLeft(badge).dy, lessThan(tester.getTopLeft(title).dy));
    expect(
      tester.getTopLeft(badge).dy,
      greaterThan(tester.getBottomLeft(find.byType(EventCoverImage)).dy),
    );
  });

  testWidgets('a finished event does not keep a PAST pill on the photo', (
    tester,
  ) async {
    final l10n = await pumpDetail(
      tester,
      startOffset: const Duration(hours: -5),
      endOffset: const Duration(hours: -3),
    );

    expect(find.text(l10n.pastBadge), findsNothing);
    expect(find.text(l10n.happeningNow), findsNothing);
    expect(find.text(l10n.ended), findsOneWidget);
  });
}
