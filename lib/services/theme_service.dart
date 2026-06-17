import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ThemeService extends ChangeNotifier {
  static const _boxName = 'theme_box';
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

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await _box?.put('isDark', value);
    notifyListeners();
  }

  /// Records [userId]'s explicit light/dark choice and applies it.
  Future<void> markThemeChosen(String userId, bool dark) async {
    _isDark = dark;
    _themedUsers.add(userId);
    await _box?.put('isDark', dark);
    await _box?.put('themedUsers', _themedUsers.toList());
    notifyListeners();
  }
}

final themeService = ThemeService();
