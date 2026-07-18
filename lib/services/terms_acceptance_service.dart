import 'package:shared_preferences/shared_preferences.dart';

/// Stores acceptance of the current ClubUp Terms of Use on this installation.
///
/// Changing [currentVersion] presents the agreement again before any account
/// can register or sign in.
class TermsAcceptanceService {
  static const currentVersion = '2026-07-18';
  static const _preferenceKey = 'accepted_terms_version';

  bool _accepted = false;

  bool get hasAcceptedCurrentTerms => _accepted;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _accepted = preferences.getString(_preferenceKey) == currentVersion;
  }

  Future<void> accept() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_preferenceKey, currentVersion);
    _accepted = true;
  }
}

final termsAcceptanceService = TermsAcceptanceService();
