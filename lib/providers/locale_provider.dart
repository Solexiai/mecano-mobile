import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../l10n/driver_notification_copy.dart';

/// Manages the active app locale (fr default, en, es).
class LocaleProvider extends ChangeNotifier {
  static const _prefKey = 'movik_locale';
  static const supported = ['fr', 'en', 'es'];
  String _locale = 'fr';

  /// True once the locale comes from the URL or from [setLocale]. The saved
  /// choice from a previous visit must not replace it afterwards.
  bool _localeChosen = false;

  String get locale => _locale;
  Locale get flutterLocale => Locale(_locale);

  /// [initialLocale] is the language of the web address (/fr, /en, /es).
  /// When given, it wins over the language saved on a previous visit, so
  /// the first frame is already in the language of the page.
  LocaleProvider({String? initialLocale}) {
    if (initialLocale != null && supported.contains(initialLocale)) {
      _locale = initialLocale;
      _localeChosen = true;
    }
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (_localeChosen) return;
    _locale = prefs.getString(_prefKey) ?? 'fr';
    notifyListeners();
  }

  Future<void> setLocale(String code) async {
    if (!supported.contains(code)) return;
    _localeChosen = true;
    _locale = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, code);
  }

  String t(String key) =>
      DriverNotificationCopy.maybeTranslate(key, _locale) ?? AppStrings.t(key, _locale);
}
