// -----------------------------------------------------------------------------
// disputeOrchestration.ts — Cycle de vie complet des litiges/chargebacks
// (Phase 6, directive 38 points, points 8 et 9).
//
// Contrairement aux opérations de paiement (createAndAuthorizeMissionPayment,
// capturePayment, refundPayment, submitDriverPayout), l'ouverture et la
// résolution d'un litige NE DÉCLENCHENT JAMAIS d'appel sortant vers le
// PaymentProvider — l'évènement provider (webhook Stripe) a DÉJÀ eu lieu
// AVANT que ce code ne s'exécute ; il ne fait qu'ENREGISTRER ce fait de
// façon idempotente et appliquer les effets ledger/paiement qui en
// découlent. Une SEULE transaction Firestore suffit donc (pas de schéma en
// 3 temps ici).
//
// openDispute()            -> chargeback_created (+ chargeback_fee ledger)
// transitionDisputeStatus() -> under_review / won / lost / reversed / closed
//   - WON      : chargeback_won (crédit informatif, fonds définitivement
//                conservés), paiement repasse CAPTURED.
//   - LOST     : chargeback_lost (débit réel), paiement -> CHARGEBACK.
//   - REVERSED : chargeback_reversal (crédit, fonds récupérés après un LOST
//                antérieur), paiement CHARGEBACK -> REFUNDED (late-win,
//                déjà documenté dans paymentStateMachine.ts).
//   - CLOSED   : clôture administrative pure, AUCUN nouvel effet ledger
//                (déjà appliqués au moment de won/lost/reversed).
//
// Idempotence : l'ID du document `disputes/{id}` EST le
// `provider_dispute_id` fourni par Stripe — un doublon de webhook
// "dispute.created" ne crée jamais deux DisputeDoc. Un doublon de
// "dispute.updated"/"dispute.closed" vers le MÊME statut est toléré comme
// self-transition sans effet dupliqué (voir transitionDisputeStatus ci-
// dessous, comparaison dispute.status === newStatus AVANT d'appliquer quoi
// que ce soit).
// -----------------------------------------------------------------------------

import { admin, db } from "../lib/admin";
import { assertValidDisputeTransition, isTerminalDisputeStatus } from "../lib/disputeStateMachine";
import { assertValidPaymentTransition } from "../lib/paymentStateMachine";
import { notFound } from "../lib/errors";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { writeAuditLogInTransaction } from "../lib/audit";
import {
  DisputeDoc,
  DisputeStatus,
  DisputeStatuses,
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  PaymentDoc,
  PaymentStatus,
  PaymentStatuses,
} from "../lib/types";

// 🔒 Frais FIXE de litige facturé par Stripe (≈ 15 $ CAD au moment de la
// rédaction) — un frais provider documenté, PAS une règle fiscale (voir
// taxEngine.ts / Bloc E, seul concerné par l'interdiction de hardcoder une
// règle fiscale). Utilisé uniquement en repli si l'évènement webhook ne
// transmet pas le frais réel observé côté provider (voir processStripeWebhook.ts).
export const DEFAULT_STRIPE_DISPUTE_FEE_MINOR = 1500;

export interface OpenDisputeInput {
  /** ID du litige côté provider (Stripe) — devient l'ID du document `disputes/{id}`. */
  providerDisputeId: string;
  paymentId: string;
  amountMinor: number;
  reason: string;
  evidenceDueAt?: Date | null;
  providerMetadata?: Record<string, unknown> | null;
  providerFeeMinor?: number | null;
}

export interface OpenDisputeOutcome {
  disputeId: string;
  alreadyExisted: boolean;
}

export async function openDispute(input: OpenDisputeInput): Promise<OpenDisputeOutcome> {
  const disputeRef = db.collection("disputes").doc(input.providerDisputeId);
  const payRef = db.collection("payments").doc(input.paymentId);

  type TxResult = { disputeId: string; alreadyExisted: boolean; missionId: string | null };

  const result: TxResult = await db.runTransaction(async (tx): Promise<TxResult> => {
    const [disputeSnap, paySnap] = await Promise.all([tx.get(disputeRef), tx.get(payRef)]);
    if (disputeSnap.exists) {
      // Doublon de webhook "dispute.created" pour le MÊME litige provider —
      // ne recrée rien, ne journalise pas un second frais.
      return { disputeId: disputeRef.id, alreadyExisted: true, missionId: null };
    }
    if (!paySnap.exists) throw notFound(`payments/${input.paymentId} introuvable.`);
    const payment = paySnap.data() as PaymentDoc;

    const now = admin.firestore.Timestamp.now();
    const disputeDoc: DisputeDoc = {
      dispute_id: disputeRef.id,
      mission_id: payment.mission_id,
      payment_id: input.paymentId,
      provider_dispute_id: input.providerDisputeId,
      amount_minor: input.amountMinor,
      currency: payment.currency,
      reason: input.reason,
      status: DisputeStatuses.OPENED,
      evidence_due_at: input.evidenceDueAt ? admin.firestore.Timestamp.fromDate(input.evidenceDueAt) : null,
      proof_of_delivery_url: null,
      provider_metadata: input.providerMetadata ?? null,
      created_at: now,
      updated_at: now,
      resolved_at: null,
      closed_at: null,
    };
    tx.set(disputeRef, disputeDoc);

    // Transition paiement -> DISPUTED. Idempotence : si déjà DISPUTED
    // (webhook "created" rejoué après qu'une AUTRE couche ait déjà marqué
    // le paiement disputé — ne devrait pas arriver puisque ce même bloc
    // est le seul point d'entrée, mais défensif), on ne retransite pas.
    if (payment.status !== PaymentStatuses.DISPUTED) {
      assertValidPaymentTransition(payment.status, PaymentStatuses.DISPUTED);
      tx.update(payRef, { status: PaymentStatuses.DISPUTED, updated_at: now });
    }

    const feeMinor = input.providerFeeMinor ?? DEFAULT_STRIPE_DISPUTE_FEE_MINOR;
    const ledgerRef = db.collection("transaction_ledger").doc();
    tx.set(ledgerRef, {
      ledger_entry_id: ledgerRef.id,
      mission_id: payment.mission_id,
      transaction_id: input.paymentId,
      type: LedgerEntryTypes.CHARGEBACK_FEE,
      amount: feeMinor / 100,
      amount_minor: feeMinor,
      currency: payment.currency,
      direction: LedgerDirections.DEBIT,
      party: LedgerParties.PLATFORM,
      created_at: now,
      created_by: "openDispute",
      source_event: "chargeback_created",
      status: LedgerEntryStatuses.CONFIRMED,
      reference_id: disputeRef.id,
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: "system",
      actorRole: "system",
      action: "dispute_opened",
      sourceFunction: "openDispute",
      targetId: disputeRef.id,
      metadata: { paymentId: input.paymentId, amountMinor: input.amountMinor, reason: input.reason },
    });

    return { disputeId: disputeRef.id, alreadyExisted: false, missionId: payment.mission_id };
  });

  if (!result.alreadyExisted && result.missionId) {
    await recalculateMissionFinancialBalance(result.missionId);
  }
  return { disputeId: result.disputeId, alreadyExisted: result.alreadyExisted };
}

export interface TransitionDisputeStatusInput {
  disputeId: string;
  newStatus: DisputeStatus;
}

export interface TransitionDisputeStatusOutcome {
  disputeId: string;
  status: DisputeStatus;
  skipped: boolean; // true si self-transition idempotente (aucun effet appliqué)
}

export async function transitionDisputeStatus(
  input: TransitionDisputeStatusInput
): Promise<TransitionDisputeStatusOutcome> {
  const disputeRef = db.collection("disputes").doc(input.disputeId);

  type TxResult = { status: DisputeStatus; missionId: string; skipped: boolean };

  const result: TxResult = await db.runTransaction(async (tx): Promise<TxResult> => {
    const disputeSnap = await tx.get(disputeRef);
    if (!disputeSnap.exists) throw notFound(`disputes/${input.disputeId} introuvable.`);
    const dispute = disputeSnap.data() as DisputeDoc;

    if (dispute.status === input.newStatus) {
      // Doublon d'évènement webhook (ou double-clic admin) vers le MÊME
      // statut — toléré, aucun effet ledger/paiement dupliqué.
      return { status: dispute.status, missionId: dispute.mission_id, skipped: true };
    }

    assertValidDisputeTransition(dispute.status, input.newStatus);

    const payRef = db.collection("payments").doc(dispute.payment_id);
    const paySnap = await tx.get(payRef);
    if (!paySnap.exists) throw notFound(`payments/${dispute.payment_id} introuvable.`);
    const payment = paySnap.data() as PaymentDoc;

    const now = admin.firestore.Timestamp.now();
    const disputeUpdates: Record<string, unknown> = { status: input.newStatus, updated_at: now };
    if (isTerminalDisputeStatus(input.newStatus)) disputeUpdates.closed_at = now;
    if (
      input.newStatus === DisputeStatuses.WON ||
      input.newStatus === DisputeStatuses.LOST ||
      input.newStatus === DisputeStatuses.REVERSED
    ) {
      disputeUpdates.resolved_at = now;
    }
    tx.update(disputeRef, disputeUpdates);

    let ledgerType: string | null = null;
    let paymentNextStatus: PaymentStatus | null = null;
    let ledgerDirection: string = LedgerDirections.CREDIT;

    if (input.newStatus === DisputeStatuses.WON) {
      // Fonds définitivement conservés par Movi-K — entrée informative,
      // aucun mouvement d'argent réel (le paiement était déjà capturé).
      ledgerType = LedgerEntryTypes.CHARGEBACK_WON;
      paymentNextStatus = PaymentStatuses.CAPTURED;
      ledgerDirection = LedgerDirections.CREDIT;
    } else if (input.newStatus === DisputeStatuses.LOST) {
      // Perte réelle : la banque du client a définitivement récupéré les
      // fonds — débit réel côté plateforme.
      ledgerType = LedgerEntryTypes.CHARGEBACK_LOST;
      paymentNextStatus = PaymentStatuses.CHARGEBACK;
      ledgerDirection = LedgerDirections.DEBIT;
    } else if (input.newStatus === DisputeStatuses.REVERSED) {
      // Résolution comptable tardive après un LOST déjà appliqué (late-win)
      // — voir paymentStateMachine.ts, CHARGEBACK -> REFUNDED documenté.
      ledgerType = LedgerEntryTypes.CHARGEBACK_REVERSAL;
      paymentNextStatus = PaymentStatuses.REFUNDED;
      ledgerDirection = LedgerDirections.CREDIT;
    }

    if (paymentNextStatus && payment.status !== paymentNextStatus) {
      assertValidPaymentTransition(payment.status, paymentNextStatus);
      tx.update(payRef, { status: paymentNextStatus, updated_at: now });
    }

    if (ledgerType) {
      const ledgerRef = db.collection("transaction_ledger").doc();
      tx.set(ledgerRef, {
        ledger_entry_id: ledgerRef.id,
        mission_id: dispute.mission_id,
        transaction_id: dispute.payment_id,
        type: ledgerType,
        amount: dispute.amount_minor / 100,
        amount_minor: dispute.amount_minor,
        currency: dispute.currency,
        direction: ledgerDirection,
        party: LedgerParties.PLATFORM,
        created_at: now,
        created_by: "transitionDisputeStatus",
        source_event: `chargeback_${input.newStatus}`,
        status: LedgerEntryStatuses.CONFIRMED,
        reference_id: disputeRef.id,
      });
    }

    writeAuditLogInTransaction(tx, {
      actorUserId: "system",
      actorRole: "system",
      action: isTerminalDisputeStatus(input.newStatus) ? "dispute_closed" : "dispute_updated",
      sourceFunction: "transitionDisputeStatus",
      targetId: disputeRef.id,
      metadata: { newStatus: input.newStatus, paymentId: dispute.payment_id },
    });

    return { status: input.newStatus, missionId: dispute.mission_id, skipped: false };
  });

  if (!result.skipped) {
    await recalculateMissionFinancialBalance(result.missionId);
  }
  return { disputeId: disputeRef.id, status: result.status, skipped: result.skipped };
}
