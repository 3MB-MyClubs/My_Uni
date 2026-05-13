import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class SignupResult {
  final bool success;
  final String? error;

  const SignupResult.success() : success = true, error = null;
  const SignupResult.failure(this.error) : success = false;
}

class SignupInterest {
  final String id;
  final String name;

  const SignupInterest({required this.id, required this.name});
}

class SignupService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<List<SignupInterest>> fetchInterests() async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from('interests')
        .select('id, name')
        .order('name', ascending: true);

    return rows
        .map(
          (row) => SignupInterest(
            id: row['id'].toString(),
            name: row['name'].toString(),
          ),
        )
        .where((interest) => interest.id.isNotEmpty && interest.name.isNotEmpty)
        .toList();
  }

  Future<SignupResult> sendCode(String email) async {
    return _invoke('send-signup-code', {'email': email});
  }

  Future<SignupResult> verifyCode({
    required String email,
    required String code,
  }) async {
    return _invoke('verify-signup-code', {'email': email, 'code': code});
  }

  Future<SignupResult> completeSignup({
    required String email,
    required String password,
    required String fullName,
    required String major,
    required String year,
    required List<String> interestIds,
  }) async {
    return _invoke('complete-signup', {
      'email': email,
      'password': password,
      'full_name': fullName,
      'major': major,
      'year': year,
      'interest_ids': interestIds,
    });
  }

  Future<SignupResult> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final client = _client;
    if (client == null) {
      return const SignupResult.failure(
        'Supabase is not configured. Start the app with SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY.',
      );
    }

    try {
      final response = await client.functions.invoke(functionName, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        return SignupResult.failure(data['error'].toString());
      }
      return const SignupResult.success();
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] != null) {
        return SignupResult.failure(details['error'].toString());
      }
      return SignupResult.failure(
        error.reasonPhrase ?? 'Signup request failed.',
      );
    } catch (_) {
      return const SignupResult.failure(
        'Could not reach the signup server. Please try again.',
      );
    }
  }
}

final signupService = SignupService();
