import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether this device has ever reached an authenticated app state
/// (a completed sign-up followed by login, or a plain login). Once true, the
/// intro carousel is never shown again on this device.
class OnboardingIntroService {
  static const _preferenceKey = 'has_completed_onboarding_intro';

  bool _completed = false;

  bool get hasCompletedOnceOnDevice => _completed;

  Future<void> initialize() async {
    final preferences = await SharedPreferences.getInstance();
    _completed = preferences.getBool(_preferenceKey) ?? false;
  }

  Future<void> markCompletedOnDevice() async {
    if (_completed) return;
    _completed = true;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_preferenceKey, true);
  }
}

final onboardingIntroService = OnboardingIntroService();
