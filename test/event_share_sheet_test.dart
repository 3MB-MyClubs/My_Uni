import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/models/user.dart';
import 'package:flutter_application_1/services/app_colors.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/event_share_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Event event;
  late List<User> people;

  setUp(() async {
    await themeService.setDark(false, persistToAccount: false);
    final start = DateTime(2026, 9, 17, 18, 30);
    event = Event(
      id: 'share-sheet-event',
      clubId: 'share-sheet-club',
      title: 'Campus Futures Forum',
      description: 'A student-led conversation.',
      dateTime: start,
      endTime: start.add(const Duration(hours: 2)),
      location: 'Student Center',
      attendeeUserIds: const [],
    );
    people = [
      _user('friend-1', 'Ceren Levent'),
      _user('friend-2', 'Zeynep Arslan'),
      _user('friend-3', 'Tolga Kurt'),
    ];
  });

  tearDown(() async {
    await themeService.setDark(false, persistToAccount: false);
  });

  testWidgets('search, selection, send state, and embedded QR all work', (
    tester,
  ) async {
    final invited = <User>[];
    await tester.pumpWidget(
      _harness(event: event, people: people, onInvite: invited.addAll),
    );

    await tester.tap(find.byKey(const ValueKey('open-share-sheet')));
    await tester.pumpAndSettle();

    expect(find.text('Campus Futures Forum'), findsOneWidget);
    expect(find.text('Student Center'), findsOneWidget);
    expect(find.text('Invite friends'), findsOneWidget);
    expect(find.text('Copy link'), findsNothing);
    expect(find.text('Message'), findsNothing);
    expect(find.text('Story'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('event-share-summary-qr')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-share-qr-dialog')), findsOneWidget);
    expect(find.text('Scan to open this event'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('event-share-qr-close')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('event-share-search')),
      'zeynep',
    );
    await tester.pump();
    expect(find.text('Zeynep Arslan'), findsOneWidget);
    expect(find.text('Ceren Levent'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('event-share-invite-friend-2')));
    await tester.pump();
    expect(find.text('Invite 1 friend'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-share-send-invites')));
    await tester.pump();
    expect(invited.map((person) => person.id), ['friend-2']);
    expect(find.text('Sent'), findsOneWidget);
    expect(find.text('Invite friends'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('sent ids cannot be selected or invited twice', (tester) async {
    var inviteCalls = 0;
    await tester.pumpWidget(
      _harness(
        event: event,
        people: people,
        sentIds: const {'friend-1'},
        onInvite: (_) => inviteCalls++,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-share-sheet')));
    await tester.pumpAndSettle();
    expect(find.text('Sent'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('event-share-invite-friend-1')));
    await tester.pump();
    expect(find.text('Invite friends'), findsOneWidget);
    expect(inviteCalls, 0);
  });

  testWidgets('embedded QR fits a narrow sheet without overflow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _harness(event: event, people: people, onInvite: (_) {}),
    );

    await tester.tap(find.byKey(const ValueKey('open-share-sheet')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('event-share-summary-qr')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('sheet responds to theme changes while it is open', (
    tester,
  ) async {
    await themeService.setDark(true, persistToAccount: false);
    await tester.pumpWidget(
      _harness(event: event, people: people, onInvite: (_) {}),
    );
    await tester.tap(find.byKey(const ValueKey('open-share-sheet')));
    await tester.pumpAndSettle();

    Material sheetMaterial() => tester.widget<Material>(
      find.byKey(const ValueKey('event-share-sheet')),
    );

    expect(sheetMaterial().color, DarkColors.card);
    await themeService.setDark(false, persistToAccount: false);
    await tester.pump();
    expect(sheetMaterial().color, LightColors.card);
  });

  testWidgets('outside tap dismisses the sheet', (tester) async {
    await tester.pumpWidget(
      _harness(event: event, people: people, onInvite: (_) {}),
    );
    await tester.tap(find.byKey(const ValueKey('open-share-sheet')));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-share-sheet')), findsNothing);
  });

  testWidgets('downward swipe dismisses the sheet', (tester) async {
    await tester.pumpWidget(
      _harness(event: event, people: people, onInvite: (_) {}),
    );
    await tester.tap(find.byKey(const ValueKey('open-share-sheet')));
    await tester.pumpAndSettle();

    await tester.drag(
      find.byKey(const ValueKey('event-share-close')),
      const Offset(0, 700),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('event-share-sheet')), findsNothing);
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

Widget _harness({
  required Event event,
  required List<User> people,
  required ValueChanged<List<User>> onInvite,
  Set<String> sentIds = const {},
}) {
  return ProviderScope(
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: FilledButton(
              key: const ValueKey('open-share-sheet'),
              onPressed: () => showEventShareSheet(
                context: context,
                event: event,
                people: people,
                sentUserIds: sentIds,
                onInvite: onInvite,
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
}
