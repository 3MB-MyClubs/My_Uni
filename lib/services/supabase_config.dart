import 'dart:convert';

class SupabaseConfig {
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://bfntlbisipxgzxdmwxkz.supabase.co',
  );
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: 'sb_publishable_0VAHkbqINauMlCHx-EcSxg_9N84scEJ',
  );
  static const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const allowMockAuth = bool.fromEnvironment(
    'ALLOW_MOCK_AUTH',
    defaultValue: false,
  );

  static String get clientKey =>
      publishableKey.isNotEmpty ? publishableKey : anonKey;

  static bool get isConfigured => configurationError == null;

  /// Demo credentials are opt-in and can never silently become a production
  /// fallback when Supabase is unavailable or misconfigured.
  static bool get canUseMockAuth => allowMockAuth;

  static String? get configurationError {
    if (url.isEmpty && clientKey.isEmpty) {
      return 'SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY are required.';
    }

    final parsedUrl = Uri.tryParse(url);
    if (parsedUrl == null ||
        parsedUrl.scheme != 'https' ||
        parsedUrl.host.isEmpty) {
      return 'SUPABASE_URL must be a valid HTTPS URL.';
    }
    if (!_isSafePublicClientKey(clientKey)) {
      return 'Use a Supabase publishable/anon key in the client; secret and '
          'service-role keys are forbidden.';
    }
    return null;
  }

  static void validate() {
    final error = configurationError;
    if (error != null) throw StateError(error);
  }

  static bool _isSafePublicClientKey(String key) {
    if (key.startsWith('sb_publishable_')) return true;
    if (key.startsWith('sb_secret_') || key.isEmpty) return false;

    // Legacy anon keys are JWTs. Decode only their public payload so an
    // accidentally supplied service_role token fails closed before startup.
    final parts = key.split('.');
    if (parts.length != 3) return false;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      return payload is Map && payload['role'] == 'anon';
    } catch (_) {
      return false;
    }
  }
}
