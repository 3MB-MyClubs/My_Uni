import 'package:shared_preferences/shared_preferences.dart';

/// Tracks the password-free lifetime of the Supabase session on this device.
///
/// Supabase keeps access tokens short-lived and rotates refresh tokens. This
/// timestamp limits how long that refresh-token chain may restore the app
/// without asking for the password again.
class AuthSessionStore {
  static const sessionLifetime = Duration(days: 30);
  static const _startedAtKey = 'auth_session_started_at_v1';

  Future<void> startNewSession() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(
      _startedAtKey,
      DateTime.now().toUtc().millisecondsSinceEpoch,
    );
  }

  Future<bool> isSessionActive() async {
    final preferences = await SharedPreferences.getInstance();
    final startedAtMilliseconds = preferences.getInt(_startedAtKey);

    // Existing installs may already have a valid Supabase session from before
    // this device timestamp was introduced. Start their 30-day window now.
    if (startedAtMilliseconds == null) {
      await startNewSession();
      return true;
    }

    final startedAt = DateTime.fromMillisecondsSinceEpoch(
      startedAtMilliseconds,
      isUtc: true,
    );
    final age = DateTime.now().toUtc().difference(startedAt);
    return !age.isNegative && age < sessionLifetime;
  }

  Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_startedAtKey);
  }
}

final authSessionStore = AuthSessionStore();
