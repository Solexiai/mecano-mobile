// -----------------------------------------------------------------------------
// completeDelivery — Cloud Function callable (driver assigné uniquement).
//
// Marque la mission `completed`, confirme le `financial_snapshot`
// (status: pending -> confirmed, désormais IMMUABLE), et crée les entrées
// du `transaction_ledger` correspondantes (customer_charge, platform_commission,
// driver_earning, customer_service_fee, tax) — voir createLedgerEntry() pour
// la primitive réutilisable.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { LedgerDirections, LedgerEntryStatuses, LedgerEntryTypes, LedgerParties, MissionStatuses } from "../lib/types";

export interface CompleteDeliveryRequest {
  missionId: string;
  proofOfDeliveryUrl?: string;
}

export const completeDelivery = onCall<CompleteDeliveryRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  const { missionId, proofOfDeliveryUrl } = request.data;
  if (!missionId) throw invalidArgument("missionId est requis.");

  const missionRef = db.collection("delivery_requests").doc(missionId);

  await db.runTransaction(async (tx) => {
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) throw notFound(`delivery_requests/${missionId} introuvable.`);
    const mission = missionSnap.data()!;

    if (mission.driver_id !== ctx.uid) {
      throw permissionDenied("Seul le chauffeur assigné peut confirmer la livraison.");
    }
    if (mission.status !== MissionStatuses.PICKED_UP && mission.status !== MissionStatuses.IN_TRANSIT && mission.status !== MissionStatuses.ARRIVED_AT_DROPOFF) {
      throw failedPrecondition(`Transition invalide depuis le statut '${mission.status}'.`);
    }
    if (!mission.active_financial_snapshot_id) {
      throw failedPrecondition("Aucun financial_snapshot actif rattaché à cette mission.");
    }

    const snapshotRef = db.collection("financial_snapshots").doc(mission.active_financial_snapshot_id);
    const snapshotSnap = await tx.get(snapshotRef);
    if (!snapshotSnap.exists) throw notFound("financial_snapshot introuvable.");
    const snapshot = snapshotSnap.data()!;

    if (snapshot.status === "confirmed") {
      throw failedPrecondition("Ce financial_snapshot est déjà confirmé (immuable).");
    }

    const now = admin.firestore.Timestamp.now();

    // 1. Mission -> completed.
    tx.update(missionRef, { status: MissionStatuses.COMPLETED, completed_at: now });

    // 2. Snapshot -> confirmed. 🔒 Dernière écriture possible sur ce document.
    tx.update(snapshotRef, { status: "confirmed", confirmed_at: now });

    // 3. driver_profiles.completed_missions += 1.
    const driverRef = db.collection("driver_profiles").doc(mission.driver_id);
    tx.update(driverRef, {
      completed_missions: admin.firestore.FieldValue.increment(1),
      online_status: "online",
    });

    // Désactive le tracking GPS temps réel (Phase 5) : la mission est
    // terminée, plus aucun client ne doit pouvoir suivre ce chauffeur via
    // cette mission, et recordTrackingPoint() cesse d'écrire l'historique.
    tx.set(
      db.collection("driver_locations").doc(mission.driver_id),
      { active_delivery_id: null },
      { merge: true }
    );

    // 4. Entrées du ledger — append-only, créées ici DANS la même transaction
    // que la confirmation du snapshot pour garantir la cohérence comptable.
    const ledgerEntries: Array<Record<string, unknown>> = [
      {
        type: LedgerEntryTypes.CUSTOMER_CHARGE,
        amount: snapshot.customer_total,
        direction: LedgerDirections.DEBIT,
        party: LedgerParties.CUSTOMER,
      },
      {
        type: LedgerEntryTypes.PLATFORM_COMMISSION,
        amount: snapshot.platform_commission_amount,
        direction: LedgerDirections.CREDIT,
        party: LedgerParties.PLATFORM,
      },
      {
        type: LedgerEntryTypes.CUSTOMER_SERVICE_FEE,
        amount: snapshot.customer_service_fee,
        direction: LedgerDirections.CREDIT,
        party: LedgerParties.PLATFORM,
      },
      {
        type: LedgerEntryTypes.DRIVER_EARNING,
        amount: snapshot.driver_offer_amount,
        direction: LedgerDirections.CREDIT,
        party: LedgerParties.DRIVER,
      },
      {
        type: LedgerEntryTypes.TAX,
        amount: snapshot.customer_tax,
        direction: LedgerDirections.CREDIT,
        party: LedgerParties.PLATFORM,
      },
    ];

    for (const entry of ledgerEntries) {
      const entryRef = db.collection("transaction_ledger").doc();
      tx.set(entryRef, {
        ledger_entry_id: entryRef.id,
        mission_id: missionId,
        transaction_id: null,
        currency: "CAD",
        created_at: now,
        created_by: "completeDelivery",
        source_event: "delivery_completed",
        status: LedgerEntryStatuses.CONFIRMED,
        reference_id: null,
        ...entry,
      });
    }

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "delivered",
      occurred_at: now,
      metadata: proofOfDeliveryUrl ? { proof_of_delivery_url: proofOfDeliveryUrl } : {},
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: "driver",
      action: "completeDelivery",
      sourceFunction: "completeDelivery",
      targetId: missionId,
      metadata: { snapshotId: mission.active_financial_snapshot_id },
    });
  });

  return { success: true, missionId };
});
