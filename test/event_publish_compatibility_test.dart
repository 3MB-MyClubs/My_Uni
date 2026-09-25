import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/models/event.dart';
import 'package:flutter_application_1/services/guest_session.dart';
import 'package:flutter_application_1/services/supabase_event_service.dart';

void main() {
  tearDown(guestSession.end);

  Event event({bool ticketed = false}) => Event(
    id: '550e8400-e29b-41d4-a716-446655440000',
    clubId: '550e8400-e29b-41d4-a716-446655440001',
    title: 'Campus event',
    description: 'Test',
    location: 'Campus',
    dateTime: DateTime.utc(2030, 1, 1, 12),
    endTime: DateTime.utc(2030, 1, 1, 13),
    attendeeUserIds: const [],
    isTicketed: ticketed,
  );

  http.Response missingV4(http.Request request) => http.Response(
    jsonEncode({
      'code': 'PGRST202',
      'message':
          'Could not find the public.create_club_event_transactional_v4 function in the schema cache',
    }),
    404,
    request: request,
    headers: {'content-type': 'application/json'},
  );

  test('ordinary event publishes through v3 when v4 is absent', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/create_club_event_transactional_v4')) {
          return missingV4(request);
        }
        return http.Response(
          jsonEncode({
            'id': '550e8400-e29b-41d4-a716-446655440000',
            'club_id': '550e8400-e29b-41d4-a716-446655440001',
            'title': 'Campus event',
            'starts_at': '2030-01-01T12:00:00Z',
            'ends_at': '2030-01-01T13:00:00Z',
            'is_ticketed': false,
          }),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    final saved = await SupabaseEventService(
      client: client,
    ).createEvent(event());

    expect(saved.title, 'Campus event');
    expect(saved.isTicketed, false);
    expect(requests.map((request) => request.url.path), [
      '/rest/v1/rpc/create_club_event_transactional_v4',
      '/rest/v1/rpc/create_club_event_transactional_v3',
    ]);
    expect(jsonDecode(requests.first.body)['p_is_ticketed'], false);
    expect(jsonDecode(requests.last.body), isNot(contains('p_is_ticketed')));
  });

  test('ticketed event never falls back to v3', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: MockClient((request) async {
        requests.add(request);
        return missingV4(request);
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseEventService(client: client).createEvent(event(ticketed: true)),
      throwsA(
        isA<PostgrestException>().having((e) => e.code, 'code', 'PGRST202'),
      ),
    );
    expect(requests, hasLength(1));
  });

  test('ordinary event does not hide an unrelated database error', () async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://example.test',
      'anon',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({'code': '42501', 'message': 'permission denied'}),
          403,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(client.dispose);

    await expectLater(
      SupabaseEventService(client: client).createEvent(event()),
      throwsA(isA<PostgrestException>().having((e) => e.code, 'code', '42501')),
    );
    expect(requests, hasLength(1));
  });
}
