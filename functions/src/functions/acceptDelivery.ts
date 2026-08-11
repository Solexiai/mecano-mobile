// -----------------------------------------------------------------------------
// acceptDelivery — Cloud Function callable (driver). 🔒 CŒUR DE L'ATOMICITÉ.
//
// EXIGENCE EXPLICITE DU CAHIER DES CHARGES :
// « acceptDelivery doit utiliser une transaction Firestore. Elle doit
//   relire la mission dans la transaction et vérifier qu'elle est toujours
//   disponible avant de l'assigner. Le premier commit valide gagne. Aucune
//   logique frontend ne doit déterminer le gagnant. »
//
// GARANTIE D'ATOMICITÉ FIRESTORE :
// `db.runTransaction()` relit `missionRef` via `tx.get()` DANS la
// transaction. Si deux chauffeurs appellent `acceptDelivery` en même temps
// pour la même mission, Firestore détecte au commit que le document lu a
// changé entre temps pour l'un des deux appels et RÉESSAIE automatiquement
// cette transaction (jusqu'à 5 tentatives par défaut du SDK Admin). À la
// relecture suivante, `status` ne sera plus `searching_driver`/`offered`
// (l'autre transaction aura déjà gagné et committé `assigned`), et cette
// fonction lèvera alors `failed-precondition` pour le perdant. Le frontend
// ne fait qu'appeler cette fonction et afficher le résultat — il ne décide
// jamais qui gagne.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  calculateCustomerQuote,
  calculateDriverCompensation,
  resolveCommission,
} from "../lib/pricingEngine";
import {
  CommissionConfigDoc,
  DriverProfileDoc,
  DriverStatuses,
  MissionStatuses,
  OPEN_FOR_ACCEPTANCE_STATUSES,
  PricingVersionDoc,
} from "../lib/types";

export interface AcceptDeliveryRequest {
  missionId: string;
}

export const acceptDelivery = onCall<AcceptDeliveryRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const driverId = ctx.uid;
  const { missionId } = request.data;

  if (!missionId || typeof missionId !== "string") {
    throw invalidArgument("missionId est requis.");
  }

  const missionRef = db.collection("delivery_requests").doc(missionId);
  const driverRef = db.collection("driver_profiles").doc(driverId);

  const result = await db.runTransaction(async (tx) => {
    // ---- RELECTURE DANS LA TRANSACTION (garantie d'atomicité) ----
    const [missionSnap, driverSnap] = await Promise.all([tx.get(missionRef), tx.get(driverRef)]);

    if (!missionSnap.exists) {
      throw notFound(`delivery_requests/${missionId} introuvable.`);
    }
    if (!driverSnap.exists) {
      throw notFound(`driver_profiles/${driverId} introuvable.`);
    }

    const mission = missionSnap.data()!;
    const driver = driverSnap.data() as DriverProfileDoc;

    // ---- Vérifications d'éligibilité chauffeur ----
    if (driver.status !== DriverStatuses.APPROVED) {
      throw permissionDenied("Seul un chauffeur approuvé peut accepter une mission.");
    }
    if (!driver.documents_all_valid) {
      throw failedPrecondition("Documents chauffeur invalides ou expirés.");
    }
    if (!driver.accepted_vehicle_categories.includes(mission.required_vehicle_category)) {
      throw permissionDenied("Catégorie de véhicule non acceptée par ce chauffeur.");
    }

    // ---- LA vérification décisive : la mission est-elle encore ouverte ? ----
    // C'est précisément cette lecture, faite DANS la transaction, qui
    // garantit qu'un seul appel concurrent peut committer avec succès.
    if (!OPEN_FOR_ACCEPTANCE_STATUSES.includes(mission.status)) {
      throw failedPrecondition(
        `Mission déjà ${mission.status} — un autre chauffeur a probablement déjà accepté.`
      );
    }
    if (mission.driver_id) {
      throw failedPrecondition("Mission déjà assignée à un autre chauffeur.");
    }

    // ---- Recalcul financier serveur (jamais un montant client) ----
    const versionSnap = await tx.get(
      db.collection("pricing_versions").doc(mission.pricing_version)
    );
    if (!versionSnap.exists) {
      throw failedPrecondition(`pricing_versions/${mission.pricing_version} introuvable.`);
    }
    const pricingConfig = versionSnap.data() as PricingVersionDoc;

    const pricingResult = calculateCustomerQuote(pricingConfig, {
      vehicleCategory: mission.required_vehicle_category,
      distanceKm: mission.distance_km,
      estimatedDurationMinutes: mission.estimated_duration_minutes,
    });

    // Résolution de commission : Founding Driver > promo > standard.
    const foundingQualSnap = await tx.get(
      db
        .collection("founding_driver_programs")
        .doc("default")
        .collection("qualifications")
        .doc(driverId)
    );
    const promoSnap = await tx.get(
      db.collection("driver_promotions").where("driver_id", "==", driverId).limit(1)
    );

    const now = admin.firestore.Timestamp.now();
    const resolved = resolveCommission({
      nowMillis: now.toMillis(),
      foundingQualification: foundingQualSnap.exists
        ? {
            status: foundingQualSnap.data()!.status,
            promotionalPeriodEndsAtMillis: foundingQualSnap
              .data()!
              .promotional_period_ends_at.toMillis(),
          }
        : null,
      foundingProgram: null, // chargé séparément si qualification trouvée (omis ici pour concision du squelette)
      activePromotion:
        !promoSnap.empty && promoSnap.docs[0].data().is_active
          ? {
              promotionalCommissionRate: promoSnap.docs[0].data().promotional_commission_rate,
              startsAtMillis: promoSnap.docs[0].data().starts_at.toMillis(),
              endsAtMillis: promoSnap.docs[0].data().ends_at.toMillis(),
              isActive: promoSnap.docs[0].data().is_active,
            }
          : null,
      standardRate: (pricingConfig.commission as CommissionConfigDoc).standard_commission_rate,
    });

    const compensation = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolved,
      commissionConfig: pricingConfig.commission,
    });

    // ---- Écriture atomique : mission + driver_profile + snapshot pending ----
    tx.update(missionRef, {
      driver_id: driverId,
      driver_display_name: driver.full_name,
      status: MissionStatuses.ASSIGNED,
      accepted_at: now,
      driver_offer_amount: compensation.driverOfferAmount,
    });

    tx.update(driverRef, { online_status: "on_mission" });

    const snapshotRef = db.collection("financial_snapshots").doc();
    tx.set(snapshotRef, {
      snapshot_id: snapshotRef.id,
      mission_id: missionId,
      customer_id: mission.customer_id,
      driver_id: driverId,
      pricing_version: mission.pricing_version,
      mission_base_value: pricingResult.missionBaseValue,
      driver_gross_earnings: compensation.driverGrossEarnings,
      driver_offer_amount: compensation.driverOfferAmount,
      commission_rate: resolved.rate,
      commission_program: resolved.program,
      minimum_platform_commission: pricingConfig.commission.minimum_platform_commission,
      maximum_effective_commission_rate:
        pricingConfig.commission.maximum_effective_commission_rate,
      platform_commission_amount: compensation.platformCommissionAmount,
      customer_service_fee: pricingResult.customerServiceFee,
      customer_fees:
        pricingResult.handlingFeesTotal + pricingResult.waitingFee + pricingResult.additionalStopsFee,
      customer_discount: 0,
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
      status: "pending", // confirmé par completeDelivery()
    });

    tx.update(missionRef, { active_financial_snapshot_id: snapshotRef.id });

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, { event_type: "driver_assigned", occurred_at: now, metadata: { driverId } });

    writeAuditLogInTransaction(tx, {
      actorUserId: driverId,
      actorRole: "driver",
      action: "acceptDelivery",
      targetId: missionId,
      metadata: { snapshotId: snapshotRef.id },
    });

    return { missionId, driverOfferAmount: compensation.driverOfferAmount, snapshotId: snapshotRef.id };
  });

  return { success: true, ...result };
});
