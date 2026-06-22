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
        final rows = await Supabase.instance.client.rpc(
          'verify_club_passcode',
          params: {
            'p_email': normalizedEmail,
            'p_passcode': normalizedPasscode,
          },
        );
        final list = rows is List ? rows : const [];
        if (list.isEmpty) {
          return ClubPasscodeAuthResult.failure(
            'Invalid club email or passcode',
          );
        }
        final row = Map<String, dynamic>.from(list.first as Map);
        final clubId = row['club_id']?.toString() ?? '';
        final clubName = row['club_name']?.toString() ?? 'Club';
        final clubEmail = row['club_email']?.toString() ?? normalizedEmail;
        if (clubId.isEmpty) {
          return ClubPasscodeAuthResult.failure(
            'Invalid club email or passcode',
          );
        }
        return ClubPasscodeAuthResult.success(
          AppAdmin(id: clubId, name: clubName, email: clubEmail, password: ''),
        );
      } catch (error, stackTrace) {
        debugPrint('Club passcode login failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        return ClubPasscodeAuthResult.failure(
          'Club login is not ready. Check the Supabase passcode SQL.',
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
