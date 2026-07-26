import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether a user has been through the first-run "campus tour"
/// onboarding, and carries the replay / deep-link signals the flow needs.
///
/// Completion is stored per user under a versioned key; bumping
/// [onboardingVersion] re-shows the tour to everyone exactly once.
class OnboardingService {
  static const int onboardingVersion = 1;
  static const String _completionPrefix = 'onboarding_version_';

  SharedPreferences? _preferences;

  /// Incremented when Settings asks for the tour to run again.
  final ValueNotifier<int> replayRequests = ValueNotifier<int>(0);

  /// Set to a bottom-nav index when the starter checklist (or the finish
  /// view) wants MainNavScreen to jump to a tab.
  final ValueNotifier<int?> tabRequests = ValueNotifier<int?>(null);

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  bool isComplete(String userId) {
    if (userId.isEmpty || _preferences == null) return true;
    return _preferences!.getInt('$_completionPrefix$userId') ==
        onboardingVersion;
  }

  Future<void> complete(String userId) async {
    if (userId.isEmpty || _preferences == null) return;
    await _preferences!.setInt('$_completionPrefix$userId', onboardingVersion);
  }

  Future<void> reset(String userId) async {
    if (userId.isEmpty || _preferences == null) return;
    await _preferences!.remove('$_completionPrefix$userId');
  }

  void requestReplay() {
    replayRequests.value++;
  }

  void requestTab(int index) {
    tabRequests.value = null; // re-fire even for the same tab twice in a row
    tabRequests.value = index;
  }
}

final onboardingService = OnboardingService();
