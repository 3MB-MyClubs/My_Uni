import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'account_preferences_service.dart';

class LocaleService extends ChangeNotifier {
  LocaleService({Future<void> Function(String)? accountSaver})
    : _accountSaver = accountSaver;

  static const _boxName = 'locale_box';
  final Future<void> Function(String)? _accountSaver;
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

  Future<void> setLanguage(String code, {bool persistToAccount = true}) async {
    if (code != 'en' && code != 'tr') return;
    final changed = _languageCode != code;
    _languageCode = code;
    await _box?.put('languageCode', code);
    if (changed) notifyListeners();
    if (persistToAccount) {
      try {
        await _accountSaver?.call(code);
      } catch (_) {
        // The local selection remains usable offline. The account write will
        // be retried the next time the user changes this setting.
      }
    }
  }

  Future<void> markLanguageChosen(String userId, String code) async {
    if (code != 'en' && code != 'tr') return;
    _languageCode = code;
    await _accountSaver?.call(code);
    _chosenLanguageUsers.add(userId);
    await _box?.put('languageCode', code);
    await _box?.put('chosenLanguageUsers', _chosenLanguageUsers.toList());
    notifyListeners();
  }

  Future<void> applyAccountLanguage(String userId, String code) async {
    if (code != 'en' && code != 'tr') return;
    final changed = _languageCode != code;
    _languageCode = code;
    _chosenLanguageUsers.add(userId);
    await _box?.put('languageCode', code);
    await _box?.put('chosenLanguageUsers', _chosenLanguageUsers.toList());
    if (changed) notifyListeners();
  }
}

final localeService = LocaleService(
  accountSaver: accountPreferencesService.saveLanguage,
);
