// Implémentation par défaut (non-web) de configureUrlStrategy().
//
// Sur mobile (Android/iOS) et dans les tests Flutter (`flutter test`, qui
// s'exécutent sur la plateforme VM), la notion de "stratégie d'URL" n'existe
// pas — c'est un concept exclusivement web (dart:ui_web, disponible
// uniquement en compilation web). Ce fichier est sélectionné par défaut via
// l'import conditionnel dans main.dart et ne fait rien.
void configureUrlStrategy() {
  // No-op sur mobile/VM.
}
