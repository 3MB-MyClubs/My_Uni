import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/club.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<Club> originalClubs;
  late List<Event> originalEvents;
  late List<User> originalUsers;

  setUp(() {
    originalClubs = List<Club>.from(clubs);
    originalEvents = List<Event>.from(events);
    originalUsers = List<User>.from(users);
  });

  tearDown(() {
    authService.logout();
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

  testWidgets('host row keeps the follow button within a narrow screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final club = Club(
      id: 'chemical-engineering-club',
      name: 'Kimya Mühendisliği Kulübü (AIChE)',
      description: '',
      adminUserIds: const [],
    );
    final start = DateTime.now().add(const Duration(days: 1));
    final event = Event(
      id: 'career-lab',
      clubId: club.id,
      title: 'Career Lab',
      description: 'Event description',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'SNA A21',
      attendeeUserIds: const [],
    );
    clubs
      ..clear()
      ..add(club);
    events
      ..clear()
      ..add(event);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('tr'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventDetailScreen(event: event, color: const Color(0xFF9E2045)),
        ),
      ),
    );
    await tester.pump();

    expect(find.text(club.name), findsOneWidget);
    expect(find.text('Takip Et'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('event actions stay compact and quick invite animates', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    users.add(
      User(
        id: 'sticky-actions-student',
        name: 'Sticky Actions Student',
        email: 'sticky.actions@ku.edu.tr',
        password: '135790',
        role: 'student',
        subscribedClubIds: const [],
      ),
    );
    expect(authService.login('sticky.actions@ku.edu.tr', '135790'), isTrue);

    final club = Club(
      id: 'sticky-actions-club',
      name: 'Sticky Actions Club',
      description: '',
      adminUserIds: const [],
    );
    final start = DateTime.now().add(const Duration(days: 1));
    final event = Event(
      id: 'sticky-actions-event',
      clubId: club.id,
      title: 'Sticky Actions Event',
      description: 'Event description',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'SNA A21',
      attendeeUserIds: const [],
    );
    clubs
      ..clear()
      ..add(club);
    events
      ..clear()
      ..add(event);
    userState.setProfilePhotoUrl(
      'event-friend-ceren',
      'https://example.com/ceren-avatar.png',
    );
    addTearDown(() => userState.removeProfilePhoto('event-friend-ceren'));

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

    final sticky = find.byKey(const ValueKey('event-sticky-actions'));
    expect(sticky, findsOneWidget);
    expect(tester.getRect(sticky).bottom, closeTo(844, 0.1));
    expect(tester.getSize(sticky).height, lessThanOrEqualTo(114));
    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    final scrollPadding = scrollView.padding!.resolve(TextDirection.ltr);
    expect(
      scrollPadding.bottom,
      greaterThanOrEqualTo(tester.getSize(sticky).height + 32),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('event-rsvp-action'))).height,
      lessThanOrEqualTo(44),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('event-add-to-calendar-action')))
          .height,
      lessThanOrEqualTo(44),
    );
    expect(
      tester
          .getSize(find.byKey(const ValueKey('event-reminder-action')))
          .height,
      lessThanOrEqualTo(44),
    );

    for (final id in const [
      'event-friend-ceren',
      'event-friend-zeynep',
      'event-friend-tolga',
      'event-friend-ece',
      'event-friend-can',
    ]) {
      expect(find.byKey(ValueKey('event-invite-$id')), findsOneWidget);
    }

    final invite = find.byKey(
      const ValueKey('event-invite-event-friend-ceren'),
    );
    expect(invite, findsOneWidget);
    expect(
      tester.getSize(
        find.byKey(
          const ValueKey('event-quick-invite-avatar-event-friend-ceren'),
        ),
      ),
      const Size(56, 56),
    );
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pump();

    expect(find.text('Invited'), findsOneWidget);
    expect(find.byType(InteractiveViewer), findsNothing);
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('invited-check')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 600));
    expect(
      find.byKey(const ValueKey('event-invite-event-friend-selin')),
      findsOneWidget,
    );
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(invite, findsNothing);
    expect(tester.takeException(), isNull);
  });
}
