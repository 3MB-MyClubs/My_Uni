import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_admin.dart';
import 'auth_session_store.dart';
import 'supabase_config.dart';

const String platformAdminEmail = 'dev3mb@gmail.com';

enum PlatformAdminAuthError {
  missingCredentials,
  invalidPasscodeFormat,
  invalidCredentials,
  unauthorized,
  notConfigured,
}

class PlatformAdminAuthResult {
  final bool success;
  final AppAdmin? admin;
  final PlatformAdminAuthError? errorCode;

  const PlatformAdminAuthResult._({
    required this.success,
    this.admin,
    this.errorCode,
  });

  factory PlatformAdminAuthResult.success(AppAdmin admin) {
    return PlatformAdminAuthResult._(success: true, admin: admin);
  }

  factory PlatformAdminAuthResult.failure(PlatformAdminAuthError errorCode) {
    return PlatformAdminAuthResult._(success: false, errorCode: errorCode);
  }
}

/// Authenticates the single app-wide administrator.
///
/// Knowing the hidden route or the expected email is not authorization. The
/// signed-in Supabase user must also be able to read its own singleton row in
/// `app_admins`; that RLS-protected assignment is the source of truth.
class PlatformAdminAuthService {
  const PlatformAdminAuthService();

  Future<PlatformAdminAuthResult> login({
    required String email,
    required String passcode,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPasscode = passcode.trim();

    if (normalizedEmail.isEmpty || normalizedPasscode.isEmpty) {
      return PlatformAdminAuthResult.failure(
        PlatformAdminAuthError.missingCredentials,
      );
    }
    if (!RegExp(r'^[0-9]{8}$').hasMatch(normalizedPasscode)) {
      return PlatformAdminAuthResult.failure(
        PlatformAdminAuthError.invalidPasscodeFormat,
      );
    }
    if (normalizedEmail != platformAdminEmail) {
      return PlatformAdminAuthResult.failure(
        PlatformAdminAuthError.invalidCredentials,
      );
    }
    if (!SupabaseConfig.isConfigured) {
      return PlatformAdminAuthResult.failure(
        PlatformAdminAuthError.notConfigured,
      );
    }

    final client = Supabase.instance.client;
    var signedIn = false;
    try {
      final response = await client.auth.signInWithPassword(
        email: normalizedEmail,
        password: normalizedPasscode,
      );
      final authUser = response.user;
      signedIn = authUser != null;
      if (authUser == null ||
          authUser.email?.trim().toLowerCase() != platformAdminEmail) {
        if (signedIn) await client.auth.signOut();
        return PlatformAdminAuthResult.failure(
          PlatformAdminAuthError.invalidCredentials,
        );
      }

      final rows = await client
          .from('app_admins')
          .select('auth_user_id, email')
          .eq('auth_user_id', authUser.id)
          .eq('email', platformAdminEmail)
          .limit(1);
      final assignments = rows as List;
      if (assignments.isEmpty) {
        await client.auth.signOut();
        return PlatformAdminAuthResult.failure(
          PlatformAdminAuthError.unauthorized,
        );
      }

      await authSessionStore.startNewSession();
      return PlatformAdminAuthResult.success(
        AppAdmin(
          id: authUser.id,
          name: 'ClubUp Admin',
          email: platformAdminEmail,
          password: '',
          isPlatformAdmin: true,
        ),
      );
    } on AuthException {
      return PlatformAdminAuthResult.failure(
        PlatformAdminAuthError.invalidCredentials,
      );
    } catch (error, stackTrace) {
      if (signedIn) {
        try {
          await client.auth.signOut();
        } catch (_) {
          // The local session is cleared by signOut before remote revocation.
        }
      }
      debugPrint('Platform admin Supabase Auth login failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return PlatformAdminAuthResult.failure(
        PlatformAdminAuthError.notConfigured,
      );
    }
  }
}

const platformAdminAuthService = PlatformAdminAuthService();
