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
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_application_1/widgets/club_avatar.dart';
import 'package:flutter_application_1/widgets/clubup_design.dart';
import 'package:flutter_application_1/widgets/event_cover_image.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Geometry and palette assertions for the `Event new design light` /
/// `Event new design black` frames (`283:381` / `283:497`).
///
/// The numbers here are read straight off those frames, so a regression that
/// silently loosens the layout shows up as a failing measurement rather than
/// as a golden nobody re-reads.
///
/// One section is deliberately absent: `attendee-section`. Offline
/// `supabaseEventRsvpCounts` is empty and `fetchEventAttendees` returns
/// `const []`, which sets `_remoteAttendeesLoaded` with nothing in it — so a
/// student's visible-attendee count is zero and `_AttendingCard` renders
/// `SizedBox.shrink()` no matter how the event is seeded. That is a
/// pre-existing property of the Supabase path, documented on
/// `event_attendee_visibility.dart`; the rendering is covered through
/// `ThisWeekScreen` in `event_social_sections_test.dart` instead.
void main() {
  const phone = Size(393, 852);

  late List<Club> originalClubs;
  late List<Event> originalEvents;
  late List<User> originalUsers;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    accountSwitcherService.clear();
    originalClubs = List<Club>.from(clubs);
    originalEvents = List<Event>.from(events);
    originalUsers = List<User>.from(users);
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

  /// Seeds a student session plus an event carrying every optional section the
  /// frames draw — tags, speakers, a programme and a registration link — and
  /// four mutually-followed attendees so the avatar stack is populated.
  Future<Event> pumpDetail(WidgetTester tester) async {
    // The default 800x600 surface reads as a tablet, and `setSurfaceSize`
    // only constrains layout — `MediaQuery.sizeOf` keeps reporting 800x600,
    // which the hero sizes itself off. Drive the view instead.
    tester.view.physicalSize = Size(phone.width * 2, phone.height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);

    users.clear();
    events.clear();
    clubs.clear();

    users.add(
      User(
        id: 'design-current-student',
        name: 'Design Student',
        email: 'design.qa@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    expect(authService.login('design.qa@ku.edu.tr', '135790'), isTrue);

    const followed = [
      'attendee-1',
      'attendee-2',
      'attendee-3',
      'attendee-4',
      'attendee-5',
      'attendee-6',
    ];
    for (final id in followed) {
      users.add(
        User(
          id: id,
          name: 'Attendee ${id.split('-').last}',
          email: '$id@ku.edu.tr',
          password: '',
          role: 'student',
          subscribedClubIds: const [],
        ),
      );
    }
    userState.replaceFollowedUsers(followed);

    final club = Club(
      id: 'rooftop-collective',
      name: 'Rooftop Collective',
      description: '',
      adminUserIds: const [],
    );
    clubs.add(club);

    final start = DateTime.now().add(const Duration(days: 3));
    final event = Event(
      id: 'sunset-rooftop-sessions',
      clubId: club.id,
      title: 'Sunset Rooftop Sessions',
      description:
          'Join us for an evening of live DJ sets, craft cocktails, and '
          'stunning city views.',
      dateTime: start,
      endTime: start.add(const Duration(hours: 4)),
      location: 'Sky Terrace, 245 W 14th St',
      attendeeUserIds: List<String>.from(followed),
      tags: const ['Music', 'Outdoor', '21+', 'Free Entry'],
      registrationUrl: 'https://example.com/reserve',
      speakers: const [
        EventSpeaker(
          name: 'Sarah Chen',
          role: 'Resident DJ & Producer',
          linkedin: 'linkedin.com/in/sarahchen',
        ),
      ],
      schedule: [
        EventSlot(
          time: start,
          title: 'Opening & Welcome Lounge',
          subtitle: 'Speaker: Host Duo',
        ),
        EventSlot(
          time: start.add(const Duration(minutes: 30)),
          title: 'Sunset DJ Performance Set',
          subtitle: 'Speaker: Sarah Chen',
        ),
      ],
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
    await tester.pump(const Duration(milliseconds: 250));
    return event;
  }

  testWidgets('sections run in the order the frames put them in', (
    tester,
  ) async {
    await pumpDetail(tester);

    double topOf(Finder finder) => tester.getTopLeft(finder).dy;

    final title = topOf(find.text('Sunset Rooftop Sessions'));
    final host = topOf(find.text('Rooftop Collective'));
    final about = topOf(find.text('About this event'));
    final tags = topOf(find.text('Music'));
    final speakers = topOf(find.text('Speakers'));
    final programme = topOf(find.text('Programme Schedule'));
    final cta = topOf(find.byKey(const ValueKey('event-registration-cta')));

    expect(title, lessThan(host));
    expect(host, lessThan(about));
    expect(about, lessThan(tags));
    // Speakers before the programme — the reverse of the old order, where the
    // programme came first and the speakers row trailed it.
    expect(tags, lessThan(speakers));
    expect(speakers, lessThan(programme));
    // The registration link used to sit fifth, between the host and the
    // about copy. It is now the page's last section.
    expect(programme, lessThan(cta));

    expect(tester.takeException(), isNull);
  });

  testWidgets('hero, title and CTA match the frame measurements', (
    tester,
  ) async {
    final event = await pumpDetail(tester);

    // `hero-container` 111:6 — 320 tall on a 402-wide frame, so the crop
    // scales off the full width. The cover fills the hero, so its box is the
    // hero's box.
    final hero = tester.getSize(find.byType(EventCoverImage));
    expect(hero.width, phone.width);
    expect(hero.height, closeTo(phone.width * 0.796, 1));

    // `111:36` — ExtraBold 24 at 1.2.
    final title = tester.widget<Text>(find.text(event.title));
    expect(title.style?.fontSize, 24);
    expect(title.style?.fontWeight, FontWeight.w800);
    expect(title.style?.height, 1.2);
    expect(title.style?.fontFamily, 'Figtree');

    // `cta-reserve` 656:9 — a 56px bar spanning the 20px-padded column.
    final ctaSize = tester.getSize(
      find.byKey(const ValueKey('event-registration-cta')),
    );
    expect(ctaSize.height, 56);
    expect(ctaSize.width, phone.width - 40);

    expect(tester.takeException(), isNull);
  });

  testWidgets('every tag is a neutral chip', (tester) async {
    await pumpDetail(tester);

    // `tags-row` 111:65 — no accented leading chip in these frames.
    for (final label in const ['Music', 'Outdoor', '21+']) {
      final tag = tester.widget<Text>(find.text(label));
      expect(tag.style?.color, ClubUpColors.text);
      expect(tag.style?.fontSize, 12);
      expect(tag.style?.fontWeight, FontWeight.w600);
    }

    expect(tester.takeException(), isNull);
  });

  testWidgets('light mode paints the frame palette over a dim header', (
    tester,
  ) async {
    await pumpDetail(tester);

    expect(ClubUpColors.background, const Color(0xFFFAF9F6));
    expect(ClubUpColors.card, const Color(0xFFFFFFFF));
    expect(ClubUpColors.text, const Color(0xFF18181B));
    expect(ClubUpColors.muted, const Color(0xFF71717A));
    // The frames draw #1DA1F2; the handoff accent is the burgundy every other
    // redesigned area already uses.
    expect(ClubUpColors.accent, const Color(0xFF800020));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFFFAF9F6));

    // `back-button` 111:24 — the dim disc and a white glyph, as in dark.
    final back = tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded));
    expect(back.color, Colors.white);
    expect(back.size, 20);

    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode swaps the ramp and returns the header to white', (
    tester,
  ) async {
    await themeService.setDark(true, persistToAccount: false);
    await pumpDetail(tester);

    expect(ClubUpColors.background, const Color(0xFF121212));
    expect(ClubUpColors.card, const Color(0xFF1E1E1E));
    expect(ClubUpColors.text, const Color(0xFFFAFAFA));
    expect(ClubUpColors.muted, const Color(0xFFA1A1AA));
    // The fill stays burgundy; only accent *text* lifts for contrast on the
    // #1E1E1E card.
    expect(ClubUpColors.accent, const Color(0xFF800020));
    expect(ClubUpColors.accentText, const Color(0xFFE8A1A6));

    final scaffold = tester.widget<Scaffold>(find.byType(Scaffold).first);
    expect(scaffold.backgroundColor, const Color(0xFF121212));

    // `back-button` 283:517 keeps the dim disc and the white glyph.
    final back = tester.widget<Icon>(find.byIcon(Icons.arrow_back_rounded));
    expect(back.color, Colors.white);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a section rule is 20px clear of the content on both sides', (
    tester,
  ) async {
    await pumpDetail(tester);

    // The rule between the host row and the About heading. Measured off the
    // 40px club avatar (the row's tallest child) and the heading's own box.
    final hostBottom = tester.getRect(find.byType(ClubAvatar).first).bottom;
    final aboutTop = tester.getTopLeft(find.text('About this event')).dy;

    final rule = find.byWidgetPredicate(
      (w) => w is Divider && w.color == ClubUpColors.border,
    );
    expect(rule, findsWidgets);

    Rect? between;
    for (var i = 0; i < rule.evaluate().length; i++) {
      final rect = tester.getRect(rule.at(i));
      if (rect.top > hostBottom && rect.bottom < aboutTop) {
        between = rect;
        break;
      }
    }
    expect(between, isNotNull, reason: 'no rule between host and about');

    // The heading's text box carries its own line-box padding, so allow a
    // couple of logical pixels either side of the 20.
    expect(between!.top - hostBottom, closeTo(20, 3));
    expect(aboutTop - between.bottom, closeTo(20, 3));

    expect(tester.takeException(), isNull);
  });
}
