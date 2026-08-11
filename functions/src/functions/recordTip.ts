// -----------------------------------------------------------------------------
// recordTip — Cloud Function callable (customer, mission complétée).
//
// Politique : 100% du pourboire va au chauffeur (TipPolicyConfig.driverTipPercentage,
// voir lib/finance/models/pricing_config.dart). Toute dérogation à ce
// pourcentage nécessite super_admin (canModifyProtectedFinancialPolicy) et
// n'est PAS gérée par cette fonction cliente. Le snapshot étant déjà
// `confirmed` (immuable), le pourboire est ajouté via une ENTRÉE LEDGER
// séparée — jamais une réécriture du snapshot.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { LedgerDirections, LedgerEntryStatuses, LedgerEntryTypes, LedgerParties, MissionStatuses, PricingVersionDoc } from "../lib/types";

export interface RecordTipRequest {
  missionId: string;
  tipAmount: number;
}

export const recordTip = onCall<RecordTipRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const { missionId, tipAmount } = request.data;

  if (!missionId) throw invalidArgument("missionId est requis.");
  if (typeof tipAmount !== "number" || tipAmount <= 0) {
    throw invalidArgument("tipAmount doit être un nombre strictement positif.");
  }

  const missionRef = db.collection("delivery_requests").doc(missionId);

  await db.runTransaction(async (tx) => {
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) throw notFound(`delivery_requests/${missionId} introuvable.`);
    const mission = missionSnap.data()!;

    if (mission.customer_id !== ctx.uid) {
      throw permissionDenied("Seul le client de cette mission peut ajouter un pourboire.");
    }
    if (mission.status !== MissionStatuses.COMPLETED) {
      throw failedPrecondition("Le pourboire ne peut être ajouté qu'après complétion de la mission.");
    }

    // Résout le pourcentage chauffeur depuis la pricing_version figée sur la
    // mission (jamais la config active courante, qui peut avoir changé).
    const versionSnap = await tx.get(db.collection("pricing_versions").doc(mission.pricing_version));
    const tipPolicy = versionSnap.exists
      ? (versionSnap.data() as PricingVersionDoc).tip_policy
      : { driver_tip_percentage: 100 };
    const driverShare = tipAmount * (tipPolicy.driver_tip_percentage / 100);

    const now = admin.firestore.Timestamp.now();

    const tipEntryRef = db.collection("transaction_ledger").doc();
    tx.set(tipEntryRef, {
      ledger_entry_id: tipEntryRef.id,
      mission_id: missionId,
      transaction_id: null,
      type: LedgerEntryTypes.DRIVER_TIP,
      amount: driverShare,
      currency: "CAD",
      direction: LedgerDirections.CREDIT,
      party: LedgerParties.DRIVER,
      created_at: now,
      created_by: "recordTip",
      source_event: "tip_added",
      status: LedgerEntryStatuses.CONFIRMED,
      reference_id: null,
    });

    if (mission.active_financial_snapshot_id) {
      // Le snapshot reste IMMUABLE (aucun champ modifié) — on incrémente
      // uniquement un compteur d'affichage dénormalisé optionnel côté
      // mission, jamais le snapshot lui-même.
      tx.update(missionRef, {
        // champ purement informatif pour affichage rapide, la source de
        // vérité du montant reste transaction_ledger.
        // eslint-disable-next-line @typescript-eslint/naming-convention
        last_tip_amount: driverShare,
      });
    }

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: "customer",
      action: "recordTip",
      targetId: missionId,
      metadata: { tipAmount, driverShare },
    });
  });

  return { success: true, missionId, tipAmount };
});
