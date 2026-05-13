import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

class PasswordResetResult {
  final bool success;
  final String? error;

  const PasswordResetResult.success() : success = true, error = null;
  const PasswordResetResult.failure(this.error) : success = false;
}

class PasswordResetService {
  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<PasswordResetResult> sendCode(String email) {
    return _invoke('send-password-reset-code', {'email': email});
  }

  Future<PasswordResetResult> verifyCode({
    required String email,
    required String code,
  }) {
    return _invoke('verify-password-reset-code', {
      'email': email,
      'code': code,
    });
  }

  Future<PasswordResetResult> updatePassword({
    required String email,
    required String password,
  }) {
    return _invoke('complete-password-reset', {
      'email': email,
      'password': password,
    });
  }

  Future<PasswordResetResult> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final client = _client;
    if (client == null) {
      return const PasswordResetResult.failure('Supabase is not configured.');
    }

    try {
      final response = await client.functions.invoke(functionName, body: body);
      final data = response.data;
      if (data is Map && data['error'] != null) {
        return PasswordResetResult.failure(data['error'].toString());
      }
      return const PasswordResetResult.success();
    } on FunctionException catch (error) {
      final details = error.details;
      if (details is Map && details['error'] != null) {
        return PasswordResetResult.failure(details['error'].toString());
      }
      return PasswordResetResult.failure(
        error.reasonPhrase ?? 'Password reset request failed.',
      );
    } catch (_) {
      return const PasswordResetResult.failure(
        'Could not reach the password reset server. Please try again.',
      );
    }
  }
}

final passwordResetService = PasswordResetService();
