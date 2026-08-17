// -----------------------------------------------------------------------------
// registerAsDriver — Cloud Function callable, SELF-SERVICE (tout utilisateur
// connecté).
//
// CONTEXTE (trouvé lors de l'audit Movi-K) : firestore.rules exige le custom
// claim `driver` pour pouvoir créer son propre document
// `driver_profiles/{uid}` (voir `isDriver()` + règle `create` de
// `driver_profiles`). Or aucune Cloud Function n'existait pour permettre à
// un nouvel utilisateur de s'attribuer ce rôle — `setUserRole` est réservé
// au super_admin. Ce chaînon manquant bloquait entièrement le flux
// d'inscription chauffeur.
//
// 🔒 SÉCURITÉ : cette fonction est volontairement peu privilégiée. Elle
// AJOUTE uniquement le rôle `driver` aux rôles existants de l'appelant
// (jamais retirer un rôle existant, jamais définir un autre rôle que
// `driver`). Elle NE DONNE AUCUN PRIVILÈGE OPÉRATIONNEL : un compte avec le
// claim `driver` mais dont `driver_profiles.status != 'approved'` ne peut ni
// passer en ligne, ni recevoir d'offres, ni accepter de mission (voir
// `canGoOnline` côté Dart et les vérifications explicites dans
// `acceptDelivery`). Le claim `driver` sert uniquement de porte d'entrée
// pour SOUMETTRE une candidature, jamais pour exercer l'activité.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { authAdmin } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { PlatformRole, PlatformRoles } from "../lib/types";

export const registerAsDriver = onCall(async (request) => {
  const ctx = requireSignedIn(request);

  const currentRoles: PlatformRole[] =
    ctx.roles.length > 0 ? ctx.roles : [PlatformRoles.CUSTOMER];

  if (currentRoles.includes(PlatformRoles.DRIVER)) {
    return { success: true, roles: currentRoles, note: "Le rôle driver est déjà présent." };
  }

  const newRoles = [...currentRoles, PlatformRoles.DRIVER];

  await authAdmin.setCustomUserClaims(ctx.uid, {
    role: currentRoles[0] ?? PlatformRoles.CUSTOMER,
    roles: newRoles,
  });

  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "unknown",
    action: "registerAsDriver",
    sourceFunction: "registerAsDriver",
    targetId: ctx.uid,
    metadata: { newRoles },
  });

  return {
    success: true,
    roles: newRoles,
    note: "Le client doit appeler getIdTokenResult(forceRefresh: true) avant de créer driver_profiles.",
  };
});
