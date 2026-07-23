import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TutorialService {
  static const int tutorialVersion = 1;
  static const String _completionPrefix = 'app_tutorial_version_';

  SharedPreferences? _preferences;

  final ValueNotifier<int> replayRequests = ValueNotifier<int>(0);

  Future<void> initialize() async {
    _preferences ??= await SharedPreferences.getInstance();
  }

  bool isComplete(String userId) {
    if (userId.isEmpty || _preferences == null) return true;
    return _preferences!.getInt('$_completionPrefix$userId') == tutorialVersion;
  }

  Future<void> complete(String userId) async {
    if (userId.isEmpty || _preferences == null) return;
    await _preferences!.setInt('$_completionPrefix$userId', tutorialVersion);
  }

  Future<void> reset(String userId) async {
    if (userId.isEmpty || _preferences == null) return;
    await _preferences!.remove('$_completionPrefix$userId');
  }

  void requestReplay() {
    replayRequests.value++;
  }
}

final tutorialService = TutorialService();
