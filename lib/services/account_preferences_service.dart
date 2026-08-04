import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_config.dart';

typedef AccountPreferencesRowLoader =
    Future<Map<String, dynamic>?> Function(String userId);
typedef AccountPreferencesRowWriter =
    Future<void> Function(String userId, Map<String, dynamic> values);

@immutable
class AccountPreferences {
  final String? languageCode;
  final bool? isDark;

  const AccountPreferences({this.languageCode, this.isDark});

  factory AccountPreferences.fromRow(Map<String, dynamic>? row) {
    final language = row?['language_code'];
    final theme = row?['theme_mode'];
    return AccountPreferences(
      languageCode: language == 'en' || language == 'tr'
          ? language as String
          : null,
      isDark: theme == 'dark'
          ? true
          : theme == 'light'
          ? false
          : null,
    );
  }

  AccountPreferences copyWith({String? languageCode, bool? isDark}) {
    return AccountPreferences(
      languageCode: languageCode ?? this.languageCode,
      isDark: isDark ?? this.isDark,
    );
  }
}

/// Account-scoped language and appearance preferences.
///
/// Hive remains the fast local cache used to paint the first frame. This
/// service is the source of truth after authentication, so the same choices
/// follow a Supabase account to every device.
class AccountPreferencesService extends ChangeNotifier {
  AccountPreferencesService({
    SupabaseClient? Function()? clientProvider,
    String? Function()? userIdProvider,
    AccountPreferencesRowLoader? rowLoader,
    AccountPreferencesRowWriter? rowWriter,
  }) : _clientProvider = clientProvider,
       _userIdProvider = userIdProvider,
       _rowLoader = rowLoader,
       _rowWriter = rowWriter;

  final SupabaseClient? Function()? _clientProvider;
  final String? Function()? _userIdProvider;
  final AccountPreferencesRowLoader? _rowLoader;
  final AccountPreferencesRowWriter? _rowWriter;

  AccountPreferences _preferences = const AccountPreferences();
  String? _loadedUserId;

  AccountPreferences get preferences => _preferences;
  bool get hasLanguagePreference => _preferences.languageCode != null;
  bool get hasThemePreference => _preferences.isDark != null;
  String? get authenticatedUserId => _currentUserId;
  bool get hasAuthenticatedUser => _currentUserId != null;
  bool get isLoadedForCurrentUser {
    final userId = _currentUserId;
    return userId != null && _loadedUserId == userId;
  }

  SupabaseClient? get _client {
    if (_clientProvider != null) return _clientProvider();
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String? get _currentUserId {
    final provided = _userIdProvider?.call();
    if (provided != null) return provided;
    return _client?.auth.currentUser?.id;
  }

  Future<AccountPreferences> loadForCurrentUser() async {
    final userId = _currentUserId;
    if (userId == null) {
      clear();
      return const AccountPreferences();
    }

    final row = _rowLoader != null
        ? await _rowLoader(userId)
        : await _loadSupabaseRow(userId);

    // Do not let a late response from the previous account overwrite the next
    // account's state during a fast logout/login sequence.
    if (_currentUserId != userId) return const AccountPreferences();

    _preferences = AccountPreferences.fromRow(row);
    _loadedUserId = userId;
    notifyListeners();
    return _preferences;
  }

  Future<void> saveLanguage(String code) async {
    if (code != 'en' && code != 'tr') return;
    if (_currentUserId == null) return;
    await _save({'language_code': code});
    _preferences = _preferences.copyWith(languageCode: code);
    notifyListeners();
  }

  Future<void> saveTheme(bool isDark) async {
    if (_currentUserId == null) return;
    await _save({'theme_mode': isDark ? 'dark' : 'light'});
    _preferences = _preferences.copyWith(isDark: isDark);
    notifyListeners();
  }

  void clear() {
    final changed =
        _loadedUserId != null ||
        _preferences.languageCode != null ||
        _preferences.isDark != null;
    _loadedUserId = null;
    _preferences = const AccountPreferences();
    if (changed) notifyListeners();
  }

  Future<Map<String, dynamic>?> _loadSupabaseRow(String userId) async {
    final client = _client;
    if (client == null) return null;
    final row = await client
        .from('user_preferences')
        .select('language_code, theme_mode')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : Map<String, dynamic>.from(row);
  }

  Future<void> _save(Map<String, dynamic> values) async {
    final userId = _currentUserId;
    if (userId == null) return;

    if (_rowWriter != null) {
      await _rowWriter(userId, values);
    } else {
      final client = _client;
      if (client == null) return;
      await client.from('user_preferences').upsert({
        'user_id': userId,
        ...values,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    }
    _loadedUserId = userId;
  }
}

final accountPreferencesService = AccountPreferencesService();
