import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LocaleService extends ChangeNotifier {
  static const _boxName = 'locale_box';
  Box<dynamic>? _box;
  String _languageCode = 'en';
  final Set<String> _chosenLanguageUsers = {};

  String get languageCode => _languageCode;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _languageCode = _box!.get('languageCode', defaultValue: 'en') as String;
    final stored = _box!.get('chosenLanguageUsers');
    if (stored != null) {
      _chosenLanguageUsers.addAll(List<String>.from(stored as List));
    }
  }

  bool hasChosenLanguage(String userId) =>
      _chosenLanguageUsers.contains(userId);

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    await _box?.put('languageCode', code);
    notifyListeners();
  }

  Future<void> markLanguageChosen(String userId, String code) async {
    _languageCode = code;
    _chosenLanguageUsers.add(userId);
    await _box?.put('languageCode', code);
    await _box?.put('chosenLanguageUsers', _chosenLanguageUsers.toList());
    notifyListeners();
  }
}

final localeService = LocaleService();
