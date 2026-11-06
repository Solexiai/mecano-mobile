// -----------------------------------------------------------------------------
// bookingDeposit.ts — dépôt de réservation (décision Daniel, 2026-11-06).
//
// Règles :
//   - 25 $ débités dès que le client réserve (vrai paiement, pas un blocage),
//     pour toutes les réservations, AVANT la création de la mission : une
//     mission n'existe que si le dépôt est passé. Déduit du prix total : le
//     solde est débité à la livraison (le blocage de carte posé à
//     l'acceptation couvre le solde, voir acceptDelivery).
//   - Remboursé automatiquement : aucun chauffeur n'accepte, le chauffeur ou
//     Movi-K annule, le client annule plus de 48 h avant le ramassage, ou
//     aucun chauffeur n'avait encore accepté.
//   - Gardé : le client annule à moins de 48 h alors qu'un chauffeur avait
//     accepté. Le dépôt gardé remplace les frais d'annulation tardive pris
//     sur le blocage (lib/missionFees.ts) ; le frais « déplacement inutile »
//     reste inchangé.
//   - Ne touche ni aux tarifs, ni à la commission, ni aux taxes : le dépôt est
//     une partie du total taxes comprises.
//
// Même schéma en 3 temps que les autres opérations de paiement :
//   1. transaction : document `payments/deposit_<devis>` en capture_pending ;
//   2. appel Stripe HORS transaction, clé d'idempotence stable par devis et
//      par tentative (un nouvel essai après un refus crée un nouveau débit,
//      un nouvel essai après une coupure réseau reprend le même) ;
//   3. transaction : résultat appliqué (captured / failed).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { writeAuditLogInTransaction } from "./audit";
import { failedPrecondition } from "./errors";
import { buildIdempotencyKey } from "./idempotency";
import { DRIVER_COMMITTED_STATUSES, missionPickupAtMs } from "./missionFees";
import { DEFAULT_CURRENCY, toMajorUnits } from "./money";
import {
  BookingDepositDoc,
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  PaymentDoc,
  PaymentStatuses,
  RefundReasons,
} from "./types";
import { getPaymentProvider } from "../payment/paymentProviderFactory";
import { refundPayment } from "../payment/paymentOrchestration";

export const BOOKING_DEPOSIT_POLICY = Object.freeze({
  version: "MOVIK-DEPOSIT-20261106-001",
  amount_minor: 2500,
  /** Annulation par le client : remboursé si le ramassage est à plus de 48 h. */
  refund_window_ms: 48 * 60 * 60 * 1000,
});

/** Un dépôt par devis : l'identifiant du paiement en découle. */
export function depositPaymentId(quoteId: string, sequence = 1): string {
  return sequence <= 1 ? `deposit_${quoteId}` : `deposit_${quoteId}_${sequence}`;
}

/** Un dépôt déjà remboursé ou annulé ne se réutilise jamais : le suivant prend un nouvel identifiant. */
const TERMINAL_DEPOSIT_STATUSES: ReadonlySet<string> = new Set([
  PaymentStatuses.REFUNDED, PaymentStatuses.PARTIALLY_REFUNDED, PaymentStatuses.CANCELLED,
  PaymentStatuses.FAILED, PaymentStatuses.DISPUTED, PaymentStatuses.CHARGEBACK,
]);
const MAX_DEPOSIT_SEQUENCE = 5;

export interface CollectDepositInput {
  customerId: string;
  quoteId: string;
  /** payment_profiles/{uid} déjà vérifié (environnement actif, carte enregistrée). */
  providerCustomerId: string;
  providerPaymentMethodId: string;
}

export interface CollectDepositOutcome {
  success: boolean;
  paymentId: string;
  status: string;
  amountMinor: number;
  failureMessage?: string | null;
  /** Dépôt déjà encaissé lors d'un appel précédent (nouvel essai de réservation). */
  reused: boolean;
}

/**
 * Débite le dépôt pour un devis. Idempotent par devis : un deuxième appel
 * avec un dépôt déjà encaissé le renvoie sans nouveau débit.
 */
export async function collectBookingDeposit(input: CollectDepositInput): Promise<CollectDepositOutcome> {
  const provider = getPaymentProvider();
  const amountMinor = BOOKING_DEPOSIT_POLICY.amount_minor;
  let paymentId = depositPaymentId(input.quoteId);

  // ---- 1. Réservation de la tentative ---------------------------------------
  const prepared = await db.runTransaction(async (tx) => {
    let existing: PaymentDoc | undefined;
    let sequence = 1;
    for (; sequence <= MAX_DEPOSIT_SEQUENCE; sequence += 1) {
      paymentId = depositPaymentId(input.quoteId, sequence);
      existing = (await tx.get(db.collection("payments").doc(paymentId))).data() as PaymentDoc | undefined;
      if (!existing || !TERMINAL_DEPOSIT_STATUSES.has(existing.status)) break;
    }
    if (sequence > MAX_DEPOSIT_SEQUENCE) throw failedPrecondition("Ce devis n'est plus utilisable. Recalculez le devis pour réserver.");
    const payRef = db.collection("payments").doc(paymentId);
    const now = admin.firestore.Timestamp.now();
    if (existing) {
      if (existing.customer_id !== input.customerId) throw failedPrecondition("Dépôt d'un autre client.");
      if (existing.status === PaymentStatuses.CAPTURED) {
        return { kind: "done" as const, status: existing.status, amount: existing.amount_captured_minor };
      }
      if (existing.status === PaymentStatuses.CAPTURE_PENDING) {
        // Coupure réseau lors d'un essai précédent : on reprend la même clé.
        return { kind: "charge" as const, attempt: existing.capture_attempt_count ?? 1 };
      }
      if (existing.status !== PaymentStatuses.CAPTURE_FAILED) {
        throw failedPrecondition("Le dépôt de cette réservation est dans un état inattendu. Recalculez le devis.");
      }
      // Refus précédent (capture_failed) : nouvelle tentative, nouvelle clé.
      const attempt = (existing.capture_attempt_count ?? 1) + 1;
      tx.update(payRef, {
        status: PaymentStatuses.CAPTURE_PENDING,
        capture_attempt_count: attempt,
        provider_payment_method_id: input.providerPaymentMethodId,
        updated_at: now,
      });
      return { kind: "charge" as const, attempt };
    }
    const doc: PaymentDoc = {
      payment_id: paymentId,
      mission_id: "", // renseigné par createDeliveryRequest dès que la mission existe
      quote_id: input.quoteId,
      customer_id: input.customerId,
      driver_id: "",
      status: PaymentStatuses.CAPTURE_PENDING,
      currency: DEFAULT_CURRENCY,
      amount_authorized_minor: 0,
      amount_requested_minor: amountMinor,
      service_amount_minor: amountMinor,
      amount_captured_minor: 0,
      amount_refunded_minor: 0,
      application_fee_minor: 0,
      purpose: "deposit",
      provider: "stripe",
      provider_customer_id: input.providerCustomerId,
      provider_payment_method_id: input.providerPaymentMethodId,
      provider_payment_intent_id: null,
      provider_charge_id: null,
      connected_account_id: null,
      idempotency_key: buildIdempotencyKey("bookingDeposit", paymentId),
      capture_attempt_count: 1,
      created_at: now,
      updated_at: now,
      stripe_environment: provider.environment,
    };
    tx.set(payRef, doc);
    return { kind: "charge" as const, attempt: 1 };
  });
  if (prepared.kind === "done") {
    return { success: true, paymentId, status: prepared.status, amountMinor: prepared.amount, reused: true };
  }

  // ---- 2. Débit, hors transaction ------------------------------------------
  const payRef = db.collection("payments").doc(paymentId);
  const idempotencyKey = buildIdempotencyKey("bookingDeposit", paymentId, String(prepared.attempt));
  const result = await provider.chargeSavedPaymentMethod({
    providerCustomerId: input.providerCustomerId,
    providerPaymentMethodId: input.providerPaymentMethodId,
    amountMinor,
    currency: DEFAULT_CURRENCY,
    connectedAccountId: null,
    applicationFeeMinor: 0,
    idempotencyKey,
    metadata: {
      movik_purpose: "booking_deposit",
      movik_quote_id: input.quoteId,
      movik_customer_id: input.customerId,
      movik_deposit_policy: BOOKING_DEPOSIT_POLICY.version,
    },
  });

  // ---- 3. Résultat -------------------------------------------------------------
  if (result.indeterminate) {
    // Réponse Stripe inconnue : le document reste en capture_pending et le
    // prochain essai reprend la même clé d'idempotence.
    throw failedPrecondition("Le dépôt n'a pas pu être confirmé. Réessayez dans un instant.");
  }
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(payRef);
    const current = snap.data() as PaymentDoc | undefined;
    if (!current || current.status !== PaymentStatuses.CAPTURE_PENDING) return;
    const now = admin.firestore.Timestamp.now();
    if (result.success) {
      tx.update(payRef, {
        status: PaymentStatuses.CAPTURED,
        amount_captured_minor: result.amountCapturedMinor,
        provider_payment_intent_id: result.providerPaymentIntentId,
        provider_charge_id: result.providerChargeId,
        captured_at: now,
        updated_at: now,
        failure_code: null,
        failure_message: null,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: input.customerId, actorRole: "customer", action: "booking_deposit_captured",
        sourceFunction: "collectBookingDeposit", targetId: paymentId,
        metadata: { quoteId: input.quoteId, amountMinor: result.amountCapturedMinor, attempt: prepared.attempt },
      });
    } else {
      tx.update(payRef, {
        status: PaymentStatuses.CAPTURE_FAILED,
        provider_payment_intent_id: result.providerPaymentIntentId,
        failed_at: now,
        failure_code: result.failureCode ?? null,
        failure_message: result.failureMessage ?? null,
        updated_at: now,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: input.customerId, actorRole: "customer", action: "booking_deposit_refused",
        sourceFunction: "collectBookingDeposit", targetId: paymentId,
        metadata: { quoteId: input.quoteId, failureCode: result.failureCode ?? null, attempt: prepared.attempt },
      });
    }
  });
  return {
    success: result.success,
    paymentId,
    status: result.success ? PaymentStatuses.CAPTURED : PaymentStatuses.CAPTURE_FAILED,
    amountMinor: result.success ? result.amountCapturedMinor : 0,
    failureMessage: result.failureMessage ?? null,
    reused: false,
  };
}

/** Champ `deposit` écrit sur la mission à sa création. */
export function buildMissionDeposit(paymentId: string, now: admin.firestore.Timestamp): BookingDepositDoc {
  return {
    policy_version: BOOKING_DEPOSIT_POLICY.version,
    amount_minor: BOOKING_DEPOSIT_POLICY.amount_minor,
    currency: DEFAULT_CURRENCY,
    payment_id: paymentId,
    status: "captured",
    captured_at: now,
    updated_at: now,
  };
}

/** Écriture comptable du dépôt (débit client), au moment où la mission naît. */
export function writeDepositLedgerEntry(
  tx: FirebaseFirestore.Transaction,
  missionId: string,
  paymentId: string,
  now: admin.firestore.Timestamp
): void {
  const ref = db.collection("transaction_ledger").doc();
  tx.set(ref, {
    ledger_entry_id: ref.id,
    mission_id: missionId,
    transaction_id: paymentId,
    type: LedgerEntryTypes.CUSTOMER_CHARGE,
    purpose: "deposit",
    amount: toMajorUnits(BOOKING_DEPOSIT_POLICY.amount_minor),
    amount_minor: BOOKING_DEPOSIT_POLICY.amount_minor,
    direction: LedgerDirections.DEBIT,
    party: LedgerParties.CUSTOMER,
    currency: DEFAULT_CURRENCY,
    created_at: now,
    created_by: "createDeliveryRequest",
    source_event: "booking_deposit_captured",
    status: LedgerEntryStatuses.CONFIRMED,
    reference_id: null,
  });
}

/**
 * Annulation par le client : le dépôt est gardé seulement si un chauffeur
 * avait accepté ET que le ramassage est à moins de 48 h (ou « dès que
 * possible », ou le chauffeur est déjà en route). Sinon, remboursé.
 */
export function customerCancellationKeepsDeposit(mission: Record<string, any>, nowMs = Date.now()): boolean {
  if (mission.assignment_mode === "internal_test") return false;
  if (typeof mission.driver_id !== "string" || !mission.driver_id) return false;
  if (!DRIVER_COMMITTED_STATUSES.includes(String(mission.status))) return false;
  if (mission.status === "driver_to_pickup" || mission.status === "arrived_at_pickup") return true;
  const pickup = missionPickupAtMs(mission);
  if (pickup === null) return true;
  return pickup - nowMs < BOOKING_DEPOSIT_POLICY.refund_window_ms;
}

export type DepositRefundResult = "refunded" | "already_done" | "not_applicable" | "failed";

/**
 * Rembourse le dépôt d'une mission (idempotent : une seule demande de
 * remboursement par mission). Appelé par onMissionEndedClearTracking quand
 * une mission avec dépôt passe à « annulée » sans que le dépôt soit gardé.
 */
export async function refundBookingDeposit(
  missionId: string,
  options: { reason: string; actorUserId: string; actorRole: string }
): Promise<DepositRefundResult> {
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const prepared = await db.runTransaction(async (tx) => {
    const mission = (await tx.get(missionRef)).data();
    const deposit = mission?.deposit as BookingDepositDoc | undefined | null;
    if (!mission || !deposit) return { outcome: "not_applicable" as const };
    if (deposit.status === "refunded" || deposit.status === "kept") return { outcome: "already_done" as const };
    if (deposit.status !== "captured" && deposit.status !== "refund_pending" && deposit.status !== "refund_failed") {
      return { outcome: "not_applicable" as const };
    }
    const now = admin.firestore.Timestamp.now();
    tx.update(missionRef, {
      "deposit.status": "refund_pending",
      "deposit.refund_reason": options.reason,
      "deposit.updated_at": now,
    });
    return { outcome: "refund" as const, paymentId: deposit.payment_id, amountMinor: deposit.amount_minor,
      customerId: mission.customer_id as string };
  });
  if (prepared.outcome !== "refund") return prepared.outcome;

  const result = await refundPayment({
    paymentId: prepared.paymentId,
    amountMinor: prepared.amountMinor,
    reason: RefundReasons.CANCELLED_BEFORE_PICKUP,
    initiatedByUserId: options.actorUserId,
    initiatedByRole: options.actorRole,
    isAdminInitiated: options.actorRole === "admin" || options.actorRole === "super_admin",
    requestKey: `deposit_refund_${missionId}`,
  }).catch((error: unknown) => ({
    success: false, refundId: null as string | null, status: "failed",
    providerRefundId: null as string | null,
    failureMessage: error instanceof Error ? error.message : String(error),
    alreadyProcessed: false,
  }));

  await db.runTransaction(async (tx) => {
    const now = admin.firestore.Timestamp.now();
    tx.update(missionRef, {
      "deposit.status": result.success ? "refunded" : "refund_failed",
      "deposit.refund_id": result.refundId ?? null,
      "deposit.refunded_at": result.success ? now : null,
      "deposit.updated_at": now,
    });
    writeAuditLogInTransaction(tx, {
      actorUserId: options.actorUserId, actorRole: options.actorRole,
      action: result.success ? "booking_deposit_refunded" : "booking_deposit_refund_failed",
      sourceFunction: "refundBookingDeposit", targetId: missionId,
      metadata: { paymentId: prepared.paymentId, amountMinor: prepared.amountMinor, reason: options.reason,
        refundId: result.refundId ?? null, failureMessage: result.failureMessage ?? null },
    });
  });
  return result.success ? "refunded" : "failed";
}

/** Marque le dépôt comme gardé (annulation tardive du client), dans la transaction d'annulation. */
export function keepDepositInTransaction(
  tx: FirebaseFirestore.Transaction,
  missionRef: FirebaseFirestore.DocumentReference,
  now: admin.firestore.Timestamp,
  reason: string
): void {
  tx.update(missionRef, {
    "deposit.status": "kept",
    "deposit.kept_at": now,
    "deposit.kept_reason": reason,
    "deposit.updated_at": now,
  });
}
