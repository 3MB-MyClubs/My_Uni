import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter_application_1/l10n/app_localizations.dart';
import 'package:flutter_application_1/services/event_ticket_service.dart';
import 'package:flutter_application_1/screens/event_ticket_scan_screen.dart';
import 'package:flutter_application_1/screens/event_ticket_screen.dart';
import 'package:flutter_application_1/widgets/event_ticket_card.dart';
import 'package:flutter_application_1/widgets/app_network_image.dart';

class FakeTickets extends EventTicketService {
  EventTicket? ticket;
  bool authorized = true;
  bool failFetch = false;
  int scans = 0;
  int issues = 0;
  int revokes = 0;
  bool? reissueRequested;
  Completer<TicketScanResult>? pending;
  TicketScanStatus status = TicketScanStatus.invalid;
  TicketPerson? person;
  @override
  Future<bool> canManage(String eventId) async => authorized;
  @override
  Future<EventTicket?> fetch(String eventId, String profileId) async {
    if (failFetch) throw StateError('offline');
    return ticket;
  }

  @override
  Future<EventTicket> issue(
    String eventId,
    String profileId, {
    bool reissue = false,
  }) async {
    issues++;
    reissueRequested = reissue;
    return ticket = EventTicket(
      id: 't$issues',
      token: (reissue ? 'b' : 'a') * 64,
    );
  }

  @override
  Future<void> revoke(String eventId, String ticketId) async {
    revokes++;
    ticket = EventTicket(
      id: ticketId,
      token: 'a' * 64,
      revokedAt: DateTime.now(),
    );
  }

  @override
  Future<TicketScanResult> scan(String eventId, String payload) async {
    scans++;
    if (pending != null) return pending!.future;
    return TicketScanResult(status);
  }

  @override
  Future<TicketPerson?> personForScan(
    String eventId,
    String payload,
    TicketScanResult result,
  ) async => person;
}

Widget app(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('Android offers a pass file without checking Google Wallet', (
    tester,
  ) async {
    const googleChannel = MethodChannel('ku_app/google_wallet_ticket');
    final googleCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      googleChannel,
      (call) async {
        googleCalls.add(call);
        return true;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        googleChannel,
        null,
      );
    });
    final service = FakeTickets()
      ..ticket = EventTicket(id: 't', token: 'a' * 64);
    await tester.pumpWidget(
      app(
        EventTicketCard(
          eventId: 'event',
          profileId: 'holder',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Add to Wallet'), findsOneWidget);
    expect(find.text('Add to Google Wallet'), findsNothing);
    expect(googleCalls, isEmpty);

    service.ticket = EventTicket(
      id: 't',
      token: 'a' * 64,
      revokedAt: DateTime.now(),
    );
    await tester.tap(find.byTooltip('Refresh ticket'));
    await tester.pumpAndSettle();
    expect(find.text('Add to Wallet'), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));

  testWidgets('scanner shows a square guide and scanned holder details', (
    tester,
  ) async {
    final service = FakeTickets()
      ..status = TicketScanStatus.checkedIn
      ..person = TicketPerson(
        fullName: 'Ada Lovelace',
        avatarUrl: 'https://example.com/ada.jpg',
        major: 'Computer Engineering',
        usedAt: DateTime.utc(2026, 9, 25, 11, 34),
      );
    late void Function(String) detect;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventTicketScanScreen(
          eventId: 'event',
          eventTitle: 'Event',
          service: service,
          scannerBuilder: (callback) {
            detect = callback;
            return const ColoredBox(color: Colors.black);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    final frame = tester.getSize(
      find.byKey(const ValueKey('ticket-scan-frame')),
    );
    expect(frame.width, frame.height);
    detect('qr');
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Computer Engineering'), findsOneWidget);
    expect(find.text('Check-in time'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('ticket-scan-checkin-time')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('ticket-scan-fullscreen-result')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('ticket-scan-frame')), findsNothing);
    expect(find.byType(AppNetworkImage), findsOneWidget);
    await tester.tap(find.text('Scan next ticket'));
    await tester.pump();
    expect(find.text('Ada Lovelace'), findsNothing);
  });

  for (final entry in {
    TicketScanStatus.checkedIn: 'Valid — checked in',
    TicketScanStatus.alreadyUsed: 'Already checked in',
    TicketScanStatus.revoked: 'Ticket canceled',
    TicketScanStatus.wrongEvent: 'Wrong event',
    TicketScanStatus.invalid: 'Invalid ticket',
  }.entries) {
    testWidgets('scanner clearly shows ${entry.key.name}', (tester) async {
      final service = FakeTickets()..status = entry.key;
      late void Function(String) detect;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventTicketScanScreen(
            eventId: 'local-test-event',
            eventTitle: 'Event',
            service: service,
            scannerBuilder: (callback) {
              detect = callback;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      detect('qr');
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(
        find.byKey(const ValueKey('ticket-scan-fullscreen-result')),
        findsOneWidget,
      );
      if (entry.key == TicketScanStatus.alreadyUsed ||
          entry.key == TicketScanStatus.revoked) {
        final icon = tester.widget<Icon>(
          find.byKey(const ValueKey('ticket-scan-status-icon')),
        );
        expect(icon.icon, Icons.warning_rounded);
        expect(
          icon.color,
          entry.key == TicketScanStatus.revoked
              ? Colors.red
              : Colors.amber.shade800,
        );
      }
      expect(find.text('Scan next ticket'), findsOneWidget);
    });
  }

  for (final used in [false, true]) {
    testWidgets('holder cannot display ${used ? 'used' : 'revoked'} QR', (
      tester,
    ) async {
      final service = FakeTickets()
        ..ticket = EventTicket(
          id: 't',
          token: 'a' * 64,
          usedAt: used ? DateTime.now() : null,
          revokedAt: used ? null : DateTime.now(),
        );
      await tester.pumpWidget(
        app(
          EventTicketCard(
            eventId: 'event',
            profileId: 'holder',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(QrImageView), findsNothing);
      expect(
        find.text(used ? 'Already used' : 'Ticket revoked'),
        findsOneWidget,
      );
    });
  }

  testWidgets('used ticket can be reissued by staff', (tester) async {
    final service = FakeTickets()
      ..ticket = EventTicket(
        id: 'used',
        token: 'a' * 64,
        usedAt: DateTime.now(),
      );
    await tester.pumpWidget(
      app(
        EventTicketCard(
          eventId: 'event',
          profileId: 'holder',
          manage: true,
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reissue ticket'));
    await tester.pumpAndSettle();
    expect(service.reissueRequested, true);
    expect(service.ticket?.isActive, true);
    expect(find.text('Ready for admission'), findsOneWidget);
  });

  testWidgets('ticket QR appears on its own page', (tester) async {
    final service = FakeTickets()
      ..ticket = EventTicket(id: 't', token: 'a' * 64);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventTicketScreen(
          eventId: 'event',
          profileId: 'holder',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Admission ticket'), findsWidgets);
    expect(find.byKey(const ValueKey('admission-ticket-qr')), findsOneWidget);
  });

  testWidgets(
    'tapping ticket QR enlarges it and restores brightness on close',
    (tester) async {
      const channel = MethodChannel('ku_app/ticket_brightness');
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call.method);
        return null;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );

      final service = FakeTickets()
        ..ticket = EventTicket(id: 't', token: 'a' * 64);
      await tester.pumpWidget(
        app(
          EventTicketCard(
            eventId: 'event',
            profileId: 'holder',
            service: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('admission-ticket-qr-action')),
      );
      await tester.pumpAndSettle();
      final expanded = tester.widget<QrImageView>(
        find.byKey(const ValueKey('admission-ticket-qr-expanded')),
      );
      expect(expanded.size, greaterThan(220));
      expect(calls, ['maximize']);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('admission-ticket-qr-expanded')),
        findsNothing,
      );
      expect(calls, ['maximize', 'restore']);
    },
  );

  testWidgets('holder sees credential QR; refresh failure hides stale QR', (
    tester,
  ) async {
    final service = FakeTickets()
      ..ticket = EventTicket(id: 't', token: 'a' * 64);
    await tester.pumpWidget(
      app(
        EventTicketCard(
          eventId: 'event',
          profileId: 'holder',
          service: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('admission-ticket-qr')), findsOneWidget);
    expect(find.text('Issue ticket'), findsNothing);
    service.failFetch = true;
    await tester.tap(find.byTooltip('Refresh ticket'));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byKey(const ValueKey('ticket-error')), findsOneWidget);
  });

  testWidgets('staff can issue, revoke and explicitly reissue', (tester) async {
    final service = FakeTickets();
    final changed = <bool>[];
    await tester.pumpWidget(
      app(
        EventTicketCard(
          eventId: 'event',
          profileId: 'holder',
          manage: true,
          service: service,
          onChanged: (ticket) => changed.add(ticket?.isActive == true),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Issue ticket'));
    await tester.pumpAndSettle();
    expect(service.issues, 1);
    expect(service.reissueRequested, false);
    expect(changed, [true]);
    expect(find.byType(QrImageView), findsNothing);
    await tester.tap(find.text('Revoke ticket'));
    await tester.pumpAndSettle();
    expect(service.revokes, 1);
    expect(changed, [true, false]);
    expect(find.text('Ticket revoked'), findsOneWidget);
    await tester.tap(find.text('Reissue ticket'));
    await tester.pumpAndSettle();
    expect(service.reissueRequested, true);
    expect(changed, [true, false, true]);
    expect(find.text('Ready for admission'), findsOneWidget);
  });

  testWidgets('scanner gates camera on server authorization', (tester) async {
    final service = FakeTickets()..authorized = false;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EventTicketScanScreen(
          eventId: 'event',
          eventTitle: 'Event',
          service: service,
          scannerBuilder: (_) => const Text('CAMERA'),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('CAMERA'), findsNothing);
    expect(
      find.text('You are not authorized to manage tickets for this event.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'repeated camera detections send one request and require next-scan action',
    (tester) async {
      final service = FakeTickets()..pending = Completer<TicketScanResult>();
      late void Function(String) detect;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: EventTicketScanScreen(
            eventId: 'event',
            eventTitle: 'Event',
            service: service,
            scannerBuilder: (callback) {
              detect = callback;
              return const SizedBox();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      detect('qr');
      detect('qr');
      expect(service.scans, 1);
      service.pending!.complete(
        const TicketScanResult(TicketScanStatus.wrongEvent),
      );
      await tester.pumpAndSettle();
      expect(find.text('Wrong event'), findsOneWidget);
      detect('qr');
      expect(service.scans, 1);
      await tester.tap(find.text('Scan next ticket'));
      await tester.pump();
      service.pending = Completer<TicketScanResult>();
      detect('qr');
      service.pending!.completeError(StateError('offline'));
      await tester.pumpAndSettle();
      expect(service.scans, 2);
      expect(
        find.textContaining('Could not confirm admission.'),
        findsOneWidget,
      );
      expect(find.text('Valid — checked in'), findsNothing);
    },
  );
}
