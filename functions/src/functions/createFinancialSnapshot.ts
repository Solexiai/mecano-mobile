// -----------------------------------------------------------------------------
// createFinancialSnapshot — primitive interne + callable admin (ajustement
// manuel exceptionnel, ex: création rétroactive suite à un litige résolu).
//
// 🔒 IMMUABILITÉ : cette fonction ne modifie JAMAIS un snapshot existant.
// - Si aucun snapshot n'existe pour la mission : en crée un nouveau
//   (status='pending', à confirmer ensuite par completeDelivery()).
// - Si un snapshot `confirmed` existe déjà : REFUS explicite (failed-precondition).
//   Le chemin normal de création est `acceptDelivery()` (voir ce fichier) ;
//   cette fonction callable n'est utile que pour des cas d'admin exceptionnels
//   (ex: mission créée hors flux normal) et exige `admin`/`super_admin`.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  calculateCustomerQuote,
  calculateDriverCompensation,
  resolveCommission,
} from "../lib/pricingEngine";
import { PricingVersionDoc } from "../lib/types";

export interface CreateFinancialSnapshotRequest {
  missionId: string;
  reason: string;
}

/**
 * Primitive réutilisable (appelée en interne par acceptDelivery via une
 * logique équivalente inline, ou ici pour un flux admin exceptionnel).
 * Effectue elle-même sa transaction ; NE PAS appeler depuis une transaction
 * déjà ouverte (Firestore n'autorise pas les transactions imbriquées) —
 * pour un usage transactionnel (ex: acceptDelivery), dupliquer la logique de
 * calcul inline comme déjà fait dans acceptDelivery.ts.
 */
export const createFinancialSnapshot = onCall<CreateFinancialSnapshotRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const { missionId, reason } = request.data;
  if (!missionId) throw invalidArgument("missionId est requis.");
  if (!reason) throw invalidArgument("reason est requis (justification admin).");

  const missionRef = db.collection("delivery_requests").doc(missionId);

  const snapshotId = await db.runTransaction(async (tx) => {
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) throw notFound(`delivery_requests/${missionId} introuvable.`);
    const mission = missionSnap.data()!;

    if (mission.active_financial_snapshot_id) {
      const existingSnap = await tx.get(
        db.collection("financial_snapshots").doc(mission.active_financial_snapshot_id)
      );
      if (existingSnap.exists && existingSnap.data()!.status === "confirmed") {
        throw failedPrecondition(
          "Un financial_snapshot confirmé existe déjà pour cette mission — immuable, non remplaçable."
        );
      }
    }

    const versionSnap = await tx.get(db.collection("pricing_versions").doc(mission.pricing_version));
    if (!versionSnap.exists) throw failedPrecondition("pricing_version introuvable.");
    const pricingConfig = versionSnap.data() as PricingVersionDoc;

    const pricingResult = calculateCustomerQuote(pricingConfig, {
      vehicleCategory: mission.required_vehicle_category,
      distanceKm: mission.distance_km,
      estimatedDurationMinutes: mission.estimated_duration_minutes,
      customerDiscountAmount: mission.customer_discount_amount ?? 0,
    });

    const resolved = resolveCommission({
      nowMillis: Date.now(),
      standardRate: pricingConfig.commission.standard_commission_rate,
    });

    const compensation = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolved,
      commissionConfig: pricingConfig.commission,
    });

    const now = admin.firestore.Timestamp.now();
    const snapshotRef = db.collection("financial_snapshots").doc();
    tx.set(snapshotRef, {
      snapshot_id: snapshotRef.id,
      mission_id: missionId,
      customer_id: mission.customer_id,
      driver_id: mission.driver_id,
      pricing_version: mission.pricing_version,
      mission_base_value: pricingResult.missionBaseValue,
      driver_gross_earnings: compensation.driverGrossEarnings,
      driver_offer_amount: compensation.driverOfferAmount,
      commission_rate: resolved.rate,
      commission_program: resolved.program,
      minimum_platform_commission: pricingConfig.commission.minimum_platform_commission,
      maximum_effective_commission_rate: pricingConfig.commission.maximum_effective_commission_rate,
      platform_commission_amount: compensation.platformCommissionAmount,
      customer_service_fee: pricingResult.customerServiceFee,
      customer_fees: pricingResult.handlingFeesTotal + pricingResult.waitingFee + pricingResult.additionalStopsFee,
      customer_discount: pricingResult.customerDiscountAmount,
      customer_tax: pricingResult.taxAmount,
      driver_bonus: 0,
      tip_amount: 0,
      driver_net_mission_earnings: compensation.driverNetMissionEarnings,
      driver_total_payout: compensation.driverNetMissionEarnings,
      payment_processing_cost: 0,
      insurance_cost: 0,
      customer_total: pricingResult.customerTotal,
      platform_gross_revenue: compensation.platformCommissionAmount + pricingResult.customerServiceFee,
      contribution_margin: compensation.platformCommissionAmount + pricingResult.customerServiceFee,
      created_at: now,
      confirmed_at: null,
      status: "pending",
    });

    tx.update(missionRef, { active_financial_snapshot_id: snapshotRef.id });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "createFinancialSnapshot",
      targetId: missionId,
      metadata: { reason, snapshotId: snapshotRef.id },
    });

    return snapshotRef.id;
  });

  return { success: true, snapshotId };
});
