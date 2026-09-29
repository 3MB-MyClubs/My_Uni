import 'package:flutter/material.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/services/app_strings.dart';
import 'package:flutter_application_1/services/event_ticket_service.dart';
import 'package:flutter_application_1/services/theme_service.dart';
import 'package:flutter_application_1/widgets/event_ticket_design.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';

class _FakeTickets extends EventTicketService {
  EventTicket? ticket;
  bool fail = false;
  int fetches = 0;

  @override
  Future<EventTicket?> fetch(String eventId, String profileId) async {
    fetches++;
    if (fail) throw StateError('offline');
    return ticket;
  }
}

Event _event({int? capacity}) => Event(
  id: '00000000-0000-0000-0000-000000000001',
  clubId: 'club',
  title: 'Sunset Rooftop Sessions',
  description: '',
  dateTime: DateTime(2030, 9, 27, 19),
  endTime: DateTime(2030, 9, 27, 23),
  location: 'Sky Terrace',
  attendeeUserIds: const [],
  isTicketed: true,
  capacity: capacity,
);

Future<void> _pump(
  WidgetTester tester,
  _FakeTickets service, {
  int? capacity,
  int going = 0,
}) async {
  tester.view.physicalSize = const Size(402, 874);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: EventTicketSection(
            event: _event(capacity: capacity),
            profileId: 'student-1',
            attendeeName: 'Alex Morgan',
            goingCount: going,
            service: service,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('event-get-ticket')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  tearDown(() => themeService.setDark(false, persistToAccount: false));

  testWidgets('section draws the free admission card and a pending status', (
    tester,
  ) async {
    await _pump(tester, _FakeTickets());

    // The heading and the button share their copy in the frame.
    expect(find.text(S.ticketSectionTitle), findsNWidgets(2));
    expect(find.byKey(const ValueKey('event-get-ticket')), findsOneWidget);
    expect(find.text(S.ticketTypeFree), findsOneWidget);
    expect(find.text(S.ticketPriceFree), findsOneWidget);
    expect(find.text(S.ticketStatusPending), findsOneWidget);
    // No seat cap, so no remaining row.
    expect(find.byKey(const ValueKey('event-ticket-remaining')), findsNothing);
  });

  testWidgets('seat cap drives the remaining row', (tester) async {
    await _pump(tester, _FakeTickets(), capacity: 150, going: 26);
    expect(find.text(S.ticketsRemaining(124)), findsOneWidget);
  });

  testWidgets('pending ticket opens the sheet without a QR', (tester) async {
    await _pump(tester, _FakeTickets());
    await _openSheet(tester);

    expect(find.byKey(const ValueKey('event-ticket-sheet')), findsOneWidget);
    expect(find.text(S.ticketPendingBadge), findsOneWidget);
    expect(find.text(S.ticketPendingTitle), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('event-ticket-code')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active ticket shows the QR, holder and door code', (
    tester,
  ) async {
    final service = _FakeTickets()
      ..ticket = EventTicket(id: 't1', token: 'a' * 64, displayCode: 'AB12CD');
    await _pump(tester, service);
    expect(find.text(S.ticketStatusActive), findsOneWidget);

    await _openSheet(tester);

    expect(find.text(S.ticketOnTheList), findsOneWidget);
    expect(find.byKey(const ValueKey('event-ticket-qr')), findsOneWidget);
    expect(find.text('Alex Morgan'), findsOneWidget);
    expect(find.text('AB12CD'), findsOneWidget);
    expect(find.text(S.ticketPresentAtDoor), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Done closes the sheet and the section refetches.
    final before = service.fetches;
    await tester.tap(find.byKey(const ValueKey('event-ticket-done')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byKey(const ValueKey('event-ticket-sheet')), findsNothing);
    expect(service.fetches, greaterThan(before));
  });

  testWidgets('used ticket never shows a scannable QR', (tester) async {
    final service = _FakeTickets()
      ..ticket = EventTicket(
        id: 't1',
        token: 'a' * 64,
        displayCode: 'AB12CD',
        usedAt: DateTime(2030),
      );
    await _pump(tester, service);
    expect(find.text(S.ticketStatusUsed), findsOneWidget);

    await _openSheet(tester);
    expect(find.text(S.ticketUsedBadge), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
  });

  testWidgets('refresh failure drops the QR', (tester) async {
    final service = _FakeTickets()
      ..ticket = EventTicket(id: 't1', token: 'a' * 64, displayCode: 'AB12CD');
    await _pump(tester, service);
    await _openSheet(tester);
    expect(find.byType(QrImageView), findsOneWidget);

    service.fail = true;
    await tester.tap(find.byKey(const ValueKey('event-ticket-refresh')));
    await tester.pump();
    await tester.pump();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('event-ticket-badge')), findsNothing);
  });

  testWidgets('dark sheet lays out without overflow', (tester) async {
    await themeService.setDark(true, persistToAccount: false);
    final service = _FakeTickets()
      ..ticket = EventTicket(id: 't1', token: 'a' * 64, displayCode: 'AB12CD');
    await _pump(tester, service, capacity: 10, going: 3);
    await _openSheet(tester);

    final sheet = tester.widget<Container>(
      find.byKey(const ValueKey('event-ticket-sheet')),
    );
    expect((sheet.decoration! as BoxDecoration).color, const Color(0xFF1E1E1E));
    expect(tester.takeException(), isNull);
  });
}
