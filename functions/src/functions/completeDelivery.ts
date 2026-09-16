// -----------------------------------------------------------------------------
// completeDelivery — Cloud Function callable (driver assigné uniquement).
//
// Marque la mission `completed`, confirme le `financial_snapshot`
// (status: pending -> confirmed, désormais IMMUABLE), et crée les entrées
// du `transaction_ledger` correspondantes (customer_charge, platform_commission,
// driver_earning, customer_service_fee, tax) — voir createLedgerEntry() pour
// la primitive réutilisable.
//
// PREUVE DE LIVRAISON (Phase 5, partie 3) : `proofOfDeliveryUrl` est
// OBLIGATOIRE — une mission ne peut devenir `completed` sans une preuve de
// livraison valide (photo uploadée dans Firebase Storage sous
// `delivery_proofs/{missionId}/{fileName}`, voir storage.rules). L'URL est
// à la fois :
//   1. dénormalisée sur le document mission (`proof_of_delivery_url`) pour
//      un affichage client trivial sans lecture de sous-collection ;
//   2. tracée dans `tracking_events` (event_type: "delivered",
//      metadata.proof_of_delivery_url) pour l'historique/timeline.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireSignedIn } from "../lib/auth";
import { failedPrecondition, invalidArgument, notFound, permissionDenied } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  MissionAssignmentModes,
  MissionStatuses,
} from "../lib/types";
import { captureMissionPayment } from "../payment/paymentOrchestration";
import { STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET } from "../lib/secrets";

export interface CompleteDeliveryRequest {
  missionId: string;
  proofOfDeliveryUrl: string;
}

export const completeDelivery = onCall<CompleteDeliveryRequest>(
  { secrets: [STRIPE_SECRET_KEY, STRIPE_WEBHOOK_SECRET] },
  async (request) => {
  const ctx = requireSignedIn(request);
  const { missionId, proofOfDeliveryUrl } = request.data;
  if (!missionId) throw invalidArgument("missionId est requis.");
  if (!proofOfDeliveryUrl || typeof proofOfDeliveryUrl !== "string" || !proofOfDeliveryUrl.trim()) {
    throw invalidArgument("proofOfDeliveryUrl est requis pour compléter la livraison (preuve de livraison obligatoire).");
  }

  const missionRef = db.collection("delivery_requests").doc(missionId);

  const completion = await db.runTransaction(async (tx) => {
    const missionSnap = await tx.get(missionRef);
    if (!missionSnap.exists) throw notFound(`delivery_requests/${missionId} introuvable.`);
    const mission = missionSnap.data()!;

    if (mission.driver_id !== ctx.uid) {
      throw permissionDenied("Seul le chauffeur assigné peut confirmer la livraison.");
    }
    if (mission.status !== MissionStatuses.PICKED_UP && mission.status !== MissionStatuses.IN_TRANSIT && mission.status !== MissionStatuses.ARRIVED_AT_DROPOFF) {
      throw failedPrecondition(`Transition invalide depuis le statut '${mission.status}'.`);
    }
    const isInternalTest =
      mission.assignment_mode === MissionAssignmentModes.INTERNAL_TEST;
    if (!isInternalTest && !mission.active_financial_snapshot_id) {
      throw failedPrecondition("Aucun financial_snapshot actif rattaché à cette mission.");
    }

    const snapshotRef = mission.active_financial_snapshot_id
      ? db.collection("financial_snapshots").doc(mission.active_financial_snapshot_id)
      : null;
    const snapshotSnap = snapshotRef ? await tx.get(snapshotRef) : null;
    if (!isInternalTest && !snapshotSnap?.exists) {
      throw notFound("financial_snapshot introuvable.");
    }
    const snapshot = snapshotSnap?.data();

    if (!isInternalTest && snapshot?.status === "confirmed") {
      throw failedPrecondition("Ce financial_snapshot est déjà confirmé (immuable).");
    }

    const now = admin.firestore.Timestamp.now();

    // 1. Mission -> completed (avec dénormalisation de la preuve de livraison).
    tx.update(missionRef, {
      status: MissionStatuses.COMPLETED,
      completed_at: now,
      proof_of_delivery_url: proofOfDeliveryUrl,
    });

    if (!isInternalTest) {
      if (!snapshotRef || !snapshot) {
        throw notFound("financial_snapshot introuvable.");
      }

      // 2. Snapshot -> confirmed. Dernière écriture possible sur ce document.
      tx.update(snapshotRef, { status: "confirmed", confirmed_at: now });

      // 3. Entrées comptables pour une mission réelle seulement.
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
    }

    const driverRef = db.collection("driver_profiles").doc(mission.driver_id);
    tx.update(driverRef, isInternalTest
      ? { online_status: "online" }
      : {
          completed_missions: admin.firestore.FieldValue.increment(1),
          online_status: "online",
        }
    );

    // Désactive le tracking GPS temps réel à la fin de toute mission.
    tx.set(
      db.collection("driver_locations").doc(mission.driver_id),
      { active_delivery_id: null },
      { merge: true }
    );

    const eventRef = missionRef.collection("tracking_events").doc();
    tx.set(eventRef, {
      event_type: "delivered",
      actor_uid: ctx.uid,
      occurred_at: now,
      metadata: {
        proof_of_delivery_url: proofOfDeliveryUrl,
        internal_test: isInternalTest,
      },
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: "driver",
      action: isInternalTest ? "completeDeliveryInternalTest" : "completeDelivery",
      sourceFunction: "completeDelivery",
      targetId: missionId,
      metadata: {
        snapshotId: mission.active_financial_snapshot_id ?? null,
        internalTest: isInternalTest,
      },
    });

    return {
      paymentId: isInternalTest
        ? null
        : ((mission.active_payment_id as string | null | undefined) ?? null),
      internalTest: isInternalTest,
    };
  });

  // ---- PHASE 6, point 5 : capture RÉELLE du paiement -------------------
  // Exécutée APRÈS le commit de la transaction ci-dessus (jamais dedans —
  // même raison que dans acceptDelivery : un appel Stripe ne doit jamais
  // pouvoir être ré-exécuté par un retry de contention Firestore). Si
  // `active_payment_id` est absent (mission antérieure à Phase 6, ou
  // fournisseur non configuré au moment de acceptDelivery), on ne capture
  // rien — rétro-compatibilité intentionnelle, déjà documentée dans
  // types.ts. Si la capture échoue (carte finalement invalide, litige
  // réseau), l'échec est enregistré sur `payments/{id}` (status FAILED) et
  // remonté comme anomalie de réconciliation — la mission RESTE `completed`
  // (la livraison a eu lieu ; le recouvrement du paiement est un problème
  // financier distinct traité via le tableau de bord admin, jamais en
  // ré-annulant une livraison déjà effectuée).
  let captureFailureMessage: string | null = null;
  if (completion.paymentId) {
    const captureResult = await captureMissionPayment(missionId, completion.paymentId);
    if (!captureResult.success) {
      captureFailureMessage = captureResult.failureMessage ?? "Capture refusée par le fournisseur.";
    }
  }

  return {
    success: true,
    missionId,
    paymentCaptured: completion.internalTest ? false : !captureFailureMessage,
    paymentSkipped: completion.internalTest,
    internalTest: completion.internalTest,
    captureFailureMessage,
  };
  }
);
