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
// ÉTAT ACTUEL : PLACEHOLDER — aucun projet Firebase n'a encore été fourni
// par l'utilisateur. `FirebaseBootstrap.isConfigured` restera `false` et
// `Firebase.initializeApp()` ne sera pas appelé, tant que les valeurs
// ci-dessous ne sont pas remplacées par les vraies valeurs du projet
// Firebase Console (voir README_FIREBASE_SETUP.md à la racine du projet
// pour les instructions étape par étape).
// ---------------------------------------------------------------------------

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Renseigne ici les valeurs obtenues depuis Firebase Console > Paramètres
/// du projet > Vos applications, pour chaque plateforme (Web et Android).
/// Tant que `projectId` vaut 'UNCONFIGURED', le bootstrap ne tentera pas de
/// se connecter et l'application fonctionnera en mode `not_configured`.
class DefaultFirebaseOptions {
  static const String projectId = 'UNCONFIGURED';

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

  /// À remplacer par la config Web réelle (Firebase Console > Web app).
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'UNCONFIGURED',
    appId: 'UNCONFIGURED',
    messagingSenderId: 'UNCONFIGURED',
    projectId: projectId,
    authDomain: 'UNCONFIGURED',
    storageBucket: 'UNCONFIGURED',
  );

  /// À remplacer par la config Android réelle (issue de google-services.json).
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'UNCONFIGURED',
    appId: 'UNCONFIGURED',
    messagingSenderId: 'UNCONFIGURED',
    projectId: projectId,
    storageBucket: 'UNCONFIGURED',
  );

  static bool get isPlaceholder => projectId == 'UNCONFIGURED';
}
