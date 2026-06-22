import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_admin.dart';
import 'mock_data.dart';
import 'supabase_config.dart';

class ClubPasscodeAuthResult {
  final bool success;
  final AppAdmin? admin;
  final String? error;

  const ClubPasscodeAuthResult._({
    required this.success,
    this.admin,
    this.error,
  });

  factory ClubPasscodeAuthResult.success(AppAdmin admin) {
    return ClubPasscodeAuthResult._(success: true, admin: admin);
  }

  factory ClubPasscodeAuthResult.failure(String error) {
    return ClubPasscodeAuthResult._(success: false, error: error);
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
        'Club email and passcode are required',
      );
    }
    if (!RegExp(r'^[0-9]{8}$').hasMatch(normalizedPasscode)) {
      return ClubPasscodeAuthResult.failure(
        'Passcode must be exactly 8 digits',
      );
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
            'Invalid club email or passcode',
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
            'This login is not linked to a club',
          );
        }

        final account = Map<String, dynamic>.from(accounts.first as Map);
        final clubId = account['club_id']?.toString() ?? '';
        if (clubId.isEmpty) {
          await client.auth.signOut();
          return ClubPasscodeAuthResult.failure(
            'This login is not linked to a club',
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
          return ClubPasscodeAuthResult.failure('Linked club was not found');
        }

        final club = Map<String, dynamic>.from(linkedClubs.first as Map);
        final clubName = club['name']?.toString() ?? 'Club';
        final clubEmail = club['email']?.toString() ?? normalizedEmail;
        return ClubPasscodeAuthResult.success(
          AppAdmin(id: clubId, name: clubName, email: clubEmail, password: ''),
        );
      } on AuthException {
        return ClubPasscodeAuthResult.failure('Invalid club email or passcode');
      } catch (error, stackTrace) {
        debugPrint('Club Supabase Auth login failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return ClubPasscodeAuthResult.failure(
          'Club login is not ready. Check club_auth_accounts in Supabase.',
        );
      }
    }

    final mockAdmin = clubAdmins.firstWhere(
      (admin) =>
          admin.email.toLowerCase() == normalizedEmail &&
          admin.password == normalizedPasscode,
      orElse: () => AppAdmin(id: '', name: '', email: '', password: ''),
    );
    if (mockAdmin.id.isNotEmpty) {
      return ClubPasscodeAuthResult.success(mockAdmin);
    }
    return ClubPasscodeAuthResult.failure('Invalid club email or passcode');
  }
}

final clubPasscodeAuthService = ClubPasscodeAuthService();
