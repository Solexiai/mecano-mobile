// -----------------------------------------------------------------------------
// updatePricingConfiguration — Cloud Function callable (super_admin).
//
// 🔒 RÈGLE CRITIQUE : ne JAMAIS écraser une pricing_version existante. Cette
// fonction crée TOUJOURS un nouveau document `pricing_versions/{newVersion}`
// puis met à jour le pointeur `pricing_configs/active`. Les missions
// historiques continuent de référencer leur `pricing_version` d'origine,
// qui demeure inchangée pour toujours (voir docs/FIRESTORE_ARCHITECTURE.md #9-10).
//
// Grille de tarifs admin (24 octobre 2026) :
//   - réservé au super admin (les tarifs fixent ce que paient les clients et
//     ce que reçoivent les chauffeurs) ;
//   - chaque champ est vérifié contre des bornes (pricingConfigValidation.ts)
//     et le chauffeur doit toujours recevoir un montant positif ;
//   - les taxes et la politique de pourboire sont recopiées de la version
//     active, jamais acceptées du brouillon ;
//   - `basedOnPricingVersion` doit être la version active : deux personnes ne
//     peuvent pas s'écraser sans le savoir ;
//   - changer les frais d'annulation exige de confirmer que le texte
//     d'annulation des conditions de réservation a été mis à jour.
// -----------------------------------------------------------------------------

import { HttpsError, onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn, requireSuperAdmin } from "../lib/auth";
import { aborted, failedPrecondition, invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { missionFeePolicyFrom } from "../lib/missionFees";
import { asPricingVersion, validatePricingDraft } from "../lib/pricingConfigValidation";
import { PricingVersionDoc } from "../lib/types";

export interface UpdatePricingConfigurationRequest {
  /** Optionnel : identifiant généré par le serveur s'il est absent. */
  newPricingVersion?: string;
  /** Version active au moment où l'admin a ouvert la grille. */
  basedOnPricingVersion?: string | null;
  /** Brouillon de la grille (voir PricingDraft). */
  config: unknown;
  /** Obligatoire à `true` quand les frais d'annulation changent. */
  feeTextUpdated?: boolean;
  changeNote?: string | null;
}

const VERSION_PATTERN = /^[A-Za-z0-9_-]{3,80}$/;

function generatedVersionId(now: Date): string {
  const iso = now.toISOString(); // 2026-10-24T14:30:05.123Z
  const stamp = iso.slice(0, 19).replace(/[-:]/g, "").replace("T", "-");
  return `MOVIK-PRICING-${stamp}`;
}

export const updatePricingConfiguration = onCall<UpdatePricingConfigurationRequest>(
  async (request) => {
    const ctx = requireSignedIn(request);
    requireSuperAdmin(ctx);

    const data = request.data ?? ({} as UpdatePricingConfigurationRequest);
    const requestedVersion =
      typeof data.newPricingVersion === "string" ? data.newPricingVersion.trim() : "";
    if (requestedVersion && !VERSION_PATTERN.test(requestedVersion)) {
      throw invalidArgument("Identifiant de version invalide (lettres, chiffres, - et _).");
    }
    const changeNote =
      typeof data.changeNote === "string" && data.changeNote.trim()
        ? data.changeNote.trim().slice(0, 500)
        : null;

    const validation = validatePricingDraft(data.config);
    if (!validation.draft) {
      throw new HttpsError("invalid-argument", "La grille de tarifs contient des erreurs.", {
        reason: "pricing_invalid",
        errors: validation.errors,
      });
    }
    const draft = validation.draft;
    const newPricingVersion = requestedVersion || generatedVersionId(new Date());
    const newVersionRef = db.collection("pricing_versions").doc(newPricingVersion);
    const activeRef = db.collection("pricing_configs").doc("active");

    const result = await db.runTransaction(async (tx) => {
      const [existing, activeSnap] = await Promise.all([tx.get(newVersionRef), tx.get(activeRef)]);
      if (existing.exists) {
        throw failedPrecondition(
          `pricing_versions/${newPricingVersion} existe déjà — les versions sont immuables, choisir un nouvel identifiant.`
        );
      }

      const rawActiveId = activeSnap.data()?.active_pricing_version;
      const activeId = typeof rawActiveId === "string" && rawActiveId.trim() ? rawActiveId.trim() : null;
      let active: PricingVersionDoc | null = null;
      if (activeId) {
        if ((data.basedOnPricingVersion ?? null) !== activeId) {
          throw aborted(
            "Les tarifs ont changé depuis l'ouverture de la grille. Rechargez la page avant de publier."
          );
        }
        const activeVersionSnap = await tx.get(db.collection("pricing_versions").doc(activeId));
        active = (activeVersionSnap.data() as PricingVersionDoc | undefined) ?? null;
      }

      const currentFee = missionFeePolicyFrom(active?.mission_fee_policy);
      const feeChanged =
        currentFee.total_minor !== draft.mission_fee_policy.total_minor ||
        currentFee.driver_minor !== draft.mission_fee_policy.driver_minor ||
        currentFee.platform_minor !== draft.mission_fee_policy.platform_minor;
      if (feeChanged && data.feeTextUpdated !== true) {
        throw new HttpsError(
          "failed-precondition",
          "Les frais d'annulation changent : mettez d'abord à jour le texte d'annulation des conditions de réservation.",
          { reason: "fee_text_update_required" }
        );
      }

      const now = admin.firestore.Timestamp.now();
      const version = asPricingVersion(
        draft,
        {
          // 🔒 Taxes et pourboires : jamais modifiés par la grille.
          tax_rate: typeof active?.tax_rate === "number" ? active.tax_rate : 0,
          tip_policy: active?.tip_policy ?? { driver_tip_percentage: 100 },
        },
        newPricingVersion
      );
      tx.set(newVersionRef, {
        ...version,
        effective_from: now,
        previous_pricing_version: activeId,
        published_by_user_id: ctx.uid,
        change_note: changeNote,
      });

      tx.set(
        activeRef,
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
        metadata: {
          vehicleRuleCount: draft.vehicle_rules.length,
          previousPricingVersion: activeId,
          feeChanged,
          changeNote,
        },
      });
      return { previousPricingVersion: activeId, feeChanged };
    });

    return { success: true, pricingVersion: newPricingVersion, ...result };
  }
);
