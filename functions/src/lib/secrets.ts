// -----------------------------------------------------------------------------
// secrets.ts — Déclaration des secrets Phase 6 via Firebase Functions
// Secret Manager (`defineSecret`). AUCUNE clé n'est jamais committée dans ce
// dépôt, ni écrite en dur, ni journalisée (point 30 du cahier des charges).
//
// `defineSecret` (firebase-functions/params) crée une RÉFÉRENCE paramétrée :
// la vraie valeur n'existe qu'à l'exécution, injectée par Cloud
// Functions/Cloud Run depuis Secret Manager. Elle n'apparaît JAMAIS dans le
// code source, les logs de build, ni les artefacts de déploiement.
//
// Utilisation :
//   firebase functions:secrets:set STRIPE_SECRET_KEY
//   firebase functions:secrets:set STRIPE_WEBHOOK_SECRET
// Puis chaque fonction qui a besoin d'un secret doit le déclarer dans ses
// options (`{ secrets: [STRIPE_SECRET_KEY] }`) — voir onCall(...) dans les
// fonctions de paiement.
// -----------------------------------------------------------------------------

import { defineSecret } from "firebase-functions/params";

export const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");
export const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

/**
 * Vrai si une clé Stripe est configurée dans l'environnement d'exécution
 * courant (Secret Manager en production, variable d'env en émulateur de
 * test). Utilisé pour choisir entre `StripeProvider` et
 * `NotConfiguredPaymentProvider` SANS jamais logguer la valeur elle-même.
 */
export function isStripeConfigured(): boolean {
  try {
    const value = STRIPE_SECRET_KEY.value();
    return typeof value === "string" && value.length > 0;
  } catch {
    return false;
  }
}
