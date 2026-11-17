// -----------------------------------------------------------------------------
// userKind.ts — client, chauffeur ou personnel ? (Daniel, 2026-11-17)
//
// « Si la personne s'inscrit comme chauffeur, elle ne peut pas être placée
// dans les clients : il faut qu'elle s'inscrive comme client à part — deux
// inscriptions. » Un compte est donc UNE chose :
//   - personnel  : analyste, admin ou super-admin (compté à part au tableau
//                  de bord) ;
//   - chauffeur  : a le rôle « driver », quel que soit son statut ;
//   - client     : le reste (rôle « customer » seul).
// Le personnel garde le droit de tester (prix, réservations, dossier chauffeur).
// -----------------------------------------------------------------------------

import { failedPrecondition } from "./errors";

export type UserKind = "staff" | "driver" | "customer" | "none";

const STAFF = new Set(["analyst", "admin", "super_admin"]);

export function userKind(roles: readonly string[] | undefined): UserKind {
  const r = roles ?? [];
  if (r.some((x) => STAFF.has(x))) return "staff";
  if (r.includes("driver")) return "driver";
  if (r.includes("customer")) return "customer";
  return "none";
}

/** Un compte chauffeur ne demande pas de prix et ne réserve pas. */
export function refuseDriverAsCustomer(roles: readonly string[] | undefined): void {
  if (userKind(roles) !== "driver") return;
  throw failedPrecondition(
    "Ce compte est un compte chauffeur. Pour réserver une livraison, créez un compte client avec une autre adresse courriel."
  );
}
