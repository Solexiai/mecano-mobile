// -----------------------------------------------------------------------------
// Admin SDK bootstrap — Application Default Credentials UNIQUEMENT.
//
// IMPORTANT SÉCURITÉ :
// - Aucune clé de compte de service (service account JSON / private key) ne
//   doit JAMAIS être référencée ici, committée dans ce dépôt, ni chargée
//   depuis un fichier local.
// - Sur l'environnement d'exécution Cloud Functions (2nd gen / Cloud Run),
//   `admin.initializeApp()` sans argument utilise automatiquement les
//   Application Default Credentials fournies par la plateforme (identité du
//   compte de service d'exécution de la fonction).
// - En local (Firebase Emulator Suite), les emulators fournissent leurs
//   propres credentials factices ; aucune clé n'est nécessaire non plus tant
//   que les variables d'environnement FIRESTORE_EMULATOR_HOST /
//   FIREBASE_AUTH_EMULATOR_HOST sont définies par `firebase emulators:start`.
// - Si un accès Admin SDK est un jour nécessaire depuis un script HORS Cloud
//   Functions (ex: un script d'admin ponctuel), utiliser
//   `gcloud auth application-default login` pour générer des ADC locales
//   plutôt que de générer/committer une clé privée.
// -----------------------------------------------------------------------------

import * as admin from "firebase-admin";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

export const db = admin.firestore();
export const authAdmin = admin.auth();
export { admin };

// Paramètres Firestore recommandés (ignoreUndefinedProperties évite des
// erreurs d'écriture accidentelles quand un champ optionnel vaut `undefined`
// plutôt que `null` en TypeScript).
db.settings({ ignoreUndefinedProperties: true });
