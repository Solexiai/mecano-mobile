import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';

/// Manages the active app locale (fr default, en, es).
class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'movik_locale';
  String _locale = 'fr';

  String get locale => _locale;
  Locale get flutterLocale => Locale(_locale);

  LocaleProvider() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_prefKey) ?? 'fr';
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (!['fr', 'en', 'es'].contains(code)) return;
    _locale = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  String t(String key) => AppStrings.t(key, _locale);
}
