// ---------------------------------------------------------------------------
// BackendBootstrap — point d'entrée unique pour l'initialisation Firebase.
//
// Comportement sécurisé :
// - Si firebase_options.dart est encore un placeholder ('UNCONFIGURED'),
//   n'appelle JAMAIS Firebase.initializeApp() et retourne immédiatement un
//   BackendStatus.notConfigured() — évite tout crash au démarrage.
// - Si des vraies valeurs sont présentes, tente l'initialisation dans un
//   try/catch : en cas d'échec (mauvaise config, réseau, etc.), l'app
//   continue de fonctionner en mode not_configured plutôt que de planter.
// - Ne contient et ne charge AUCUN secret (pas de clé Admin SDK, pas de clé
//   API privée). Les seules valeurs utilisées sont les identifiants publics
//   de projet Firebase (voir firebase_options.dart).
// ---------------------------------------------------------------------------

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'backend_status.dart';
import 'firebase_options.dart';

class BackendBootstrap {
  static BackendStatus _status = const BackendStatus.notConfigured('not_initialized_yet');

  static BackendStatus get status => _status;

  /// À appeler une seule fois, tôt dans main(), avant runApp().
  static Future<BackendStatus> initialize() async {
    if (DefaultFirebaseOptions.isPlaceholder) {
      _status = const BackendStatus.notConfigured('firebase_options_placeholder');
      if (kDebugMode) {
        debugPrint(
            '[BackendBootstrap] Firebase non configuré (firebase_options.dart contient encore '
            'des valeurs UNCONFIGURED). L\'application fonctionne en mode not_configured. '
            'Voir README_FIREBASE_SETUP.md pour connecter un vrai projet Firebase.');
      }
      return _status;
    }

    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      _status = const BackendStatus.ready();
    } catch (e) {
      _status = BackendStatus.notConfigured('firebase_init_failed: $e');
      if (kDebugMode) {
        debugPrint('[BackendBootstrap] Échec Firebase.initializeApp(): $e');
      }
    }
    return _status;
  }
}
