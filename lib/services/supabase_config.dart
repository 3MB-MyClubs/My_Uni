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

  static String get clientKey =>
      publishableKey.isNotEmpty ? publishableKey : anonKey;

  static bool get isConfigured => url.isNotEmpty && clientKey.isNotEmpty;
}
