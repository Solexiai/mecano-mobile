// -----------------------------------------------------------------------------
// runtimeFlags.ts — Kill switches / feature flags MINIMAUX, centralisés,
// server-authoritative (Phase 7, Bloc X).
//
// OBJECTIF (directive utilisateur) : permettre à un admin de désactiver
// rapidement une opération critique SANS republier l'application, via UN
// SEUL document Firestore mutable, lu par UN SEUL helper serveur — jamais un
// "magic boolean" dupliqué dans chaque Cloud Function. Ce n'est PAS une
// plateforme complète de feature management (voir X-12 : pas de cache, pas
// de TTL, pas de SDK client — juste 4 interrupteurs MVP).
//
// DOCUMENT : `system_config/runtime_flags` (singleton) — convention alignée
// sur les configs sensibles déjà existantes (`payout_policy_configs/default`,
// `tax_configs/{...}`, `pricing_configs/active`) : lecture Cloud-Functions
// (et admin le cas échéant), écriture STRICTEMENT Cloud-Function-only (voir
// firestore.rules).
//
// FLAGS MVP (aucun autre sans besoin démontré — X-1) :
//   - accept_new_delivery_requests : autorise la création de NOUVELLES
//     missions (createDeliveryRequest.ts). N'affecte jamais une mission déjà
//     créée.
//   - allow_driver_acceptance : autorise l'acceptation de NOUVELLES missions
//     par un chauffeur (acceptDelivery.ts). N'affecte jamais une mission déjà
//     assignée (déjà en cours de livraison).
//   - payments_enabled : autorise la création de NOUVELLES expositions
//     financières côté client (autorisation de paiement). N'affecte JAMAIS
//     un refund/dispute/compensation/correction ledger sur un paiement déjà
//     existant — un kill switch paiement empêche de PRENDRE plus d'argent,
//     jamais d'en RENDRE ou d'en CORRIGER.
//   - driver_payouts_enabled : autorise le déclenchement d'un NOUVEL appel
//     réel au fournisseur pour verser un chauffeur (submitDriverPayout).
//     N'affecte jamais une compensation comptable, une réconciliation ou une
//     correction de ledger sur un payout déjà existant.
//
// FAIL-SAFE (X-3, X-4) — POLITIQUE EXPLICITE ET DOCUMENTÉE, jamais implicite :
//   - `payments_enabled` / `driver_payouts_enabled` (FINANCIER) :
//     document absent, champ absent, type invalide, ou erreur Firestore
//     (offline/permission/timeout) => FAIL CLOSED (`false`). Une opération
//     financière RISQUÉE (prendre de l'argent, verser de l'argent) ne doit
//     JAMAIS être autorisée par accident sur une configuration corrompue ou
//     inaccessible.
//   - `accept_new_delivery_requests` / `allow_driver_acceptance`
//     (OPÉRATIONNEL, non financier au sens strict — mais un chauffeur qui
//     accepte enclenche IMMÉDIATEMENT une autorisation de paiement dans
//     acceptDelivery.ts) : même politique FAIL CLOSED que le financier, par
//     cohérence et simplicité (UNE SEULE politique documentée, jamais deux
//     comportements dispersés selon le flag — voir directive X-3). C'est
//     pourquoi le BOOTSTRAP (X-13) est CRITIQUE : sans le document initial
//     seedé à `true` pour ces 4 flags, un déploiement Phase 8 bloquerait
//     silencieusement TOUT Movi-K (aucune mission, aucun chauffeur, aucun
//     paiement, aucun versement) — voir `ensureRuntimeFlagsBootstrapped()`
//     ci-dessous et docs/PHASE7_BUG_REPORT.md (table X) pour la procédure.
//
// AUCUN CACHE (X-12) : chaque appel à `isRuntimeFlagEnabled()` déclenche une
// lecture Firestore directe. Aucun TTL, aucune mémoïsation process-local.
// C'est un choix DÉLIBÉRÉ pour un mécanisme de kill switch d'urgence : un
// admin qui bascule un flag doit voir l'effet sur le TOUT PROCHAIN appel
// serveur, jamais après un délai de propagation de cache. Le coût (une
// lecture Firestore de plus par action critique) est jugé acceptable pour
// ce MVP (voir X-12).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { failedPrecondition } from "./errors";

// -----------------------------------------------------------------------------
// Types
// -----------------------------------------------------------------------------

/** Les 4 flags MVP — clé stable, jamais renommée sans migration explicite. */
export const RuntimeFlagKeys = {
  ACCEPT_NEW_DELIVERY_REQUESTS: "accept_new_delivery_requests",
  ALLOW_DRIVER_ACCEPTANCE: "allow_driver_acceptance",
  PAYMENTS_ENABLED: "payments_enabled",
  DRIVER_PAYOUTS_ENABLED: "driver_payouts_enabled",
} as const;

export type RuntimeFlagKey = (typeof RuntimeFlagKeys)[keyof typeof RuntimeFlagKeys];

/** Liste ordonnée, utilisée pour la validation stricte des clés (X-4 update). */
export const ALL_RUNTIME_FLAG_KEYS: RuntimeFlagKey[] = [
  RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS,
  RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE,
  RuntimeFlagKeys.PAYMENTS_ENABLED,
  RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED,
];

/** Forme du document Firestore `system_config/runtime_flags`. */
export interface RuntimeFlagsDoc {
  accept_new_delivery_requests: boolean;
  allow_driver_acceptance: boolean;
  payments_enabled: boolean;
  driver_payouts_enabled: boolean;
  updated_at: FirebaseFirestore.Timestamp | FirebaseFirestore.FieldValue;
  updated_by_user_id: string;
}

/**
 * Défaults de FAIL-SAFE (jamais utilisés pour ÉCRIRE le document — voir
 * `ensureRuntimeFlagsBootstrapped()` pour la seule fonction qui écrit un
 * document initial). Utilisés UNIQUEMENT par `isRuntimeFlagEnabled()` comme
 * valeur de repli en lecture quand le document/champ est absent ou invalide.
 *
 * 🔒 Politique unique documentée (X-3) : FAIL CLOSED pour LES 4 flags. Un
 * flag absent/invalide/inaccessible se comporte comme "désactivé" — jamais
 * "activé par défaut" pour un mécanisme dont le but est justement de couper
 * une opération en urgence. Le risque inverse (bootstrap manquant bloquant
 * tout Movi-K) est couvert par X-13, pas en assouplissant ce fail-safe.
 */
export const RUNTIME_FLAG_FAIL_SAFE_DEFAULTS: Record<RuntimeFlagKey, boolean> = {
  [RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS]: false,
  [RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE]: false,
  [RuntimeFlagKeys.PAYMENTS_ENABLED]: false,
  [RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED]: false,
};

/**
 * Valeurs de BOOTSTRAP (X-13) — utilisées UNIQUEMENT à la création du
 * document initial s'il n'existe pas encore (jamais pour écraser un document
 * existant, même partiellement). Toutes à `true` : au premier déploiement,
 * Movi-K doit fonctionner normalement (aucune opération bloquée par défaut).
 * Un admin doit ensuite désactiver EXPLICITEMENT un flag via
 * `updateRuntimeFlags` pour couper une opération — jamais l'inverse.
 */
export const RUNTIME_FLAG_BOOTSTRAP_DEFAULTS: Record<RuntimeFlagKey, boolean> = {
  [RuntimeFlagKeys.ACCEPT_NEW_DELIVERY_REQUESTS]: true,
  [RuntimeFlagKeys.ALLOW_DRIVER_ACCEPTANCE]: true,
  [RuntimeFlagKeys.PAYMENTS_ENABLED]: true,
  [RuntimeFlagKeys.DRIVER_PAYOUTS_ENABLED]: true,
};

export const RUNTIME_FLAGS_COLLECTION = "system_config";
export const RUNTIME_FLAGS_DOC_ID = "runtime_flags";

function runtimeFlagsRef(): FirebaseFirestore.DocumentReference {
  return db.collection(RUNTIME_FLAGS_COLLECTION).doc(RUNTIME_FLAGS_DOC_ID);
}

// -----------------------------------------------------------------------------
// Lecture — helper CENTRAL unique, appelé par CHAQUE Cloud Function critique.
// -----------------------------------------------------------------------------

/** Résultat détaillé d'une résolution de flag — utile pour le logging/debug
 *  sans jamais exposer ce détail au client (voir X-10, buildKillSwitchError). */
export type RuntimeFlagResolutionReason =
  | "document_found_valid"
  | "document_missing"
  | "field_missing"
  | "field_invalid_type"
  | "firestore_error";

export interface RuntimeFlagResolution {
  key: RuntimeFlagKey;
  enabled: boolean;
  reason: RuntimeFlagResolutionReason;
}

/**
 * Lit `system_config/runtime_flags` et résout la valeur effective d'UN flag,
 * en appliquant explicitement le fail-safe (X-3/X-4) pour CHAQUE cas
 * anormal : document absent, champ absent, type incorrect, erreur Firestore.
 * AUCUN cache — lecture Firestore directe à chaque appel (voir X-12).
 *
 * 🔒 C'est LE SEUL point du code qui décide "le document est-il valide ?" —
 * jamais dupliqué/réinterprété différemment dans une Cloud Function
 * consommatrice, ce qui garantit une politique de fail-safe cohérente
 * partout (directive X-4 : "éviter toute logique dispersée").
 */
export async function resolveRuntimeFlag(key: RuntimeFlagKey): Promise<RuntimeFlagResolution> {
  let snap: FirebaseFirestore.DocumentSnapshot;
  try {
    snap = await runtimeFlagsRef().get();
  } catch {
    // Firestore temporairement inaccessible (timeout, panne, permission
    // dénormalisée côté Admin SDK) : fail-safe, jamais une exception qui
    // remonterait un code d'erreur ambigu à l'appelant métier.
    return { key, enabled: RUNTIME_FLAG_FAIL_SAFE_DEFAULTS[key], reason: "firestore_error" };
  }

  if (!snap.exists) {
    return { key, enabled: RUNTIME_FLAG_FAIL_SAFE_DEFAULTS[key], reason: "document_missing" };
  }

  const data = snap.data() as Partial<Record<RuntimeFlagKey, unknown>> | undefined;
  const rawValue = data?.[key];

  if (rawValue === undefined || rawValue === null) {
    return { key, enabled: RUNTIME_FLAG_FAIL_SAFE_DEFAULTS[key], reason: "field_missing" };
  }
  if (typeof rawValue !== "boolean") {
    return { key, enabled: RUNTIME_FLAG_FAIL_SAFE_DEFAULTS[key], reason: "field_invalid_type" };
  }

  return { key, enabled: rawValue, reason: "document_found_valid" };
}

/**
 * Raccourci booléen pour les sites d'appel qui n'ont besoin que de la valeur
 * (la majorité des Cloud Functions ci-dessous). Utiliser
 * `resolveRuntimeFlag()` directement si le détail (`reason`) est utile pour
 * l'observabilité.
 */
export async function isRuntimeFlagEnabled(key: RuntimeFlagKey): Promise<boolean> {
  const resolution = await resolveRuntimeFlag(key);
  return resolution.enabled;
}

// -----------------------------------------------------------------------------
// Erreur structurée (X-10) — utilisée par CHAQUE Cloud Function qui refuse une
// opération à cause d'un kill switch. N'expose JAMAIS : le nom du document
// Firestore, la valeur brute du flag, la raison technique (`reason`), ni
// aucun détail d'implémentation — uniquement un code d'erreur stable et un
// message générique orienté utilisateur final, traduit côté client (voir
// lib/l10n/app_strings.dart, clé 'service_temporarily_unavailable').
// -----------------------------------------------------------------------------

export const KILL_SWITCH_ERROR_CODE = "service_temporarily_unavailable";

/**
 * Construit l'erreur structurée à lever par une Cloud Function quand un kill
 * switch refuse l'opération. Code HttpsError `"failed-precondition"` (déjà
 * utilisé dans tout le projet pour "état/config serveur empêche l'action" —
 * voir acceptDelivery.ts/createDeliveryRequest.ts) + message stable
 * `KILL_SWITCH_ERROR_CODE`, jamais le nom du flag, sa valeur, ni la raison
 * technique de résolution (`RuntimeFlagResolutionReason`) — voir X-10.
 */
export function killSwitchRefusal(): ReturnType<typeof failedPrecondition> {
  return failedPrecondition(KILL_SWITCH_ERROR_CODE);
}

// -----------------------------------------------------------------------------
// Bootstrap (X-13) — crée le document initial UNIQUEMENT s'il n'existe pas
// encore, avec les 4 flags à `true` (Movi-K opérationnel par défaut). Ne
// modifie JAMAIS un document déjà existant, même partiel — c'est
// `updateRuntimeFlags` (Cloud Function admin) qui gère toute évolution
// ultérieure. Conçu pour être appelé :
//   - manuellement une fois en Phase 8 (script/console Firebase), ou
//   - automatiquement par `updateRuntimeFlags` elle-même si le document
//     n'existe pas encore au moment du premier appel admin (voir
//     updateRuntimeFlags.ts) — garantissant qu'un admin peut TOUJOURS
//     initialiser la configuration sans dépendre d'une étape manuelle
//     séparée, sans jamais écraser une configuration déjà présente.
// -----------------------------------------------------------------------------

export async function ensureRuntimeFlagsBootstrapped(
  actorUserId: string
): Promise<{ created: boolean }> {
  const ref = runtimeFlagsRef();
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(ref);
    if (snap.exists) {
      return { created: false };
    }
    const doc: RuntimeFlagsDoc = {
      ...RUNTIME_FLAG_BOOTSTRAP_DEFAULTS,
      updated_at: admin.firestore.FieldValue.serverTimestamp(),
      updated_by_user_id: actorUserId,
    };
    tx.set(ref, doc);
    return { created: true };
  });
}
