import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_config.dart';

/// Tracks whether a user has been through the first-run "campus tour"
/// onboarding, and carries the replay / deep-link signals the flow needs.
///
/// Completion lives in `public.user_preferences.onboarding_version` so the tour
/// does not reappear on a second device; SharedPreferences stays behind it as
/// an offline cache. Bumping [onboardingVersion] re-shows the tour to everyone
/// exactly once.
class OnboardingService {
  static const int onboardingVersion = 1;
  static const String _completionPrefix = 'onboarding_version_';
  static const String _table = 'user_preferences';
  static const String _column = 'onboarding_version';

  SharedPreferences? _preferences;

  /// Server-backed completion state, keyed by the id [isComplete] is asked
  /// about. Populated by [loadFor] before the tour decision is made.
  final Map<String, bool> _completion = <String, bool>{};

  /// Incremented when Settings asks for the tour to run again.
  final ValueNotifier<int> replayRequests = ValueNotifier<int>(0);

  /// Set to a bottom-nav index when the starter checklist (or the finish
  /// view) wants MainNavScreen to jump to a tab.
  final ValueNotifier<int?> tabRequests = ValueNotifier<int?>(null);

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  /// Reads completion from Supabase into memory. Anything that stops us from
  /// getting an answer — no client, no signed-in auth user, a network or RLS
  /// failure — counts as complete so the tour never ambushes an existing user.
  Future<void> loadFor(String userId) async {
    if (userId.isEmpty) return;

    final client = _client;
    final authUserId = client?.auth.currentUser?.id;
    if (client == null || authUserId == null) {
      _completion[userId] = true;
      return;
    }

    try {
      final row = await client
          .from(_table)
          .select(_column)
          .eq('user_id', authUserId)
          .maybeSingle();
      final complete = row?[_column] == onboardingVersion;
      _completion[userId] = complete;
      await _cacheLocally(userId, complete);
    } catch (_) {
      _completion[userId] = true;
    }
  }

  bool isComplete(String userId) {
    if (userId.isEmpty) return true;
    final loaded = _completion[userId];
    if (loaded != null) return loaded;
    // No server answer yet: fall back to the offline cache.
    if (_preferences == null) return true;
    return _preferences!.getInt('$_completionPrefix$userId') ==
        onboardingVersion;
  }

  Future<void> complete(String userId) async {
    if (userId.isEmpty) return;
    _completion[userId] = true;
    await _preferences?.setInt('$_completionPrefix$userId', onboardingVersion);
    await _writeRemoteVersion(onboardingVersion);
  }

  Future<void> reset(String userId) async {
    if (userId.isEmpty) return;
    _completion[userId] = false;
    await _preferences?.remove('$_completionPrefix$userId');
    await _writeRemoteVersion(null);
  }

  void requestReplay() {
    replayRequests.value++;
  }

  void requestTab(int index) {
    tabRequests.value = null; // re-fire even for the same tab twice in a row
    tabRequests.value = index;
  }

  SupabaseClient? get _client {
    if (!SupabaseConfig.isConfigured) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> _cacheLocally(String userId, bool complete) async {
    final preferences = _preferences;
    if (preferences == null) return;
    if (complete) {
      await preferences.setInt('$_completionPrefix$userId', onboardingVersion);
    } else {
      await preferences.remove('$_completionPrefix$userId');
    }
  }

  /// Club admins reach this with a club id, which is not an `auth.users` row,
  /// so the write is always keyed by the signed-in auth user. Failures are
  /// swallowed: the local cache already carries the user through this session.
  Future<void> _writeRemoteVersion(int? version) async {
    final client = _client;
    final authUserId = client?.auth.currentUser?.id;
    if (client == null || authUserId == null) return;
    try {
      await client.from(_table).upsert({
        'user_id': authUserId,
        _column: version,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'user_id');
    } catch (_) {
      // Offline or blocked by RLS; SharedPreferences keeps the local answer.
    }
  }
}

final onboardingService = OnboardingService();
