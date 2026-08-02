import 'dart:io';

import 'package:flutter/widgets.dart' show Locale;
import 'package:supabase_flutter/supabase_flutter.dart';

import 'academic_year_options.dart';
import '../l10n/app_localizations.dart';
import 'auth_service.dart';
import 'locale_service.dart';
import 'student_profile_service.dart';
import 'supabase_config.dart';
import 'terms_acceptance_service.dart';

class SignupResult {
  final bool success;
  final String? error;

  const SignupResult.success() : success = true, error = null;
  const SignupResult.failure(this.error) : success = false;
}

class SignupLookupItem {
  final String id;
  final String name;

  const SignupLookupItem({required this.id, required this.name});
}

class SignupService {
  // No BuildContext is available this deep in the service layer; these
  // fallbacks never come from the server, so they're resolved here via the
  // current locale rather than pushed up to a caller that may not exist yet.
  AppLocalizations get _l10n =>
      lookupAppLocalizations(Locale(localeService.languageCode));

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    return Supabase.instance.client;
  }

  Future<List<SignupLookupItem>> fetchInterests() async {
    return _fetchLookupItems('interests');
  }

  Future<List<SignupLookupItem>> fetchMajors() async {
    return _fetchLookupItems('majors');
  }

  Future<List<SignupLookupItem>> fetchAcademicYears() async {
    final years = await _fetchLookupItems('academic_years');
    return ensurePrepAcademicYear(
      years,
      nameOf: (year) => year.name,
      createPrep: () => const SignupLookupItem(
        id: prepAcademicYearId,
        name: prepAcademicYearName,
      ),
    );
  }

  Future<List<SignupLookupItem>> _fetchLookupItems(String tableName) async {
    final client = _client;
    if (client == null) return const [];

    final rows = await client
        .from(tableName)
        .select('id, name')
        .eq('is_active', true)
        .order('sort_order', ascending: true);

    return rows
        .map(
          (row) => SignupLookupItem(
            id: row['id'].toString(),
            name: row['name'].toString(),
          ),
        )
        .where((item) => item.id.isNotEmpty && item.name.isNotEmpty)
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
    required String majorId,
    required String academicYearId,
    required List<String> interestIds,
    String? imagePath,
  }) async {
    if (!authService.isValidNewStudentPassword(password)) {
      return SignupResult.failure(_l10n.studentPasswordRule);
    }

    final result = await _invoke('complete-signup', {
      'email': email,
      'password': password,
      'full_name': fullName,
      'major_id': majorId,
      'academic_year_id': academicYearId,
      'interest_ids': interestIds,
    });
    if (!result.success) return result;

    try {
      final client = _client;
      if (client == null) return result;
      final authResponse = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      try {
        final userId = authResponse.user?.id;
        if (userId == null || userId.isEmpty) {
          return SignupResult.failure(_l10n.signupRequestFailed);
        }

        // The final signup button is disabled until the Terms checkbox is
        // selected. Persist that acceptance while this new account is
        // authenticated, even when the student did not choose an avatar.
        await termsAcceptanceService.accept(requireAuthenticatedRecord: true);

        if (imagePath != null && imagePath.isNotEmpty) {
          try {
            await studentProfileService.uploadAvatar(
              userId: userId,
              bytes: await File(imagePath).readAsBytes(),
            );
          } catch (_) {
            // The account and its Terms acceptance are already durable. The
            // optional avatar can be added later from Edit Profile.
          }
        }
      } finally {
        try {
          await client.auth.signOut();
        } catch (_) {
          // Do not turn a completed signup into a failure solely because the
          // temporary upload/acceptance session could not be cleared.
        }
      }
    } catch (_) {
      return SignupResult.failure(_l10n.signupRequestFailed);
    }
    return result;
  }

  Future<SignupResult> _invoke(
    String functionName,
    Map<String, dynamic> body,
  ) async {
    final client = _client;
    if (client == null) {
      return SignupResult.failure(_l10n.signupServerNotConfigured);
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
        error.reasonPhrase ?? _l10n.signupRequestFailed,
      );
    } catch (_) {
      return SignupResult.failure(_l10n.couldNotReachSignupServer);
    }
  }
}

final signupService = SignupService();
