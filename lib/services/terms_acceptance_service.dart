import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

/// Stores acceptance of the current ClubUp Terms of Use on this installation.
///
/// Changing [currentVersion] presents the agreement again before any account
/// can register or sign in.
class TermsAcceptanceService {
  TermsAcceptanceService({SupabaseClient? Function()? clientProvider})
    : _clientProvider = clientProvider;

  static const currentVersion = '2026-07-18';
  static const _preferenceKey = 'accepted_terms_version';

  final SupabaseClient? Function()? _clientProvider;

  bool _accepted = false;

  bool get hasAcceptedCurrentTerms => _accepted;

  SupabaseClient? get _client {
    if (_clientProvider != null) return _clientProvider();
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } on AssertionError {
      // Unit tests and local-only callers may use this service before the
      // application has initialized Supabase.
      return null;
    }
  }

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _accepted = preferences.getString(_preferenceKey) == currentVersion;
  }

  Future<void> accept({bool requireAuthenticatedRecord = false}) async {
    final recorded = await _recordForCurrentUser();
    if (requireAuthenticatedRecord && !recorded) {
      throw StateError('An authenticated user is required to accept Terms.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, currentVersion);
    _accepted = true;
  }

  /// Replays a device-local acceptance after login. The database RPC is
  /// idempotent, so calling this on every authenticated session is safe and
  /// also covers users who accepted a new version before signing in.
  Future<void> syncForCurrentUser() async {
    if (!_accepted) return;
    await _recordForCurrentUser();
  }

  Future<bool> _recordForCurrentUser() async {
    final client = _client;
    if (client?.auth.currentUser == null) return false;

    await client!.rpc(
      'record_terms_acceptance',
      params: {'p_terms_version': currentVersion},
    );
    return true;
  }
}

final termsAcceptanceService = TermsAcceptanceService();
