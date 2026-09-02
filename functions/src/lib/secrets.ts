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
//   firebase functions:secrets:set STRIPE_PLATFORM_WEBHOOK_SECRET
//   firebase functions:secrets:set STRIPE_CONNECT_WEBHOOK_SECRET
// Puis chaque fonction qui a besoin d'un secret doit le déclarer dans ses
// options (`{ secrets: [STRIPE_SECRET_KEY] }`) — voir onCall(...) dans les
// fonctions de paiement.
//
// 🔒 BLOQUEUR WEBHOOK PRODUCTION (Bloc 8B LIVE, voir docs/PAYMENT_ARCHITECTURE.md
// §10.9) : docs.stripe.com/connect/webhooks documente que chaque endpoint
// webhook Stripe est scopé EXCLUSIVEMENT à "Your account" (événements
// plateforme) OU "Connected accounts" (événements sur les comptes connectés)
// — jamais les deux dans le même endpoint. Chaque endpoint génère SON PROPRE
// secret de signature `whsec_...`, distinct même pour le même compte Stripe.
// Movi-K a besoin des deux scopes (9 événements plateforme + `account.updated`
// en Connect) => 2 endpoints, donc 2 secrets distincts :
//   - `STRIPE_PLATFORM_WEBHOOK_SECRET` : endpoint "Your account" (scope
//     plateforme), consommé par `processStripeWebhook`.
//   - `STRIPE_CONNECT_WEBHOOK_SECRET` : endpoint "Connected accounts",
//     consommé par `processStripeConnectWebhook`.
// `STRIPE_WEBHOOK_SECRET` (legacy, ci-dessous) N'EST PLUS utilisé pour la
// vérification de signature d'aucun des deux endpoints webhook — conservé
// UNIQUEMENT parce que plusieurs fonctions non-webhook (acceptDelivery,
// completeDelivery, attachCustomerPaymentMethod, createCustomerPaymentProfile,
// createDriverStripeAccount, refundPayment, processScheduledDriverPayouts,
// runReconciliation*) le déclarent encore par symétrie historique SANS jamais
// l'utiliser réellement (aucune de ces fonctions n'appelle
// `constructVerifiedEvent`/`stripe.webhooks.constructEvent` — voir
// docs/PAYMENT_ARCHITECTURE.md §10.5). Retirer cette déclaration bénigne de
// ces fonctions n'apporte aucun bénéfice fonctionnel et sort du périmètre
// "correction minimale" demandé — non fait ce tour.
// -----------------------------------------------------------------------------

import { defineSecret } from "firebase-functions/params";

export const STRIPE_SECRET_KEY = defineSecret("STRIPE_SECRET_KEY");

/** @deprecated Legacy — plus utilisé pour vérifier une signature webhook
 * (voir bloc de commentaire ci-dessus). Remplacé par
 * `STRIPE_PLATFORM_WEBHOOK_SECRET` / `STRIPE_CONNECT_WEBHOOK_SECRET`. Conservé
 * uniquement pour ne pas casser la déclaration `secrets: [...]` bénigne
 * d'autres fonctions non-webhook. */
export const STRIPE_WEBHOOK_SECRET = defineSecret("STRIPE_WEBHOOK_SECRET");

/** Secret de signature de l'endpoint webhook PLATEFORME ("Your account" dans
 * Stripe Workbench/API `connect: false`) — consommé par `processStripeWebhook`. */
export const STRIPE_PLATFORM_WEBHOOK_SECRET = defineSecret("STRIPE_PLATFORM_WEBHOOK_SECRET");

/** Secret de signature de l'endpoint webhook CONNECT ("Connected accounts"
 * dans Stripe Workbench/API `connect: true`) — consommé par
 * `processStripeConnectWebhook`. */
export const STRIPE_CONNECT_WEBHOOK_SECRET = defineSecret("STRIPE_CONNECT_WEBHOOK_SECRET");

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
