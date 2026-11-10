// -----------------------------------------------------------------------------
// customerDeletion.ts — règles pures pour effacer un client (Daniel,
// 2026-11-10) et pour la liste « Accepte les offres ».
//
// Décisions de Daniel :
//   - Effacer = ANONYMISER. Le compte et les données personnelles partent
//     (connexion, courriel, téléphone, carnet d'adresses, notes internes,
//     notifications). Les livraisons et paiements restent : preuves
//     comptables et fiscales à garder 6 ans. Un client sans aucune livraison
//     ni paiement est effacé au complet.
//   - Super-admin seulement.
//   - Bloqué s'il a une livraison en cours, un solde dû ou un litige ouvert.
// -----------------------------------------------------------------------------

import { millisOf } from "./customerFile";

type Doc = Record<string, any>;

/** Livraisons pas encore terminées : on n'efface pas un client en cours de route. */
export const ACTIVE_MISSION_STATUSES = new Set<string>([
  "searching_driver",
  "offered",
  "assigned",
  "driver_to_pickup",
  "arrived_at_pickup",
  "picked_up",
  "in_transit",
  "arrived_at_dropoff",
  "delivered",
]);

/** Paiements pas réglés : carte retenue, débit en cours ou refusé. */
export const OPEN_PAYMENT_STATUSES = new Set<string>([
  "authorization_pending",
  "authorized",
  "capture_pending",
  "capture_failed",
]);

/** Contestation de paiement (Stripe) ou litige Movi-K. */
export const DISPUTE_STATUSES = new Set<string>(["disputed", "chargeback"]);

const STAFF_ROLES = ["analyst", "admin", "super_admin"];

export type DeletionMode = "erase" | "anonymize";

export interface DeletionInput {
  actorUid: string;
  targetUid: string;
  roles: string[];
  hasDriverProfile: boolean;
  missions: Doc[];
  payments: Doc[];
}

/** Raisons qui empêchent d'effacer ce client (vide = on peut). */
export function deletionBlockers(input: DeletionInput): string[] {
  const reasons: string[] = [];
  if (input.actorUid === input.targetUid) {
    reasons.push("Vous ne pouvez pas effacer votre propre compte.");
  }
  if (input.roles.some((r) => STAFF_ROLES.includes(r))) {
    reasons.push("Ce compte a un rôle de personnel : retirez-le d'abord.");
  }
  if (input.hasDriverProfile || input.roles.includes("driver")) {
    reasons.push("C'est aussi un chauffeur : supprimez d'abord son dossier chauffeur.");
  }
  const active = input.missions.filter((m) => ACTIVE_MISSION_STATUSES.has(String(m.status))).length;
  if (active > 0) {
    reasons.push(`${active} livraison(s) en cours : terminez-les ou annulez-les d'abord.`);
  }
  const owing = input.payments.filter((p) =>
    OPEN_PAYMENT_STATUSES.has(String(p.status)) ||
    (p.status === "failed" && p.failure_code === "capture_abandoned_after_retries")
  ).length;
  if (owing > 0) {
    reasons.push(`${owing} paiement(s) pas réglé(s) : solde dû ou carte retenue.`);
  }
  const disputes =
    input.missions.filter((m) => m.status === "disputed").length +
    input.payments.filter((p) => DISPUTE_STATUSES.has(String(p.status))).length;
  if (disputes > 0) {
    reasons.push(`${disputes} litige(s) ouvert(s) : réglez-les d'abord.`);
  }
  return reasons;
}

/**
 * Un client qui a déjà réservé ou payé garde son historique (anonymisé) ;
 * un compte sans livraison ni paiement est effacé au complet.
 */
export function deletionMode(missions: Doc[], payments: Doc[]): DeletionMode {
  const booked = missions.some((m) => m.status !== "draft" && m.status !== "quoted");
  return booked || payments.length > 0 ? "anonymize" : "erase";
}

/**
 * Ce qui reste du profil d'un client anonymisé : aucune donnée personnelle,
 * juste de quoi relier ses anciennes livraisons à « Client supprimé ».
 */
export function anonymizedUserDoc(
  original: Doc,
  uid: string,
  actorUid: string,
  deletedAt: unknown
): Doc {
  return {
    uid,
    roles: ["customer"],
    full_name: "Client supprimé",
    deleted: true,
    deleted_at: deletedAt,
    deleted_by: actorUid,
    is_disabled: true,
    ...(original.created_at ? { created_at: original.created_at } : {}),
  };
}

/**
 * Clients dont la DERNIÈRE réservation dit « Je souhaite recevoir des
 * offres ». Un client qui a décoché la case à une réservation suivante n'y
 * est plus (loi canadienne anti-pourriel : consentement exprès).
 */
export function latestMarketingOptIns(
  rows: Array<{ customerId: unknown; createdAt: unknown; optIn: boolean }>
): string[] {
  const latest = new Map<string, { at: number; optIn: boolean }>();
  for (const row of rows) {
    if (typeof row.customerId !== "string" || !row.customerId) continue;
    const at = millisOf(row.createdAt) ?? 0;
    const current = latest.get(row.customerId);
    if (!current || at >= current.at) latest.set(row.customerId, { at, optIn: row.optIn });
  }
  return [...latest.entries()].filter(([, v]) => v.optIn).map(([id]) => id).sort();
}
