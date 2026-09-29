import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/services/event_ticket_service.dart';
import 'package:flutter_application_1/services/guest_session.dart';

void main() {
  final token = 'a' * 64;
  final row = {
    'id': 'ticket-id',
    'token': token,
    'display_code': 'AB12CD',
    'revoked_at': null,
    'used_at': null,
  };
  tearDown(guestSession.end);

  test('QR is a versioned bearer token, rejects event share links and IDs', () {
    expect(EventTicketService.tokenFromQr('clubup-ticket:v1:$token'), token);
    for (final payload in [
      'https://clubup.app/event/event-id',
      'profile-id',
      token,
      'clubup-ticket:v2:$token',
      'clubup-ticket:v1:${'a' * 63}',
      'clubup-ticket:v1:$token\n',
    ]) {
      expect(EventTicketService.tokenFromQr(payload), isNull);
    }
    expect(EventTicket.fromJson(row).qrPayload, 'clubup-ticket:v1:$token');
    expect(EventTicket.fromJson(row).displayCode, 'AB12CD');
  });

  test(
    'issuance and reissue use server identity and explicit rotation',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.test',
        'anon',
        httpClient: MockClient((r) async {
          expect(r.headers['Accept'], 'application/vnd.pgrst.object+json');
          requests.add(r);
          return http.Response(
            jsonEncode(row),
            200,
            request: r,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = EventTicketService(client: client);
      await service.issue('event', 'holder');
      await service.issue('event', 'holder', reissue: true);
      expect(
        requests.map((r) => r.url.path),
        everyElement('/rest/v1/rpc/issue_event_ticket'),
      );
      expect(jsonDecode(requests[0].body), {
        'p_event_id': 'event',
        'p_profile_id': 'holder',
        'p_reissue': false,
      });
      expect(jsonDecode(requests[1].body)['p_reissue'], true);
    },
  );

  test(
    'scan submits only selected event and secret; parses all server outcomes',
    () async {
      final outcomes = [
        'checked_in',
        'already_used',
        'revoked',
        'wrong_event',
        'invalid',
      ];
      var calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'anon',
        httpClient: MockClient((r) async {
          expect(r.url.path, '/rest/v1/rpc/scan_event_ticket');
          expect(jsonDecode(r.body), {'p_event_id': 'event', 'p_token': token});
          return http.Response(
            jsonEncode({'status': outcomes[calls++]}),
            200,
            request: r,
          );
        }),
      );
      addTearDown(client.dispose);
      final service = EventTicketService(client: client);
      for (final status in TicketScanStatus.values) {
        expect(
          (await service.scan('event', 'clubup-ticket:v1:$token')).status,
          status,
        );
      }
      expect(
        (await service.scan('event', 'profile-id')).status,
        TicketScanStatus.invalid,
      );
      expect(calls, 5);
    },
  );

  test(
    'manual code normalizes input and calls the dedicated admission RPC',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'anon',
        httpClient: MockClient((request) async {
          calls++;
          expect(request.url.path, '/rest/v1/rpc/scan_event_ticket_code');
          expect(jsonDecode(request.body), {
            'p_event_id': 'event',
            'p_code': 'AB12CD',
          });
          return http.Response(
            jsonEncode({'status': 'checked_in', 'profile_id': 'holder'}),
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(client.dispose);
      final service = EventTicketService(client: client);
      expect(EventTicketService.normalizeDisplayCode(' ab12cd '), 'AB12CD');
      expect(EventTicketService.normalizeDisplayCode('ABCDEF'), isNull);
      expect(EventTicketService.normalizeDisplayCode('123456'), isNull);
      expect(EventTicketService.normalizeDisplayCode('AB12C'), isNull);
      expect(
        (await service.scanCode('event', ' ab12cd ')).status,
        TicketScanStatus.checkedIn,
      );
      expect(
        (await service.scanCode('event', 'short')).status,
        TicketScanStatus.invalid,
      );
      expect(calls, 1);
    },
  );

  test(
    'network failure and unknown responses never become admission success',
    () async {
      var calls = 0;
      final client = SupabaseClient(
        'https://example.test',
        'anon',
        httpClient: MockClient((r) async {
          calls++;
          throw http.ClientException('offline');
        }),
      );
      addTearDown(client.dispose);
      final service = EventTicketService(client: client);
      await expectLater(
        service.scan('event', 'clubup-ticket:v1:$token'),
        throwsA(isA<http.ClientException>()),
      );
      expect(calls, 1);
      expect(
        () => TicketScanResult.fromJson({'status': 'something-new'}),
        throwsFormatException,
      );
    },
  );

  test('latest ticket controls attendee icon state', () async {
    final client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: MockClient((request) async {
        expect(request.url.path, '/rest/v1/event_tickets');
        return http.Response(
          jsonEncode([
            {
              'profile_id': 'reissued',
              'display_code': 'AB12CD',
              'used_at': null,
              'revoked_at': null,
            },
            {
              'profile_id': 'used',
              'display_code': 'XY34ZT',
              'used_at': '2026-09-25T11:34:00Z',
              'revoked_at': null,
            },
            {
              'profile_id': 'cancelled',
              'display_code': 'PQ56RS',
              'used_at': null,
              'revoked_at': '2026-09-25T11:35:00Z',
            },
            {
              'profile_id': 'reissued',
              'display_code': 'JK78LM',
              'used_at': '2026-09-24T11:34:00Z',
              'revoked_at': '2026-09-25T11:35:00Z',
            },
          ]),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);
    final states = await EventTicketService(
      client: client,
    ).fetchTicketStates('event');
    expect(states['reissued']?.state, EventTicketState.active);
    expect(states['reissued']?.displayCode, 'AB12CD');
    expect(states['used']?.state, EventTicketState.used);
    expect(states['used']?.displayCode, 'XY34ZT');
    expect(states['cancelled']?.state, EventTicketState.revoked);
    expect(states['cancelled']?.displayCode, 'PQ56RS');
  });

  test('guest mode cannot issue tickets even with a client', () async {
    final client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: MockClient((_) async {
        fail('Guest must never reach Supabase');
      }),
    );
    addTearDown(client.dispose);
    guestSession.begin();
    await expectLater(
      EventTicketService(client: client).issue('event', 'holder'),
      throwsStateError,
    );
  });
}
