import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/screens/event_attendee_list_screen.dart';
import 'package:flutter_application_1/screens/event_detail_screen.dart';
import 'package:flutter_application_1/services/auth_service.dart';
import 'package:flutter_application_1/services/mock_data.dart';
import 'package:flutter_application_1/services/user_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

void main() {
  late Directory tempDir;
  late Event event;
  late List<User> originalUsers;
  late List<Event> originalEvents;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('event_social_test_');
    Hive.init(tempDir.path);
  });

  setUp(() {
    originalUsers = List<User>.from(users);
    originalEvents = List<Event>.from(events);
    users.clear();
    events.clear();

    expect(
      authService.signUp('Current Student', 'event.social@ku.edu.tr', '135790'),
      isTrue,
    );

    users.addAll([
      _user('attendee-1', 'Ceren Levent'),
      _user('attendee-2', 'Zeynep Arslan'),
      _user('attendee-3', 'Tolga Kurt'),
      _user('attendee-4', 'Mina Demir'),
      _user('friend-1', 'Ece Yılmaz'),
      _user('friend-2', 'Can Kaya'),
      _user('friend-3', 'Selin Aksoy'),
    ]);
    userState.replaceFollowedUsers(const ['attendee-1', 'attendee-2']);
    userState.setMajor('friend-1', 'Economics');
    userState.setYear('friend-1', 'Class of 2027');

    final start = DateTime.now().add(const Duration(days: 4));
    event = Event(
      id: 'event-social-sections',
      clubId: 'event-social-club',
      title: 'Campus Futures Forum',
      description: 'A student-led conversation about the future of campus.',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'Student Center',
      attendeeUserIds: const [
        'attendee-1',
        'attendee-2',
        'attendee-3',
        'attendee-4',
      ],
    );
    events.add(event);
  });

  tearDown(() {
    authService.logout();
    userState.replaceFollowedUsers(const []);
    users
      ..clear()
      ..addAll(originalUsers);
    events
      ..clear()
      ..addAll(originalEvents);
  });

  tearDownAll(() async {
    await Hive.close();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  testWidgets('shows both requested sections without horizontal overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 780));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_app(event));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    final scrollable = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('event-attending-card')),
      350,
      scrollable: scrollable,
    );
    await tester.pump();

    expect(find.text('4 attending'), findsOneWidget);
    expect(find.text('2 people you follow are going'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-bring-friends-card')),
      findsOneWidget,
    );
    expect(find.text('Bring your friends'), findsOneWidget);
    expect(find.text('Share event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attendee card opens the public attendee list', (tester) async {
    await tester.pumpWidget(_app(event));
    await tester.pump();

    final card = find.byKey(const ValueKey('event-attending-card'));
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.byType(EventAttendeeListScreen), findsOneWidget);
    expect(
      find.byKey(const ValueKey('event-public-attendee-list')),
      findsOneWidget,
    );
    expect(find.text('Ceren Levent'), findsOneWidget);
  });

  testWidgets('invite action updates the row state', (tester) async {
    await tester.pumpWidget(_app(event));
    await tester.pump();

    final invite = find.byKey(const ValueKey('event-invite-friend-1'));
    await tester.ensureVisible(invite);
    await tester.tap(invite);
    await tester.pump();

    expect(find.text('Invited'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('See all and Share event open the same share sheet', (
    tester,
  ) async {
    await tester.pumpWidget(_app(event));
    await tester.pump();

    final seeAll = find.byKey(const ValueKey('event-friends-see-all'));
    await tester.ensureVisible(seeAll);
    await tester.tap(seeAll);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('event-share-sheet')), findsOneWidget);
    expect(find.text('Share this event'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-share-close')));
    await tester.pumpAndSettle();

    final shareEvent = find.byKey(const ValueKey('event-share-from-friends'));
    await tester.ensureVisible(shareEvent);
    await tester.tap(shareEvent);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('event-share-sheet')), findsOneWidget);
    expect(find.text('Share this event'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

User _user(String id, String name) => User(
  id: id,
  name: name,
  email: '$id@ku.edu.tr',
  password: '',
  role: 'student',
  subscribedClubIds: const [],
);

Widget _app(Event event) => ProviderScope(
  child: MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: EventDetailScreen(event: event, color: const Color(0xFF9E2045)),
  ),
);
