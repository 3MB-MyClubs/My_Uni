import 'package:flutter/widgets.dart' show Locale;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import 'locale_service.dart';
import 'supabase_config.dart';

class PasswordResetResult {
  final bool success;
  final String? error;

  const PasswordResetResult.success() : success = true, error = null;
  const PasswordResetResult.failure(this.error) : success = false;
}

class PasswordResetService {
  // No BuildContext is available this deep in the service layer; these two
  // fallbacks never come from the server, so they're resolved here via the
  // current locale rather than pushed up to a caller that may not exist yet.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(localeService.languageCode));

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
      return PasswordResetResult.failure(_l10n.supabaseNotConfigured);
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
        error.reasonPhrase ?? _l10n.passwordResetRequestFailed,
      );
    } catch (_) {
      return PasswordResetResult.failure(_l10n.couldNotReachResetServer);
    }
  }
}

final passwordResetService = PasswordResetService();
