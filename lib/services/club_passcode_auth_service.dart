import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../l10n/app_localizations.dart';
import '../models/app_admin.dart';
import 'locale_service.dart';
import 'mock_data.dart';
import 'auth_session_store.dart';
import 'supabase_config.dart';

// No BuildContext is available this deep in the service layer, so failures
// are signaled as a code — callers resolve the localized message themselves
// via AppLocalizations.of(context)!.
enum ClubPasscodeAuthError {
  missingCredentials,
  invalidPasscodeFormat,
  invalidCredentials,
  notLinkedToClub,
  linkedClubNotFound,
  notConfigured,
}

class ClubPasscodeAuthResult {
  final bool success;
  final AppAdmin? admin;
  final ClubPasscodeAuthError? errorCode;

  const ClubPasscodeAuthResult._({
    required this.success,
    this.admin,
    this.errorCode,
  });

  factory ClubPasscodeAuthResult.success(AppAdmin admin) {
    return ClubPasscodeAuthResult._(success: true, admin: admin);
  }

  factory ClubPasscodeAuthResult.failure(ClubPasscodeAuthError errorCode) {
    return ClubPasscodeAuthResult._(success: false, errorCode: errorCode);
  }
}

class ClubPasscodeAuthService {
  Future<ClubPasscodeAuthResult> login({
    required String email,
    required String passcode,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final normalizedPasscode = passcode.trim();

    if (normalizedEmail.isEmpty || normalizedPasscode.isEmpty) {
      return ClubPasscodeAuthResult.failure(
        ClubPasscodeAuthError.missingCredentials,
      );
    }
    if (!RegExp(r'^[0-9]{8}$').hasMatch(normalizedPasscode)) {
      return ClubPasscodeAuthResult.failure(
        ClubPasscodeAuthError.invalidPasscodeFormat,
      );
    }

    if (SupabaseConfig.canUseMockAuth) {
      final mockAdmin = clubAdmins.firstWhere(
        (admin) =>
            admin.email.toLowerCase() == normalizedEmail &&
            admin.password == normalizedPasscode,
        orElse: () => AppAdmin(id: '', name: '', email: '', password: ''),
      );
      if (mockAdmin.id.isNotEmpty) {
        return ClubPasscodeAuthResult.success(mockAdmin);
      }
    }

    if (SupabaseConfig.isConfigured) {
      try {
        final client = Supabase.instance.client;
        final response = await client.auth.signInWithPassword(
          email: normalizedEmail,
          password: normalizedPasscode,
        );
        final authUser = response.user;
        if (authUser == null) {
          return ClubPasscodeAuthResult.failure(
            ClubPasscodeAuthError.invalidCredentials,
          );
        }

        final accountRows = await client
            .from('club_auth_accounts')
            .select('club_id')
            .eq('auth_user_id', authUser.id)
            .limit(1);
        final accounts = accountRows as List;
        if (accounts.isEmpty) {
          await client.auth.signOut();
          return ClubPasscodeAuthResult.failure(
            ClubPasscodeAuthError.notLinkedToClub,
          );
        }

        final account = Map<String, dynamic>.from(accounts.first as Map);
        final clubId = account['club_id']?.toString() ?? '';
        if (clubId.isEmpty) {
          await client.auth.signOut();
          return ClubPasscodeAuthResult.failure(
            ClubPasscodeAuthError.notLinkedToClub,
          );
        }

        final clubRows = await client
            .from('clubs')
            .select('id, name, email')
            .eq('id', clubId)
            .limit(1);
        final linkedClubs = clubRows as List;
        if (linkedClubs.isEmpty) {
          await client.auth.signOut();
          return ClubPasscodeAuthResult.failure(
            ClubPasscodeAuthError.linkedClubNotFound,
          );
        }

        final club = Map<String, dynamic>.from(linkedClubs.first as Map);
        final clubName =
            club['name']?.toString() ??
            lookupAppLocalizations(
              Locale(localeService.languageCode),
            ).clubFallbackName;
        final clubEmail = club['email']?.toString() ?? normalizedEmail;
        await authSessionStore.startNewSession();
        return ClubPasscodeAuthResult.success(
          AppAdmin(id: clubId, name: clubName, email: clubEmail, password: ''),
        );
      } on AuthException {
        return ClubPasscodeAuthResult.failure(
          ClubPasscodeAuthError.invalidCredentials,
        );
      } catch (error, stackTrace) {
        debugPrint('Club Supabase Auth login failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return ClubPasscodeAuthResult.failure(
          ClubPasscodeAuthError.notConfigured,
        );
      }
    }

    if (!SupabaseConfig.canUseMockAuth) {
      return ClubPasscodeAuthResult.failure(
        ClubPasscodeAuthError.notConfigured,
      );
    }
    return ClubPasscodeAuthResult.failure(
      ClubPasscodeAuthError.invalidCredentials,
    );
  }
}

final clubPasscodeAuthService = ClubPasscodeAuthService();
