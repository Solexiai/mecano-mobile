// ---------------------------------------------------------------------------
// firebase_options.dart — configuration multi-plateforme Firebase.
//
// ⚠️ CE FICHIER NE CONTIENT AUCUN SECRET SENSIBLE.
// Les clés "apiKey" Firebase pour Web/Android sont des identifiants
// PUBLICS de projet (elles identifient le projet Firebase, elles
// n'autorisent aucune action sans passer par Firebase Auth + Security
// Rules + App Check). Elles ne remplacent JAMAIS une clé Admin SDK privée,
// qui elle ne doit jamais apparaître dans ce projet Flutter.
//
// ÉTAT ACTUEL : projet réel "movik-connect-prod" connecté (Étape 13).
// - Config WEB : renseignée ci-dessous (Firebase Console > App Web).
// - Config ANDROID : EN ATTENTE de google-services.json (Firebase Console >
//   App Android > Télécharger google-services.json). Tant que la section
//   `android` ci-dessous contient encore des valeurs 'UNCONFIGURED', c'est
//   uniquement la plateforme Android qui restera en mode `not_configured`
//   (le Web fonctionne déjà). Voir README_FIREBASE_SETUP.md.
// ---------------------------------------------------------------------------

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Renseigne ici les valeurs obtenues depuis Firebase Console > Paramètres
/// du projet > Vos applications, pour chaque plateforme (Web et Android).
class DefaultFirebaseOptions {
  static const String projectId = 'movik-connect-prod';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        return web;
    }
  }

  /// Config Web réelle — Firebase Console > Paramètres du projet > App Web
  /// "movik-connect-prod" (identifiants publics de projet, voir en-tête).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyCLIvf9Ql4MZvsKGinjnT1caNfj8Ba6oaE',
    appId: '1:624917306908:web:6e357be752bd9ad1e489d9',
    messagingSenderId: '624917306908',
    projectId: projectId,
    authDomain: 'movik-connect-prod.firebaseapp.com',
    storageBucket: 'movik-connect-prod.firebasestorage.app',
    measurementId: 'G-T9ST69R3R6',
  );

  /// À remplacer par la config Android réelle (issue de google-services.json,
  /// Firebase Console > App Android com.movik.movik_connect).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'UNCONFIGURED',
    appId: 'UNCONFIGURED',
    messagingSenderId: 'UNCONFIGURED',
    projectId: projectId,
    storageBucket: 'UNCONFIGURED',
  );

  static bool get isPlaceholder => projectId == 'UNCONFIGURED';

  /// Indique si la plateforme Android spécifiquement est encore en attente
  /// de configuration (indépendant du Web, qui peut déjà être opérationnel).
  static bool get isAndroidPlaceholder => android.apiKey == 'UNCONFIGURED';
}
