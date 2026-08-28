// -----------------------------------------------------------------------------
// updateRuntimeFlags — Cloud Function callable (admin/super_admin).
//
// Point d'entrée UNIQUE et privilégié pour modifier `system_config/
// runtime_flags` (Phase 7, Bloc X). Calqué sur le pattern déjà validé de
// `updatePayoutPolicyConfiguration.ts` : document mutable singleton, lecture
// de l'ANCIENNE configuration DANS la transaction avant écrasement, audit
// journalisé via l'infrastructure EXISTANTE (`writeAuditLogInTransaction`,
// aucun second système de logs créé).
//
// 🔒 Auto-bootstrap : si `system_config/runtime_flags` n'existe pas encore
// (premier appel admin après déploiement Phase 8), cette fonction le crée
// avec les 4 flags à `true` (voir RUNTIME_FLAG_BOOTSTRAP_DEFAULTS) AVANT
// d'appliquer les changements demandés dans CETTE même transaction — un
// admin n'a donc jamais besoin d'une étape manuelle séparée pour initialiser
// la configuration (X-13), et ne peut jamais accidentellement écraser un
// document déjà existant (la lecture précède toujours l'écriture).
//
// 🔒 Validation stricte (X-4) : seules les 4 clés `ALL_RUNTIME_FLAG_KEYS`
// sont acceptées ; toute clé inconnue -> invalid-argument (jamais un champ
// arbitraire persisté). Chaque valeur doit être un booléen strict.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  ALL_RUNTIME_FLAG_KEYS,
  RUNTIME_FLAGS_COLLECTION,
  RUNTIME_FLAGS_DOC_ID,
  RUNTIME_FLAG_BOOTSTRAP_DEFAULTS,
  RuntimeFlagKey,
  RuntimeFlagsDoc,
} from "../lib/runtimeFlags";

export interface UpdateRuntimeFlagsRequest {
  /**
   * Uniquement les flags à MODIFIER (patch partiel) — les flags omis
   * conservent leur valeur actuelle (ou leur défaut de bootstrap si le
   * document vient d'être créé par cet appel). Permet à un admin de couper
   * UN SEUL flag en urgence sans devoir connaître/renvoyer l'état complet
   * des 3 autres.
   */
  flags: Partial<Record<RuntimeFlagKey, boolean>>;
  /** Identifiant de corrélation optionnel (traçabilité pure), propagé dans l'audit. */
  correlationId?: string;
}

function assertValidFlagsPatch(flags: unknown): asserts flags is Partial<Record<RuntimeFlagKey, boolean>> {
  if (!flags || typeof flags !== "object" || Array.isArray(flags)) {
    throw invalidArgument("flags doit être un objet { <nomDuFlag>: boolean, ... }.");
  }
  const entries = Object.entries(flags as Record<string, unknown>);
  if (entries.length === 0) {
    throw invalidArgument("flags ne peut pas être vide — au moins un flag à modifier est requis.");
  }
  for (const [key, value] of entries) {
    if (!ALL_RUNTIME_FLAG_KEYS.includes(key as RuntimeFlagKey)) {
      throw invalidArgument(
        `Clé de flag inconnue: '${key}'. Clés valides: ${ALL_RUNTIME_FLAG_KEYS.join(", ")}.`
      );
    }
    if (typeof value !== "boolean") {
      throw invalidArgument(`La valeur du flag '${key}' doit être un booléen strict (reçu: ${typeof value}).`);
    }
  }
}

export const updateRuntimeFlags = onCall<UpdateRuntimeFlagsRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const { flags, correlationId } = request.data;
  assertValidFlagsPatch(flags);

  const configRef = db.collection(RUNTIME_FLAGS_COLLECTION).doc(RUNTIME_FLAGS_DOC_ID);

  const { previousValues, newValues } = await db.runTransaction(async (tx) => {
    const now = admin.firestore.Timestamp.now();

    // 🔒 Lecture DANS la transaction — l'ANCIENNE configuration (si présente)
    // est capturée AVANT tout écrasement, pour un audit avec old/new values
    // toujours cohérentes (jamais reconstituée après-coup depuis l'audit).
    const snap = await tx.get(configRef);
    const existing = snap.exists ? (snap.data() as Partial<RuntimeFlagsDoc>) : null;

    // Base = document existant, ou defaults de BOOTSTRAP si le document
    // n'existe pas encore (X-13 — jamais les fail-safe defaults à `false`
    // ici : un bootstrap doit démarrer Movi-K opérationnel, pas bloqué).
    const baseValues: Record<RuntimeFlagKey, boolean> = existing
      ? {
          accept_new_delivery_requests: existing.accept_new_delivery_requests ?? RUNTIME_FLAG_BOOTSTRAP_DEFAULTS.accept_new_delivery_requests,
          allow_driver_acceptance: existing.allow_driver_acceptance ?? RUNTIME_FLAG_BOOTSTRAP_DEFAULTS.allow_driver_acceptance,
          payments_enabled: existing.payments_enabled ?? RUNTIME_FLAG_BOOTSTRAP_DEFAULTS.payments_enabled,
          driver_payouts_enabled: existing.driver_payouts_enabled ?? RUNTIME_FLAG_BOOTSTRAP_DEFAULTS.driver_payouts_enabled,
        }
      : { ...RUNTIME_FLAG_BOOTSTRAP_DEFAULTS };

    const previous = { ...baseValues };
    const updated: Record<RuntimeFlagKey, boolean> = { ...baseValues };
    for (const [key, value] of Object.entries(flags)) {
      updated[key as RuntimeFlagKey] = value as boolean;
    }

    const doc: RuntimeFlagsDoc = {
      ...updated,
      updated_at: now,
      updated_by_user_id: ctx.uid,
    };
    tx.set(configRef, doc);

    // 🔒 Audit — réutilise EXACTEMENT l'infrastructure existante
    // (writeAuditLogInTransaction, lib/audit.ts), aucun second système de
    // logs. Un SEUL évènement par appel, même si plusieurs flags changent en
    // même temps — old_values/new_values complets dans metadata permettent
    // de savoir précisément ce qui a changé sans générer un log par flag
    // (éviter des logs incohérents/fragmentés pour une seule action admin).
    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "runtime_flags_updated",
      sourceFunction: "updateRuntimeFlags",
      targetId: `${RUNTIME_FLAGS_COLLECTION}/${RUNTIME_FLAGS_DOC_ID}`,
      metadata: {
        oldValues: previous,
        newValues: updated,
        changedKeys: Object.keys(flags),
        wasBootstrapped: !existing,
        correlationId: correlationId ?? null,
      },
    });

    return { previousValues: previous, newValues: updated };
  });

  return { success: true, previousValues, newValues };
});
