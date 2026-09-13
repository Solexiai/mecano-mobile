import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../router/app_router.dart';

/// Phase 8D — gestion client des notifications push Movi-K.
///
/// Principes :
/// - aucun token FCM n'est écrit directement dans Firestore;
/// - le token est enregistré via la Cloud Function authentifiée
///   `registerPushToken`;
/// - aucune permission n'est demandée au démarrage : le prompt est déclenché
///   au moment pertinent où un chauffeur se met "Disponible";
/// - une panne FCM reste fail-soft : l'app continue avec les notifications
///   in-app Firestore et le flux temps réel des offres;
/// - sur Web, l'enregistrement n'est tenté que si un VAPID public est fourni
///   via --dart-define=FCM_WEB_VAPID_KEY=... .
class PushNotificationService {
  PushNotificationService._();

  static StreamSubscription<User?>? _authSubscription;
  static StreamSubscription<String>? _tokenRefreshSubscription;
  static StreamSubscription<RemoteMessage>? _openedAppSubscription;
  static bool _initialized = false;
  static String? _lastRegisteredToken;

  static const String _localePreferenceKey = 'movik_locale';
  static const String _webVapidKey = String.fromEnvironment(
    'FCM_WEB_VAPID_KEY',
    defaultValue: '',
  );

  static Future<void> initialize() async {
    if (_initialized || Firebase.apps.isEmpty) return;
    _initialized = true;

    try {
      _openedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleOpenedMessage,
      );
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
        (token) {
          if (FirebaseAuth.instance.currentUser != null) {
            unawaited(_registerToken(token));
          }
        },
      );
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
        (user) {
          if (user != null) {
            // Ne force jamais un prompt de permission ici. Si l'utilisateur
            // a déjà autorisé les notifications, le token sera synchronisé.
            unawaited(syncCurrentToken());
          }
        },
      );

      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleOpenedMessage(initialMessage);
        });
      }

      if (FirebaseAuth.instance.currentUser != null) {
        await syncCurrentToken();
      }
    } catch (_) {
      // FCM est un canal secondaire. Aucun échec d'initialisation push ne
      // doit empêcher Movi-K de démarrer.
    }
  }

  /// À appeler quand le chauffeur passe en mode "Disponible". Le refus de
  /// permission ne bloque pas le statut en ligne : les offres restent visibles
  /// en temps réel dans l'app et via la cloche de notifications.
  static Future<void> requestPermissionAndSync() async {
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return;
    }

    // Web Push est volontairement désactivé tant que la clé VAPID publique
    // n'a pas été provisionnée. Ne pas demander une permission navigateur
    // qui ne pourrait ensuite produire aucun token utilisable.
    if (kIsWeb && _webVapidKey.isEmpty) return;

    try {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      if (settings.authorizationStatus == AuthorizationStatus.denied ||
          settings.authorizationStatus == AuthorizationStatus.notDetermined) {
        return;
      }
      await syncCurrentToken();
    } catch (_) {
      // Fail-soft : le chauffeur peut tout de même recevoir l'offre in-app.
    }
  }

  /// Synchronise le token courant uniquement si la permission a déjà été
  /// accordée. Ne fait apparaître aucun prompt système.
  static Future<void> syncCurrentToken() async {
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    if (kIsWeb && _webVapidKey.isEmpty) return;

    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      final token = await _getCurrentToken();
      if (token == null || token.isEmpty) return;
      await _registerToken(token);
    } catch (_) {
      // Fail-soft.
    }
  }

  static Future<String?> _getCurrentToken() async {
    if (kIsWeb) {
      // Web Push exige une clé VAPID publique. Tant qu'elle n'est pas
      // provisionnée, le Web continue avec les notifications in-app.
      if (_webVapidKey.isEmpty) return null;
      return FirebaseMessaging.instance.getToken(vapidKey: _webVapidKey);
    }
    return FirebaseMessaging.instance.getToken();
  }

  static Future<void> _registerToken(String token) async {
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final locale = prefs.getString(_localePreferenceKey) ?? 'fr';
      await FirebaseFunctions.instance.httpsCallable('registerPushToken').call({
        'token': token,
        'platform': _platformName(),
        'locale': ['fr', 'en', 'es'].contains(locale) ? locale : 'fr',
      });
      _lastRegisteredToken = token;
    } catch (_) {
      // Le prochain login/token-refresh/remise en ligne réessaiera.
    }
  }

  /// Appelée juste AVANT FirebaseAuth.signOut(). Empêche qu'un appareil
  /// partagé continue de recevoir des offres destinées au compte précédent.
  static Future<void> unregisterCurrentToken() async {
    if (Firebase.apps.isEmpty || FirebaseAuth.instance.currentUser == null) {
      return;
    }
    try {
      final token = _lastRegisteredToken ?? await _getCurrentToken();
      if (token == null || token.isEmpty) return;
      await FirebaseFunctions.instance.httpsCallable('unregisterPushToken').call({
        'token': token,
      });
      if (_lastRegisteredToken == token) _lastRegisteredToken = null;
    } catch (_) {
      // La déconnexion ne doit jamais être bloquée par FCM.
    }
  }

  static String _platformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      default:
        return 'unknown';
    }
  }

  static Future<void> _handleOpenedMessage(RemoteMessage message) async {
    final data = message.data;
    final type = data['type'];

    if (type != 'delivery_offer' && type != 'mission_status') return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final locale = prefs.getString(_localePreferenceKey) ?? 'fr';
      final safeLocale = ['fr', 'en', 'es'].contains(locale) ? locale : 'fr';

      // Une offre n'est PAS encore une mission assignée : on ouvre la liste
      // des demandes disponibles, jamais l'écran "mission active".
      if (type == 'delivery_offer') {
        AppRouter.router.go('/$safeLocale/fournisseur/tableau-de-bord');
        return;
      }

      final missionId = data['missionId'];
      if (missionId is! String || missionId.trim().isEmpty) return;

      AppRouter.router.go('/$safeLocale/livraison/suivi/$missionId');
    } catch (_) {
      // La notification a tout de même rempli son rôle d'alerte; une erreur
      // de deep-link ne doit pas faire planter l'app.
    }
  }

  @visibleForTesting
  static Future<void> disposeForTesting() async {
    await _authSubscription?.cancel();
    await _tokenRefreshSubscription?.cancel();
    await _openedAppSubscription?.cancel();
    _authSubscription = null;
    _tokenRefreshSubscription = null;
    _openedAppSubscription = null;
    _lastRegisteredToken = null;
    _initialized = false;
  }
}
