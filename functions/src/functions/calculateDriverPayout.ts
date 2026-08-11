// -----------------------------------------------------------------------------
// calculateDriverPayout — Cloud Function callable (admin/super_admin, ou
// déclenchée par un job planifié de versement — squelette callable ici).
//
// Agrège tous les `financial_snapshots` `confirmed` d'un chauffeur non
// encore inclus dans un `driver_payouts`, crée un lot de versement, et une
// entrée `transaction_ledger` de type driver_payout (débit chauffeur côté
// interne — le chauffeur a déjà été crédité via driver_earning ; ce
// paiement représente le versement RÉEL vers son compte bancaire externe,
// via le PaymentProvider — voir lib/backend/payment/payment_provider.dart).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAdminOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { LedgerDirections, LedgerEntryStatuses, LedgerEntryTypes, LedgerParties } from "../lib/types";

export interface CalculateDriverPayoutRequest {
  driverId: string;
}

export const calculateDriverPayout = onCall<CalculateDriverPayoutRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAdminOrAbove(ctx);

  const { driverId } = request.data;
  if (!driverId) throw invalidArgument("driverId est requis.");

  // 1. Trouver les snapshots confirmés non encore payés (hors transaction —
  // lecture d'un lot potentiellement large, la transaction ne porte que sur
  // l'écriture finale pour rester dans les limites Firestore).
  const snapshotsQuery = await db
    .collection("financial_snapshots")
    .where("driver_id", "==", driverId)
    .where("status", "==", "confirmed")
    .get();

  const eligibleSnapshots = snapshotsQuery.docs.filter((d) => !d.data().included_in_payout_id);

  if (eligibleSnapshots.length === 0) {
    return { success: true, payoutId: null, amount: 0, message: "Aucun snapshot éligible." };
  }

  const totalAmount = eligibleSnapshots.reduce(
    (sum, d) => sum + (d.data().driver_net_mission_earnings as number),
    0
  );

  const payoutId = await db.runTransaction(async (tx) => {
    const now = admin.firestore.Timestamp.now();
    const payoutRef = db.collection("driver_payouts").doc();

    tx.set(payoutRef, {
      driver_id: driverId,
      financial_snapshot_ids: eligibleSnapshots.map((d) => d.id),
      amount: totalAmount,
      currency: "CAD",
      status: "pending", // passe à 'processing'/'paid' via le webhook du PaymentProvider
      provider_payout_id: null,
      created_at: now,
      paid_at: null,
    });

    for (const snap of eligibleSnapshots) {
      tx.update(snap.ref, { included_in_payout_id: payoutRef.id });
    }

    const ledgerRef = db.collection("transaction_ledger").doc();
    tx.set(ledgerRef, {
      ledger_entry_id: ledgerRef.id,
      mission_id: null,
      transaction_id: payoutRef.id,
      type: LedgerEntryTypes.DRIVER_PAYOUT,
      amount: totalAmount,
      currency: "CAD",
      direction: LedgerDirections.DEBIT,
      party: LedgerParties.DRIVER,
      created_at: now,
      created_by: "calculateDriverPayout",
      source_event: "payout_batch_created",
      status: LedgerEntryStatuses.CONFIRMED,
      reference_id: null,
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "calculateDriverPayout",
      targetId: driverId,
      metadata: { payoutId: payoutRef.id, amount: totalAmount, snapshotCount: eligibleSnapshots.length },
    });

    return payoutRef.id;
  });

  // 2. TODO (hors scope étape 11) : appeler PaymentProvider.initiatePayout()
  // ici pour déclencher le virement réel, puis mettre à jour
  // driver_payouts/{payoutId}.status via un webhook dédié (Cloud Function
  // HTTP séparée, pas cette fonction callable).

  return { success: true, payoutId, amount: totalAmount };
});
