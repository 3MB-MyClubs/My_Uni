import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_application_1/services/apple_wallet_ticket_service.dart';
import 'package:flutter_application_1/services/pkpass_ticket_service.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const androidChannel = MethodChannel('ku_app/pkpass_ticket');
  const appleChannel = MethodChannel('ku_app/apple_wallet_ticket');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    for (final channel in [androidChannel, appleChannel]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
    }
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    for (final channel in [androidChannel, appleChannel]) {
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null);
    }
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    test(
      '$platform passes downloaded bytes unchanged to the native wallet',
      () async {
        debugDefaultTargetPlatformOverride = platform;
        final bytes = Uint8List.fromList([80, 75, 3, 4, 255, 0, 128]);
        final client = SupabaseClient(
          'https://example.test',
          'anon',
          httpClient: MockClient((request) async {
            expect(request.url.path, '/functions/v1/apple-wallet-ticket');
            expect(request.method.toUpperCase(), 'POST');
            expect(jsonDecode(request.body), {'ticketId': 'ticket-id'});
            expect(request.headers['Authorization'], isNotEmpty);
            return http.Response.bytes(
              bytes,
              200,
              headers: {'content-type': 'application/octet-stream'},
            );
          }),
        );
        addTearDown(client.dispose);
        if (platform == TargetPlatform.android) {
          await PkpassTicketService(client: client).addTicket('ticket-id');
        } else {
          await AppleWalletTicketService(client: client).addTicket('ticket-id');
        }
        expect(calls, hasLength(1));
        expect(calls.single.method, 'addPass');
        expect(calls.single.arguments, bytes);
      },
    );
  }

  for (final status in [200, 401, 404, 500]) {
    test('empty or denied pass ($status) never opens a pass app', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final client = SupabaseClient(
        'https://example.test',
        'anon',
        httpClient: MockClient(
          (_) async => http.Response(
            status == 200 ? '' : '{"error":"Unavailable"}',
            status,
            headers: {
              'content-type': status == 200
                  ? 'application/octet-stream'
                  : 'application/json',
            },
          ),
        ),
      );
      addTearDown(client.dispose);
      await expectLater(
        PkpassTicketService(client: client).addTicket('ticket-id'),
        throwsA(anything),
      );
      expect(calls, isEmpty);
    });
  }
}
