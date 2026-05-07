import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class ThemeService extends ChangeNotifier {
  static const _boxName = 'theme_box';
  Box<dynamic>? _box;
  bool _isDark = true;

  bool get isDark => _isDark;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _isDark = _box!.get('isDark', defaultValue: true) as bool;
  }

  Future<void> setDark(bool value) async {
    if (_isDark == value) return;
    _isDark = value;
    await _box?.put('isDark', value);
    notifyListeners();
  }
}

final themeService = ThemeService();
