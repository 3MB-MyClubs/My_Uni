import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';

/// Initializes Hive once for the whole app. Must run before any service
/// opens a box (content store, user prefs, view tracker, ...).
class HiveBootstrap {
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    if (kIsWeb) {
      Hive.init(null);
    } else {
      final appDir = await getApplicationDocumentsDirectory();
      Hive.init(appDir.path);
    }
    _initialized = true;
  }
}

final hiveBootstrap = HiveBootstrap();
