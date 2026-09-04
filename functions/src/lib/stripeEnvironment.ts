// -----------------------------------------------------------------------------
// stripeEnvironment.ts — Garde-fou d'ISOLATION D'ENVIRONNEMENT Stripe
// (Phase 8B, item (f) de la directive "ARCHITECTURE STRIPE DÉFINITIVE
// LIVE-READY" de Daniel).
//
// 🎯 PROBLÈME RÉSOLU :
// Movi-K n'a qu'UN SEUL projet Firebase (`movik-connect-prod`, voir
// `.firebaserc`) — TEST et LIVE ne sont donc PAS séparés par projet GCP,
// mais uniquement par LA CLÉ STRIPE ACTIVE (`STRIPE_SECRET_KEY`, voir
// `lib/secrets.ts`). Toute référence Stripe stockée dans Firestore
// (`provider_customer_id`, `provider_payment_intent_id`,
// `connected_account_id`, `provider_refund_id`, `provider_payout_id`, ...)
// appartient IMPLICITEMENT au mode (test|live) de la clé qui était active
// au moment de sa création chez Stripe. Sans garde-fou, un changement de
// clé (test -> live, ou un rollback accidentel live -> test) pourrait faire
// RÉUTILISER une référence de l'AUTRE mode — Stripe rejette la plupart des
// accès cross-mode côté API (erreur native), mais PAS TOUS les cas
// (certains identifiants ne sont PAS distinguables visuellement, voir
// docs/PAYMENT_ARCHITECTURE.md) — un garde-fou APPLICATIF explicite est
// donc nécessaire, jamais une simple confiance dans le rejet Stripe.
//
// 🔒 PRINCIPE : FAIL CLOSED (directive Daniel, item f explicite : « Add
// garde-fous si nécessaires. Fail closed en cas d'incohérence »).
//
//   - Toute écriture d'un NOUVEAU document portant une référence Stripe
//     (payments, refunds, driver_payouts, payment_profiles, disputes) est
//     TAGUÉE avec l'environnement Stripe ACTIF au moment de sa création
//     (`stripe_environment`, voir lib/types.ts).
//   - Toute RÉUTILISATION d'une référence Stripe déjà stockée (avant un
//     appel PaymentProvider réel) DOIT être validée via
//     `assertStripeReferenceEnvironmentConsistency()` ci-dessous, qui:
//       * REFUSE (fail closed) toute référence dont l'environnement stocké
//         diffère de l'environnement actif — quel que soit le sens du
//         mélange (test réutilisé en live, OU live réutilisé en test).
//       * REFUSE (fail closed) toute référence SANS tag environnement dès
//         que l'environnement ACTIF est LIVE (aucune donnée pré-migration
//         non taguée ne peut être présumée sûre à l'ère de l'argent réel).
//       * TOLÈRE l'absence de tag uniquement quand l'environnement actif
//         est TEST (rétro-compatibilité avec les fixtures de test
//         existantes, qui n'ont jamais manipulé de fonds réels — voir
//         test/testUtils/fakePaymentProvider.ts et les nombreux seeds
//         directs `db.collection("payments").doc().set({...})` des tests
//         d'intégration, qui n'utilisent jamais un PaymentProvider réel).
//
// 🔒 UNE SEULE SOURCE DE VÉRITÉ POUR L'ENVIRONNEMENT ACTIF : jamais une
// lecture directe de `STRIPE_SECRET_KEY.value()` dispersée dans le code —
// chaque `PaymentProvider` porte sa PROPRE propriété `environment` (calculée
// UNE SEULE FOIS, à la construction — voir `PaymentProvider.environment`
// dans paymentProvider.ts), garantissant que l'environnement "actif" est
// TOUJOURS celui du provider RÉELLEMENT utilisé pour l'opération en cours
// (jamais une valeur lue séparément qui pourrait diverger en cas de
// reconfiguration concurrente).
// -----------------------------------------------------------------------------

import { internal } from "./errors";
import {
  logFinancialFailure,
  type FinancialOperationIdentifiers,
} from "./observability";

/** Les deux seuls modes Stripe possibles — jamais un troisième état inventé. */
export type StripeEnvironment = "test" | "live";

/**
 * Code d'erreur INTERNE (jamais un texte exposé tel quel au client — voir
 * `stripeEnvironmentMismatchError()` ci-dessous, qui renvoie un message
 * générique). Distinct de `KILL_SWITCH_ERROR_CODE` (lib/runtimeFlags.ts) :
 * ceci signale une INCOHÉRENCE DE DONNÉES potentiellement dangereuse
 * (mélange test/live), jamais une indisponibilité temporaire du service.
 */
export const STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE = "stripe_environment_mismatch";

/**
 * Erreur levée par `assertStripeReferenceEnvironmentConsistency()` — TOUJOURS
 * un `HttpsError` "internal" (jamais "invalid-argument" : ceci n'est jamais
 * une faute du client, c'est une anomalie SERVEUR — soit un bug, soit une
 * tentative de contournement, soit une transition test/live mal gérée
 * opérationnellement). Le message exposé au client reste générique — le
 * détail complet (quelle référence, quel environnement attendu/trouvé) est
 * TOUJOURS journalisé côté serveur via `logFinancialFailure()` par
 * l'appelant, jamais renvoyé au client (cohérent avec le principe déjà en
 * place pour `killSwitchRefusal()`).
 */
export function stripeEnvironmentMismatchError(): Error {
  return internal(
    "Incohérence d'environnement de paiement détectée. Opération refusée par sécurité — veuillez contacter le support."
  );
}

/**
 * Dérive l'environnement Stripe (test|live) à partir du PRÉFIXE d'une clé
 * secrète Stripe — la SEULE méthode fiable et documentée
 * (docs.stripe.com/keys : toute clé Stripe commence par `sk_test_`/`sk_live_`
 * pour les clés secrètes standard, ou `rk_test_`/`rk_live_` pour les clés
 * restreintes — Movi-K utilise `STRIPE_SECRET_KEY`, potentiellement l'une ou
 * l'autre forme selon la configuration Secret Manager de Daniel).
 *
 * 🔒 FAIL CLOSED : toute clé dont le préfixe n'est PAS reconnu lève une
 * exception explicite plutôt que de deviner un environnement par défaut —
 * une clé Stripe malformée ne doit JAMAIS être traitée silencieusement
 * comme "test" (ce qui masquerait une vraie erreur de configuration) ni
 * comme "live" (ce qui pourrait faire passer un test pour une opération
 * réelle).
 */
export function resolveStripeEnvironmentFromSecretKey(secretKey: string): StripeEnvironment {
  if (secretKey.startsWith("sk_live_") || secretKey.startsWith("rk_live_")) {
    return "live";
  }
  if (secretKey.startsWith("sk_test_") || secretKey.startsWith("rk_test_")) {
    return "test";
  }
  throw new Error(
    "Format de clé Stripe non reconnu (préfixe attendu: sk_test_/sk_live_/rk_test_/rk_live_) — " +
      "impossible de déterminer l'environnement de manière fiable, opération refusée."
  );
}

/**
 * Valide qu'une référence Stripe STOCKÉE (ex: `payments/{id}.stripe_environment`)
 * est cohérente avec l'environnement ACTUELLEMENT ACTIF (celui du
 * `PaymentProvider` réellement utilisé pour l'opération en cours — voir
 * `PaymentProvider.environment`). Lève `stripeEnvironmentMismatchError()`
 * (fail closed) dans TOUS les cas dangereux :
 *
 *   storedEnvironment | activeEnvironment | résultat
 *   ------------------|-------------------|----------------------------------
 *   "test"            | "test"            | OK
 *   "live"            | "live"            | OK
 *   "test"            | "live"            | REFUSÉ (mélange test/live réel)
 *   "live"            | "test"            | REFUSÉ (mélange test/live réel)
 *   absent/null       | "test"            | TOLÉRÉ (donnée pré-migration ou
 *                      |                   | fixture de test — jamais de
 *                      |                   | fonds réels en jeu)
 *   absent/null       | "live"            | REFUSÉ (impossible de garantir
 *                      |                   | qu'une référence non taguée est
 *                      |                   | sûre à réutiliser avec de
 *                      |                   | l'argent réel — fail closed)
 *
 * Le SEUL rôle de cette fonction est de VALIDER — elle n'écrit jamais rien,
 * n'invente jamais de correction, ne "répare" jamais silencieusement une
 * référence incohérente (cohérent avec le principe non négociable de
 * reconciliationEngine.ts : ne jamais corriger silencieusement une anomalie
 * financière).
 */
export function assertStripeReferenceEnvironmentConsistency(params: {
  activeEnvironment: StripeEnvironment;
  storedEnvironment: StripeEnvironment | null | undefined;
}): void {
  const { activeEnvironment, storedEnvironment } = params;

  if (!storedEnvironment) {
    if (activeEnvironment === "live") {
      throw stripeEnvironmentMismatchError();
    }
    return; // toléré uniquement en environnement test — voir doc ci-dessus
  }

  if (storedEnvironment !== activeEnvironment) {
    throw stripeEnvironmentMismatchError();
  }
}

/**
 * Code d'erreur INTERNE pour le mismatch `event.livemode` ↔ environnement
 * actif détecté sur un WEBHOOK Stripe entrant (voir
 * `isWebhookLivemodeConsistent()` ci-dessous et son usage dans
 * `functions/processStripeWebhook.ts`). Distinct de
 * `STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE` (qui concerne une RÉFÉRENCE
 * Stripe stockée réutilisée par une opération sortante) : celui-ci concerne
 * un ÉVÈNEMENT ENTRANT dont le mode Stripe natif (`event.livemode`) ne
 * correspond pas au mode actuellement actif côté Movi-K.
 */
export const STRIPE_WEBHOOK_LIVEMODE_MISMATCH_ERROR_CODE = "stripe_webhook_livemode_mismatch";

/**
 * Vérifie que le champ natif `event.livemode` d'un évènement Stripe déjà
 * VÉRIFIÉ (signature valide, voir `StripeProvider.constructVerifiedEvent()`)
 * est cohérent avec l'environnement Stripe ACTUELLEMENT ACTIF
 * (`PaymentProvider.environment`, dérivé de la clé secrète active).
 *
 * 🔒 DÉFENSE-EN-PROFONDEUR, JAMAIS UN REMPLACEMENT DE LA VÉRIFICATION DE
 * SIGNATURE : `event.livemode` est un champ natif Stripe, authentifié par la
 * signature `Stripe-Signature` exactement comme le reste du payload — il ne
 * s'agit PAS d'une seconde vérification cryptographique, mais d'un
 * contrôle de COHÉRENCE OPÉRATIONNELLE complémentaire : un endpoint webhook
 * mal configuré côté Dashboard Stripe (secret TEST branché alors que
 * Movi-K tourne en LIVE, ou inversement), un replay manuel d'évènement
 * depuis le Dashboard, ou une transition de clé mal séquencée pourraient
 * livrer un évènement AUTHENTIQUEMENT SIGNÉ mais appartenant au MAUVAIS
 * mode. Sans ce contrôle, un tel évènement serait traité comme n'importe
 * quel autre — potentiellement `payment_intent.succeeded` (mode test) vu
 * comme confirmant un paiement RÉEL, ou l'inverse.
 *
 * Pure et sans effet de bord (aucune écriture, aucun log) — l'appelant
 * (`processStripeWebhook.ts`) est responsable de journaliser/auditer le
 * rejet et de choisir la réponse HTTP appropriée (jamais un code déclenchant
 * une boucle de retries infinie côté Stripe, puisqu'un mismatch structurel
 * ne sera JAMAIS résolu par un simple nouvel essai).
 */
export function isWebhookLivemodeConsistent(params: {
  activeEnvironment: StripeEnvironment;
  eventLivemode: boolean;
}): boolean {
  const expectedLivemode = params.activeEnvironment === "live";
  return params.eventLivemode === expectedLivemode;
}

/**
 * Variante journalisée de `assertStripeReferenceEnvironmentConsistency()` —
 * à utiliser à CHAQUE point d'appel métier (jamais la fonction pure
 * ci-dessus directement dans les orchestrations) pour garantir qu'un rejet
 * est TOUJOURS accompagné d'un log financier structuré (BLOC I,
 * observability.ts) avant d'être propagé — un rejet d'isolation
 * d'environnement est une anomalie CRITIQUE qui doit être visible en
 * observabilité opérationnelle (Cloud Logging/alerting), pas seulement une
 * exception silencieuse remontée au client.
 */
export function assertStripeReferenceEnvironmentConsistencyOrLog(params: {
  activeEnvironment: StripeEnvironment;
  storedEnvironment: StripeEnvironment | null | undefined;
  operation: string;
  operationStartedAt: number;
  correlationId: string;
  identifiers: FinancialOperationIdentifiers;
  refType: string;
}): void {
  try {
    assertStripeReferenceEnvironmentConsistency(params);
  } catch (err) {
    logFinancialFailure(
      params.operation,
      params.operationStartedAt,
      STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE,
      params.identifiers,
      {
        correlationId: params.correlationId,
        message: `Incohérence d'environnement Stripe sur ${params.refType} : stocké="${
          params.storedEnvironment ?? "absent"
        }", actif="${params.activeEnvironment}".`,
      }
    );
    throw err;
  }
}
