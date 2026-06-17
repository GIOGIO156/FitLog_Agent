import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_language.dart';

class LanguageController extends ChangeNotifier {
  LanguageController();

  static const String _languageCodeKey = 'language_code';

  AppLanguage _language = AppLanguage.english;
  bool _initialized = false;

  AppLanguage get language => _language;
  bool get initialized => _initialized;
  bool get isChinese => _language == AppLanguage.chinese;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_languageCodeKey);
    _language = AppLanguageX.fromCode(code);
    _initialized = true;
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    if (_language == language) {
      return;
    }
    _language = language;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageCodeKey, language.code);
  }
}
