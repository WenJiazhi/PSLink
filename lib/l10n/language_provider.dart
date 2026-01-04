import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Language provider for managing app locale
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'app_language';

  Locale _locale = const Locale('zh'); // Default to Chinese

  Locale get locale => _locale;

  LanguageProvider() {
    _loadLanguage();
  }

  Future<void> _loadLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageKey);
    if (languageCode != null) {
      _locale = Locale(languageCode);
      notifyListeners();
    }
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
  }

  void toggleLanguage() {
    if (_locale.languageCode == 'en') {
      setLocale(const Locale('zh'));
    } else {
      setLocale(const Locale('en'));
    }
  }
}
