import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LocaleService extends ChangeNotifier {
  static const _boxName = 'locale_box';
  static const defaultLanguageCode = 'tr';
  Box<dynamic>? _box;
  String _languageCode = defaultLanguageCode;
  final Set<String> _chosenLanguageUsers = {};

  String get languageCode => _languageCode;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    final storedLanguage = _box!.get('languageCode');
    _languageCode = storedLanguage == 'en' || storedLanguage == 'tr'
        ? storedLanguage as String
        : defaultLanguageCode;
    final stored = _box!.get('chosenLanguageUsers');
    if (stored != null) {
      _chosenLanguageUsers.addAll(List<String>.from(stored as List));
    }
  }

  bool hasChosenLanguage(String userId) =>
      _chosenLanguageUsers.contains(userId);

  Future<void> setLanguage(String code) async {
    if (code != 'en' && code != 'tr') return;
    final changed = _languageCode != code;
    _languageCode = code;
    await _box?.put('languageCode', code);
    if (changed) notifyListeners();
  }

  Future<void> markLanguageChosen(String userId, String code) async {
    if (code != 'en' && code != 'tr') return;
    _languageCode = code;
    _chosenLanguageUsers.add(userId);
    await _box?.put('languageCode', code);
    await _box?.put('chosenLanguageUsers', _chosenLanguageUsers.toList());
    notifyListeners();
  }
}

final localeService = LocaleService();
