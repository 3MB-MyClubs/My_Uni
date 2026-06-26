import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

class LocaleService extends ChangeNotifier {
  static const _boxName = 'locale_box';
  Box<dynamic>? _box;
  String _languageCode = 'en';

  String get languageCode => _languageCode;

  Future<void> initialize() async {
    _box = await Hive.openBox<dynamic>(_boxName);
    _languageCode = _box!.get('languageCode', defaultValue: 'en') as String;
  }

  Future<void> setLanguage(String code) async {
    if (_languageCode == code) return;
    _languageCode = code;
    await _box?.put('languageCode', code);
    notifyListeners();
  }
}

final localeService = LocaleService();
