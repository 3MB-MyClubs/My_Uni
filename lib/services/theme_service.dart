import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'account_preferences_service.dart';

class ThemeService extends ChangeNotifier {
  ThemeService({Future<void> Function(bool)? accountSaver})
    : _accountSaver = accountSaver;

  static const _boxName = 'theme_box';
  final Future<void> Function(bool)? _accountSaver;
  Box<dynamic>? _box;
  // First-time users always start in light; returning users keep their choice.
  bool _isDark = false;
  final Set<String> _themedUsers = {};

  bool get isDark => _isDark;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _isDark = _box!.get('isDark', defaultValue: false) as bool;
    final stored = _box!.get('themedUsers');
    if (stored != null) {
      _themedUsers.addAll(List<String>.from(stored as List));
    }
  }

  /// Whether [userId] has already picked a theme (so we don't ask again).
  bool hasChosenTheme(String userId) => _themedUsers.contains(userId);

  Future<void> setDark(bool value, {bool persistToAccount = true}) async {
    final changed = _isDark != value;
    _isDark = value;
    await _box?.put('isDark', value);
    if (changed) notifyListeners();
    if (persistToAccount) {
      try {
        await _accountSaver?.call(value);
      } catch (_) {
        // Keep the device preference available while offline. A later change
        // in Settings will retry the account write.
      }
    }
  }

  /// Records [userId]'s explicit light/dark choice and applies it.
  Future<void> markThemeChosen(String userId, bool dark) async {
    _isDark = dark;
    await _accountSaver?.call(dark);
    _themedUsers.add(userId);
    await _box?.put('isDark', dark);
    await _box?.put('themedUsers', _themedUsers.toList());
    notifyListeners();
  }

  Future<void> applyAccountTheme(String userId, bool dark) async {
    final changed = _isDark != dark;
    _isDark = dark;
    _themedUsers.add(userId);
    await _box?.put('isDark', dark);
    await _box?.put('themedUsers', _themedUsers.toList());
    if (changed) notifyListeners();
  }
}

final themeService = ThemeService(
  accountSaver: accountPreferencesService.saveTheme,
);
