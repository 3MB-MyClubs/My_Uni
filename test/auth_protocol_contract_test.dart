import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const apiKey = 'released-anon-key';

  test('released app auth request contracts remain unchanged', () async {
    final requests = <http.Request>[];
    final mockClient = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/auth/v1/token') {
        return http.Response(jsonEncode({'message': 'contract probe'}), 400);
      }
      return http.Response(jsonEncode({'success': true}), 200);
    });
    final client = SupabaseClient(
      'https://contract.invalid',
      apiKey,
      httpClient: mockClient,
    );
    addTearDown(client.dispose);

    try {
      await client.auth.signInWithPassword(
        email: 'student@ku.edu.tr',
        password: '123456',
      );
    } catch (_) {
      // The probe server rejects only after recording the exact Auth request.
    }

    final legacyCalls = <String, Map<String, dynamic>>{
      'send-signup-code': {'email': 'student@ku.edu.tr'},
      'verify-signup-code': {'email': 'student@ku.edu.tr', 'code': '123456'},
      'complete-signup': {
        'email': 'student@ku.edu.tr',
        'password': '123456',
        'full_name': 'Released Client',
        'major_id': 'major-id',
        'academic_year_id': 'year-id',
        'interest_ids': <String>[],
        'terms_accepted': true,
        'terms_version': '2026-08-01',
      },
      'send-password-reset-code': {'email': 'student@ku.edu.tr'},
      'verify-password-reset-code': {
        'email': 'student@ku.edu.tr',
        'code': '123456',
      },
      'complete-password-reset': {
        'email': 'student@ku.edu.tr',
        'password': '654321',
      },
    };

    for (final call in legacyCalls.entries) {
      await client.functions.invoke(call.key, body: call.value);
    }

    final login = requests.first;
    expect(login.method, 'POST');
    expect(login.url.path, '/auth/v1/token');
    expect(login.url.queryParameters, {'grant_type': 'password'});
    expect(jsonDecode(login.body), {
      'email': 'student@ku.edu.tr',
      'password': '123456',
      'gotrue_meta_security': {'captcha_token': null},
    });

    for (final request in requests.skip(1)) {
      final endpoint = request.url.pathSegments.last;
      expect(request.method.toUpperCase(), 'POST');
      expect(request.headers['apikey'], apiKey);
      expect(request.headers['authorization'], 'Bearer $apiKey');
      expect(jsonDecode(request.body), legacyCalls[endpoint]);
    }
    expect(requests, hasLength(7));
  });

  test('new app uses only the six v2 endpoint contracts', () async {
    final signup = File('lib/services/signup_service.dart').readAsStringSync();
    final reset = File(
      'lib/services/password_reset_service.dart',
    ).readAsStringSync();

    for (final endpoint in const [
      'send-signup-code-v2',
      'verify-signup-code-v2',
      'complete-signup-v2',
    ]) {
      expect(signup, contains("'$endpoint'"));
    }
    for (final endpoint in const [
      'send-password-reset-code-v2',
      'verify-password-reset-code-v2',
      'complete-password-reset-v2',
    ]) {
      expect(reset, contains("'$endpoint'"));
    }
    expect(signup, contains("'capability': capability"));
    expect(reset, contains("'capability': capability"));
  });

  test('v1 and v2 Edge Functions use isolated protocol state', () {
    final legacyFiles = [
      'send-signup-code',
      'verify-signup-code',
      'complete-signup',
      'send-password-reset-code',
      'verify-password-reset-code',
      'complete-password-reset',
    ];
    final v2Files = legacyFiles.map((name) => '$name-v2');
    final legacySource = legacyFiles
        .map(
          (name) =>
              File('supabase/functions/$name/index.ts').readAsStringSync(),
        )
        .join('\n');
    final v2Source = v2Files
        .map(
          (name) =>
              File('supabase/functions/$name/index.ts').readAsStringSync(),
        )
        .join('\n');

    expect(legacySource, contains('_legacy'));
    expect(legacySource, isNot(contains('challenge_v2')));
    expect(legacySource, isNot(contains('capability_v2')));
    expect(v2Source, contains('challenge_v2'));
    expect(v2Source, contains('capability_v2'));
    expect(v2Source, isNot(contains('pending_signups')));
    expect(v2Source, isNot(contains('pending_password_resets')));
  });

  test('legacy auth endpoints keep pre-429 response contracts', () {
    final legacyFiles = [
      'send-signup-code',
      'verify-signup-code',
      'complete-signup',
      'send-password-reset-code',
      'verify-password-reset-code',
      'complete-password-reset',
    ];
    final legacySource = legacyFiles
        .map(
          (name) =>
              File('supabase/functions/$name/index.ts').readAsStringSync(),
        )
        .join('\n');

    expect(legacySource, isNot(contains('rateLimitResponse(')));
    expect(legacySource, isNot(contains('status: 429')));
    expect(legacySource, contains('TEMPORARY V1 COMPATIBILITY'));
  });

  test('v2 reset consumes once, revokes sessions, then updates password', () {
    final source = File(
      'supabase/functions/complete-password-reset-v2/index.ts',
    ).readAsStringSync();
    final consume = source.indexOf('consume_password_reset_capability_v2');
    final revoke = source.indexOf('revoke_user_sessions');
    final update = source.indexOf('updateUserById');

    expect(consume, greaterThanOrEqualTo(0));
    expect(revoke, greaterThan(consume));
    expect(update, greaterThan(revoke));
  });
}
