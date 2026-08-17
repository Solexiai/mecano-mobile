// -----------------------------------------------------------------------------
// updatePricingConfiguration — Cloud Function callable (admin/super_admin).
//
// 🔒 RÈGLE CRITIQUE : ne JAMAIS écraser une pricing_version existante. Cette
// fonction crée TOUJOURS un nouveau document `pricing_versions/{newVersion}`
// puis met à jour le pointeur `pricing_configs/active`. Les missions
// historiques continuent de référencer leur `pricing_version` d'origine,
// qui demeure inchangée pour toujours (voir docs/FIRESTORE_ARCHITECTURE.md #9-10).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { PricingVersionDoc } from "../lib/types";

export interface UpdatePricingConfigurationRequest {
  newPricingVersion: string; // ex: 'MOVIK-PRICING-002'
  config: Omit<PricingVersionDoc, "pricing_version" | "is_active" | "effective_from">;
}

export const updatePricingConfiguration = onCall<UpdatePricingConfigurationRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);

    const { newPricingVersion, config } = request.data;
    if (!newPricingVersion || typeof newPricingVersion !== "string") {
      throw invalidArgument("newPricingVersion est requis.");
    }
    if (!config || !config.vehicle_rules || config.vehicle_rules.length === 0) {
      throw invalidArgument("config.vehicle_rules doit contenir au moins une règle.");
    }

    const newVersionRef = db.collection("pricing_versions").doc(newPricingVersion);

    await db.runTransaction(async (tx) => {
      const existing = await tx.get(newVersionRef);
      if (existing.exists) {
        throw failedPrecondition(
          `pricing_versions/${newPricingVersion} existe déjà — les versions sont immuables, choisir un nouvel identifiant.`
        );
      }

      const now = admin.firestore.Timestamp.now();

      tx.set(newVersionRef, {
        pricing_version: newPricingVersion,
        is_active: true,
        effective_from: now,
        ...config,
      });

      tx.set(
        db.collection("pricing_configs").doc("active"),
        {
          active_pricing_version: newPricingVersion,
          updated_at: now,
          updated_by_user_id: ctx.uid,
        },
        { merge: true }
      );

      writeAuditLogInTransaction(tx, {
        actorUserId: ctx.uid,
        actorRole: ctx.role ?? "unknown",
        action: "updatePricingConfiguration",
        sourceFunction: "updatePricingConfiguration",
        targetId: newPricingVersion,
        metadata: { vehicleRuleCount: config.vehicle_rules.length },
      });
    });

    return { success: true, pricingVersion: newPricingVersion };
  }
);
