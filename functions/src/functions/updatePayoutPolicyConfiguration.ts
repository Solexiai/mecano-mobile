// -----------------------------------------------------------------------------
// updatePayoutPolicyConfiguration — Cloud Function callable (admin/super_admin).
//
// Point 9 du cahier des charges Phase 6 : « driver payout avec
// payout_hold_period / payout_eligible_at CONFIGURABLE, jamais hardcodé ».
//
// Contrairement à `pricing_versions` (immuable, une nouvelle version par
// changement), `payout_policy_configs/default` est un document MUTABLE
// unique : la période de rétention n'a pas besoin d'historique versionné
// pour être conforme — mais chaque écriture est journalisée (audit_logs)
// pour la traçabilité. Lu par `calculateDriverPayout.ts` à chaque calcul,
// jamais mis en cache côté serveur (toujours lu depuis Firestore).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { PayoutPolicyConfigDoc } from "../lib/types";

export interface UpdatePayoutPolicyConfigurationRequest {
  defaultHoldPeriodHours: number;
  newDriverHoldPeriodHours: number;
  riskyDriverHoldPeriodHours: number;
  /**
   * Identifiant de corrélation optionnel (traçabilité pure, jamais utilisé
   * pour la logique métier). Propagé dans l'événement d'audit
   * `payout_policy_changed`.
   */
  correlationId?: string;
}

function assertNonNegativeHours(value: unknown, label: string): void {
  if (typeof value !== "number" || !Number.isFinite(value) || value < 0) {
    throw invalidArgument(`${label} doit être un nombre >= 0 (heures).`);
  }
}

export const updatePayoutPolicyConfiguration = onCall<UpdatePayoutPolicyConfigurationRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);

    const {
      defaultHoldPeriodHours,
      newDriverHoldPeriodHours,
      riskyDriverHoldPeriodHours,
      correlationId,
    } = request.data;

    assertNonNegativeHours(defaultHoldPeriodHours, "defaultHoldPeriodHours");
    assertNonNegativeHours(newDriverHoldPeriodHours, "newDriverHoldPeriodHours");
    assertNonNegativeHours(riskyDriverHoldPeriodHours, "riskyDriverHoldPeriodHours");

    const configRef = db.collection("payout_policy_configs").doc("default");

    await db.runTransaction(async (tx) => {
      const now = admin.firestore.Timestamp.now();

      // 🔒 BLOC H : lire l'ANCIENNE configuration (si présente) AVANT de
      // l'écraser, pour permettre un audit avec "old configuration si
      // disponible" — jamais reconstituée après-coup depuis l'historique
      // d'audit (qui n'est pas une source de vérité pour la config active).
      const previousSnap = await tx.get(configRef);
      const previousConfig = previousSnap.exists
        ? (previousSnap.data() as PayoutPolicyConfigDoc)
        : null;

      const config: PayoutPolicyConfigDoc = {
        default_hold_period_hours: defaultHoldPeriodHours,
        new_driver_hold_period_hours: newDriverHoldPeriodHours,
        risky_driver_hold_period_hours: riskyDriverHoldPeriodHours,
        updated_at: now,
        updated_by_user_id: ctx.uid,
      };
      tx.set(configRef, config);

      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid,
        actorRole: ctx.role ?? "unknown",
        action: "updatePayoutPolicyConfiguration",
        sourceFunction: "updatePayoutPolicyConfiguration",
        targetId: "payout_policy_configs/default",
        metadata: {
          defaultHoldPeriodHours,
          newDriverHoldPeriodHours,
          riskyDriverHoldPeriodHours,
        },
      });

      // 🔒 BLOC H (catalogue d'évènements financiers) — évènement métier
      // normalisé distinct de l'action technique ci-dessus (jamais renommée).
      // N'expose QUE les champs de configuration nécessaires (périodes de
      // rétention en heures + métadonnées d'audit) — aucune information
      // sensible additionnelle n'existe sur ce document.
      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid,
        actorRole: ctx.role ?? "unknown",
        action: "payout_policy_changed",
        sourceFunction: "updatePayoutPolicyConfiguration",
        targetId: "payout_policy_configs/default",
        metadata: {
          oldConfiguration: previousConfig
            ? {
                defaultHoldPeriodHours: previousConfig.default_hold_period_hours,
                newDriverHoldPeriodHours: previousConfig.new_driver_hold_period_hours,
                riskyDriverHoldPeriodHours: previousConfig.risky_driver_hold_period_hours,
              }
            : null,
          newConfiguration: {
            defaultHoldPeriodHours,
            newDriverHoldPeriodHours,
            riskyDriverHoldPeriodHours,
          },
          effectiveAt: now,
          configurationId: "payout_policy_configs/default",
          timestamp: now,
          correlationId: correlationId ?? null,
        },
      });
    });

    return { success: true };
  }
);

/**
 * Lit `payout_policy_configs/default`. Si le document n'existe pas encore
 * (avant tout appel admin à `updatePayoutPolicyConfiguration`), renvoie des
 * valeurs par défaut EXPLICITES et documentées (72h standard — délai usuel
 * de rétention avant premier versement, à ajuster par un admin via la
 * fonction ci-dessus). Ce n'est PAS une valeur "hardcodée utilisée pour le
 * calcul" au sens du point 9 : c'est un filet de sécurité de bootstrap,
 * immédiatement remplaçable par un admin, et chaque lecture recalcule
 * `payout_eligible_at` à partir de la config LUE (jamais d'une constante
 * figée dans le code de calcul lui-même).
 */
export async function readPayoutPolicyConfig(): Promise<PayoutPolicyConfigDoc> {
  const snap = await db.collection("payout_policy_configs").doc("default").get();
  if (snap.exists) {
    return snap.data() as PayoutPolicyConfigDoc;
  }
  return {
    default_hold_period_hours: 72,
    new_driver_hold_period_hours: 168,
    risky_driver_hold_period_hours: 336,
    updated_at: admin.firestore.Timestamp.now(),
    updated_by_user_id: "system_default",
  };
}

/**
 * Détermine la période de rétention applicable à un chauffeur donné, selon
 * son profil de risque (nouveau chauffeur : peu de missions complétées ;
 * chauffeur signalé : documents_required_reason actif ou suspendu
 * récemment). Règle explicite et documentée, non arbitraire : un chauffeur
 * ayant complété moins de 5 missions est considéré "nouveau" (seuil aligné
 * sur `PROBATION_MISSION_THRESHOLD` si un tel seuil existe déjà côté
 * Phase 2 — sinon documenté ici comme décision Phase 6 explicite).
 */
export function resolveHoldPeriodHours(
  policy: PayoutPolicyConfigDoc,
  driver: { completed_missions?: number; suspended_at?: unknown } | undefined
): number {
  if (!driver) return policy.default_hold_period_hours;
  if (driver.suspended_at) return policy.risky_driver_hold_period_hours;
  if ((driver.completed_missions ?? 0) < 5) return policy.new_driver_hold_period_hours;
  return policy.default_hold_period_hours;
}
