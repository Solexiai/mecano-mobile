import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../l10n/app_strings.dart';
import '../l10n/driver_notification_copy.dart';
import '../services/push_notification_service.dart';

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

    // Phase 8D : le token push conserve la langue préférée pour que FCM
    // envoie le texte système dans la bonne langue. Fail-soft : la méthode
    // retourne immédiatement si Firebase/FCM n'est pas initialisé.
    await PushNotificationService.syncCurrentToken();
  }

  String t(String key) =>
      DriverNotificationCopy.maybeTranslate(key, _locale) ?? AppStrings.t(key, _locale);
}
