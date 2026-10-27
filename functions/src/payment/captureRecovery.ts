// -----------------------------------------------------------------------------
// captureRecovery.ts — Reprise d'une capture refusée ou non concluante
// (rapport pré-lancement 2026-10-27, PAY-03 et PAY-11 ; décisions de
// Daniel du 27 octobre : 2 relances sur 3 jours, puis traitement manuel).
//
// Avant ce module, une capture refusée après livraison basculait le
// paiement en FAILED (terminal) : mission `completed`, snapshot confirmé,
// personne n'était prévenu et Movi-K ne revoyait jamais l'argent. Une
// erreur réseau pendant la capture était traitée exactement comme un refus
// de carte alors que Stripe avait peut-être débité.
//
// Ce que fait ce module :
//   1. `applyCaptureAttemptResult()` — applique le résultat d'un appel Stripe
//      de capture (initial ou relance) sur `payments/{id}` :
//        - succès       -> CAPTURED ;
//        - non concluant -> reste CAPTURE_PENDING, `capture_indeterminate_at`,
//                           recontrôle planifié (PAY-11) ;
//        - refus        -> CAPTURE_FAILED + relance planifiée, ou FAILED après
//                           la dernière relance (PAY-03).
//   2. `resolveIndeterminateCapture()` — rejoue EXACTEMENT le même appel
//      Stripe avec la MÊME clé d'idempotence : Stripe renvoie le résultat
//      d'origine si l'appel avait abouti, sinon l'exécute. Jamais un double
//      débit.
//   3. `retryFailedCapture()` — nouvelle tentative de débit : l'autorisation
//      d'origine est perdue (refus/expiration), donc NOUVEAU PaymentIntent
//      off-session sur le moyen de paiement par défaut ACTUEL du client (qui a
//      pu le mettre à jour entre-temps), capturé immédiatement, même
//      destination chauffeur et mêmes frais plateforme. Clé d'idempotence
//      distincte par tentative.
//   4. `processCaptureRecoveryBatch()` — balayage périodique (cron) des
//      paiements à recontrôler ou à relancer.
//
// Schéma en 3 temps conservé (voir paymentOrchestration.ts) : jamais
// d'appel Stripe dans une transaction Firestore.
// -----------------------------------------------------------------------------

import { admin, db } from "../lib/admin";
import { buildIdempotencyKey } from "../lib/idempotency";
import { assertValidPaymentTransition } from "../lib/paymentStateMachine";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { writeAuditLog } from "../lib/audit";
import { failedPrecondition, notFound } from "../lib/errors";
import {
  logFinancialFailure,
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "../lib/observability";
import { DEFAULT_CURRENCY } from "../lib/money";
import { PaymentDoc, PaymentStatuses } from "../lib/types";
import { getPaymentProvider } from "./paymentProviderFactory";
import type { CapturePaymentResult, ChargeSavedPaymentMethodResult } from "./paymentProvider";

/** 1 capture initiale + 2 relances (décision Daniel, 2026-10-27). */
export const MAX_CAPTURE_ATTEMPTS = 3;
/** Délais avant chaque relance, indexés par le numéro de la tentative qui vient d'échouer. */
export const RETRY_DELAYS_MS: Record<number, number> = {
  1: 24 * 60 * 60 * 1000, // refus de la capture initiale -> relance à J+1
  2: 48 * 60 * 60 * 1000, // refus de la 1re relance      -> relance à J+3
};
/** Recontrôle d'un appel non concluant (PAY-11). */
export const INDETERMINATE_RECHECK_MS = 15 * 60 * 1000;
export const FINAL_FAILURE_CODE = "capture_abandoned_after_retries";

export type CaptureAttemptMode = "initial" | "recovery";

export interface CaptureAttemptOutcome {
  status: string;
  success: boolean;
  indeterminate: boolean;
  attempt: number;
  failureMessage?: string | null;
}

interface AttemptResultLike {
  success: boolean;
  status: string;
  amountCapturedMinor: number;
  providerChargeId: string | null;
  providerPaymentIntentId?: string | null;
  failureCode?: string | null;
  failureMessage?: string | null;
  indeterminate?: boolean;
}

function attemptKey(paymentId: string, attempt: number): string {
  return attempt <= 1
    ? buildIdempotencyKey("capturePayment", paymentId)
    : buildIdempotencyKey("captureRetry", paymentId, String(attempt));
}

/**
 * Applique, dans une transaction, le résultat d'une tentative de capture
 * (initiale ou relance). Le paiement DOIT être en CAPTURE_PENDING (c'est
 * l'état intermédiaire posé avant l'appel Stripe). Idempotent : un paiement
 * déjà sorti de CAPTURE_PENDING n'est jamais réécrit.
 */
export async function applyCaptureAttemptResult(params: {
  missionId: string;
  paymentId: string;
  result: AttemptResultLike;
  mode: CaptureAttemptMode;
  correlationId: string;
  operationStartedAt: number;
}): Promise<CaptureAttemptOutcome> {
  const { missionId, paymentId, result, mode, correlationId, operationStartedAt } = params;
  const payRef = db.collection("payments").doc(paymentId);
  const missionRef = db.collection("delivery_requests").doc(missionId);

  const outcome = await db.runTransaction(async (tx): Promise<CaptureAttemptOutcome> => {
    const paySnap = await tx.get(payRef);
    if (!paySnap.exists) throw notFound(`payments/${paymentId} introuvable.`);
    const payment = paySnap.data() as PaymentDoc;
    const attempt = Math.max(1, payment.capture_attempt_count ?? 1);
    if (payment.status !== PaymentStatuses.CAPTURE_PENDING) {
      // Déjà appliqué (concurrence, cron + callable) : ne rien réécrire.
      return { status: payment.status, success: payment.status === PaymentStatuses.CAPTURED, indeterminate: false, attempt };
    }
    const now = admin.firestore.Timestamp.now();

    if (result.success) {
      assertValidPaymentTransition(payment.status, PaymentStatuses.CAPTURED);
      const update: Record<string, unknown> = {
        status: PaymentStatuses.CAPTURED,
        amount_captured_minor: result.amountCapturedMinor,
        provider_charge_id: result.providerChargeId,
        captured_at: now,
        capture_retry_at: null,
        capture_indeterminate_at: null,
        failure_code: null,
        failure_message: null,
        updated_at: now,
      };
      if (mode === "recovery" && result.providerPaymentIntentId) {
        // Le débit a eu lieu sur un NOUVEAU PaymentIntent : il devient la
        // référence (remboursements, reçu, webhooks) ; l'ancien est conservé.
        update.original_payment_intent_id =
          payment.original_payment_intent_id ?? payment.provider_payment_intent_id ?? null;
        update.provider_payment_intent_id = result.providerPaymentIntentId;
      }
      tx.update(payRef, update);
      tx.update(missionRef, { payment_status: PaymentStatuses.CAPTURED });
      return { status: PaymentStatuses.CAPTURED, success: true, indeterminate: false, attempt };
    }

    if (result.indeterminate) {
      // PAY-11 : résultat inconnu -> on reste en CAPTURE_PENDING et on
      // recontrôle plus tard avec la même clé d'idempotence.
      tx.update(payRef, {
        capture_indeterminate_at: now,
        capture_retry_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + INDETERMINATE_RECHECK_MS),
        failure_code: result.failureCode ?? "capture_indeterminate",
        failure_message: result.failureMessage ?? "Réponse du fournisseur de paiement non reçue.",
        updated_at: now,
      });
      return { status: PaymentStatuses.CAPTURE_PENDING, success: false, indeterminate: true, attempt, failureMessage: result.failureMessage };
    }

    // Refus concluant.
    const recoveryIds = new Set(payment.recovery_payment_intent_ids ?? []);
    if (mode === "recovery" && result.providerPaymentIntentId) recoveryIds.add(result.providerPaymentIntentId);
    const exhausted = attempt >= MAX_CAPTURE_ATTEMPTS;
    const nextStatus = exhausted ? PaymentStatuses.FAILED : PaymentStatuses.CAPTURE_FAILED;
    assertValidPaymentTransition(payment.status, nextStatus);
    const delay = RETRY_DELAYS_MS[attempt] ?? null;
    tx.update(payRef, {
      status: nextStatus,
      failed_at: now,
      failure_code: exhausted ? FINAL_FAILURE_CODE : (result.failureCode ?? "capture_failed"),
      failure_message: result.failureMessage ?? "Capture refusée par le fournisseur.",
      capture_retry_at: exhausted || delay === null ? null : admin.firestore.Timestamp.fromMillis(now.toMillis() + delay),
      capture_indeterminate_at: null,
      recovery_payment_intent_ids: [...recoveryIds],
      updated_at: now,
    });
    tx.update(missionRef, {
      payment_status: nextStatus,
      ...(exhausted ? { payment_failure_kind: "capture_abandoned" } : {}),
    });
    return { status: nextStatus, success: false, indeterminate: false, attempt, failureMessage: result.failureMessage };
  });

  await recalculateMissionFinancialBalance(missionId);

  if (outcome.success) {
    logFinancialSuccess("capture_payment", operationStartedAt, { missionId, paymentId },
      { correlationId, metadata: { mode, attempt: outcome.attempt, amountCapturedMinor: result.amountCapturedMinor } });
  } else if (outcome.indeterminate) {
    logFinancialFailure("capture_payment", operationStartedAt, "capture_indeterminate", { missionId, paymentId },
      { correlationId, message: result.failureMessage, metadata: { mode, attempt: outcome.attempt } });
  } else {
    logFinancialFailure("capture_payment", operationStartedAt,
      outcome.status === PaymentStatuses.FAILED ? FINAL_FAILURE_CODE : "capture_failed",
      { missionId, paymentId },
      { correlationId, message: result.failureMessage, metadata: { mode, attempt: outcome.attempt, nextStatus: outcome.status } });
    await writeAuditLog({
      actorUserId: "system",
      actorRole: "system",
      action: outcome.status === PaymentStatuses.FAILED ? "capture_abandoned_after_retries" : "capture_failed_retry_scheduled",
      sourceFunction: "captureRecovery",
      targetId: paymentId,
      metadata: { missionId, mode, attempt: outcome.attempt, failureCode: result.failureCode ?? null, correlationId },
    });
  }
  return outcome;
}

/**
 * PAY-11 — un paiement resté en CAPTURE_PENDING après une réponse non
 * concluante : rejoue le MÊME appel Stripe avec la MÊME clé d'idempotence
 * (Stripe renvoie le résultat déjà obtenu s'il existe), puis applique.
 */
export async function resolveIndeterminateCapture(paymentId: string): Promise<CaptureAttemptOutcome> {
  const payRef = db.collection("payments").doc(paymentId);
  const snap = await payRef.get();
  if (!snap.exists) throw notFound(`payments/${paymentId} introuvable.`);
  const payment = snap.data() as PaymentDoc;
  if (payment.status !== PaymentStatuses.CAPTURE_PENDING) {
    return { status: payment.status, success: payment.status === PaymentStatuses.CAPTURED, indeterminate: false, attempt: payment.capture_attempt_count ?? 1 };
  }
  const attempt = Math.max(1, payment.capture_attempt_count ?? 1);
  const mode: CaptureAttemptMode = attempt <= 1 ? "initial" : "recovery";
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();
  const provider = getPaymentProvider();
  const key = attemptKey(paymentId, attempt);

  let result: AttemptResultLike;
  if (mode === "initial") {
    if (!payment.provider_payment_intent_id) {
      throw failedPrecondition("Aucun PaymentIntent à recontrôler.");
    }
    const amountToCapture = Number.isSafeInteger(payment.service_amount_minor) &&
      (payment.service_amount_minor as number) > 0 &&
      (payment.service_amount_minor as number) <= payment.amount_authorized_minor
      ? (payment.service_amount_minor as number)
      : payment.amount_authorized_minor;
    const r: CapturePaymentResult = await provider.capturePayment({
      providerPaymentIntentId: payment.provider_payment_intent_id,
      amountToCaptureMinor: amountToCapture,
      idempotencyKey: key,
    });
    result = r;
  } else {
    const r: ChargeSavedPaymentMethodResult = await provider.chargeSavedPaymentMethod(
      recoveryChargeParams(payment, key, attempt)
    );
    result = r;
  }
  return applyCaptureAttemptResult({
    missionId: payment.mission_id, paymentId, result, mode, correlationId, operationStartedAt,
  });
}

function recoveryChargeParams(payment: PaymentDoc, idempotencyKey: string, attempt: number) {
  const amount = Number.isSafeInteger(payment.service_amount_minor) && (payment.service_amount_minor as number) > 0
    ? (payment.service_amount_minor as number)
    : payment.amount_authorized_minor;
  return {
    providerCustomerId: payment.provider_customer_id as string,
    providerPaymentMethodId: payment.provider_payment_method_id as string,
    amountMinor: amount,
    currency: DEFAULT_CURRENCY,
    connectedAccountId: payment.connected_account_id,
    applicationFeeMinor: payment.application_fee_minor,
    idempotencyKey,
    metadata: {
      movik_mission_id: payment.mission_id,
      movik_payment_id: payment.payment_id,
      movik_recovery_attempt: String(attempt),
    },
  };
}

export interface RetryFailedCaptureOptions {
  /** `cron` = relance planifiée ; `customer` = après mise à jour de carte ; `admin` = forcée. */
  trigger: "cron" | "customer" | "admin";
  actorUserId: string;
}

/**
 * PAY-03 — relance d'un paiement en CAPTURE_FAILED. Le cron et le client
 * ne peuvent relancer que s'il reste des tentatives (MAX_CAPTURE_ATTEMPTS) ;
 * un admin peut forcer une relance supplémentaire tant que le paiement est
 * encore en CAPTURE_FAILED. FAILED reste terminal (traitement manuel).
 */
export async function retryFailedCapture(
  paymentId: string,
  options: RetryFailedCaptureOptions
): Promise<CaptureAttemptOutcome> {
  const payRef = db.collection("payments").doc(paymentId);
  const correlationId = resolveCorrelationId(undefined);
  const operationStartedAt = startFinancialOperationTimer();
  const provider = getPaymentProvider();

  // Étape 1 : transaction — CAPTURE_FAILED -> CAPTURE_PENDING, tentative++,
  // moyen de paiement ACTUEL du client (peut avoir été mis à jour).
  const prepared = await db.runTransaction(async (tx) => {
    const paySnap = await tx.get(payRef);
    if (!paySnap.exists) throw notFound(`payments/${paymentId} introuvable.`);
    const payment = paySnap.data() as PaymentDoc;
    if (payment.status !== PaymentStatuses.CAPTURE_FAILED) {
      return { skip: true as const, status: payment.status, attempt: payment.capture_attempt_count ?? 1 };
    }
    const previousAttempts = Math.max(1, payment.capture_attempt_count ?? 1);
    if (previousAttempts >= MAX_CAPTURE_ATTEMPTS && options.trigger !== "admin") {
      throw failedPrecondition("Toutes les tentatives automatiques ont été utilisées ; traitement manuel requis.");
    }
    if (payment.stripe_environment && payment.stripe_environment !== provider.environment) {
      throw failedPrecondition("Ce paiement appartient à un autre environnement Stripe.");
    }
    const profileSnap = await tx.get(db.collection("payment_profiles").doc(payment.customer_id));
    const profile = profileSnap.data();
    const methodId = (profile?.default_payment_method_id as string | null | undefined) ?? payment.provider_payment_method_id;
    const customerId = (profile?.provider_customer_id as string | undefined) ?? payment.provider_customer_id;
    if (!methodId || !customerId) {
      throw failedPrecondition("Aucun moyen de paiement enregistré pour ce client.");
    }
    const attempt = previousAttempts + 1;
    const now = admin.firestore.Timestamp.now();
    assertValidPaymentTransition(payment.status, PaymentStatuses.CAPTURE_PENDING);
    tx.update(payRef, {
      status: PaymentStatuses.CAPTURE_PENDING,
      capture_attempt_count: attempt,
      capture_retry_at: null,
      capture_indeterminate_at: null,
      provider_payment_method_id: methodId,
      provider_customer_id: customerId,
      updated_at: now,
    });
    tx.update(db.collection("delivery_requests").doc(payment.mission_id), {
      payment_status: PaymentStatuses.CAPTURE_PENDING,
    });
    return { skip: false as const, attempt, payment: { ...payment, provider_payment_method_id: methodId, provider_customer_id: customerId, capture_attempt_count: attempt } };
  });

  if (prepared.skip) {
    return { status: prepared.status, success: prepared.status === PaymentStatuses.CAPTURED, indeterminate: false, attempt: prepared.attempt };
  }

  await writeAuditLog({
    actorUserId: options.actorUserId,
    actorRole: options.trigger === "admin" ? "admin" : options.trigger === "customer" ? "customer" : "system",
    action: "capture_retry_started",
    sourceFunction: "captureRecovery",
    targetId: paymentId,
    metadata: { missionId: prepared.payment.mission_id, attempt: prepared.attempt, trigger: options.trigger, correlationId },
  });

  // Étape 2 : appel Stripe réel, hors transaction.
  const key = attemptKey(paymentId, prepared.attempt);
  const result = await provider.chargeSavedPaymentMethod(
    recoveryChargeParams(prepared.payment as PaymentDoc, key, prepared.attempt)
  );

  // Étape 3 : application.
  return applyCaptureAttemptResult({
    missionId: prepared.payment.mission_id,
    paymentId,
    result,
    mode: "recovery",
    correlationId,
    operationStartedAt,
  });
}

/**
 * Balayage périodique : recontrôle les captures non concluantes et relance
 * les captures refusées dont l'échéance est passée. Borné, jamais plus d'un
 * lot par exécution ; chaque paiement est traité indépendamment.
 */
export async function processCaptureRecoveryBatch(
  nowMillis = Date.now(),
  limit = 50
): Promise<{ rechecked: number; retried: number; captured: number; failed: number; errors: number }> {
  const now = admin.firestore.Timestamp.fromMillis(nowMillis);
  const totals = { rechecked: 0, retried: 0, captured: 0, failed: 0, errors: 0 };

  const pending = await db.collection("payments")
    .where("status", "==", PaymentStatuses.CAPTURE_PENDING)
    .where("capture_retry_at", "<=", now)
    .limit(limit)
    .get();
  for (const doc of pending.docs) {
    try {
      const out = await resolveIndeterminateCapture(doc.id);
      totals.rechecked++;
      if (out.success) totals.captured++;
      if (out.status === PaymentStatuses.FAILED) totals.failed++;
    } catch (err) {
      totals.errors++;
      console.error("[capture-recovery] recheck failed", doc.id, err instanceof Error ? err.message : String(err));
    }
  }

  const failed = await db.collection("payments")
    .where("status", "==", PaymentStatuses.CAPTURE_FAILED)
    .where("capture_retry_at", "<=", now)
    .limit(limit)
    .get();
  for (const doc of failed.docs) {
    try {
      const out = await retryFailedCapture(doc.id, { trigger: "cron", actorUserId: "system" });
      totals.retried++;
      if (out.success) totals.captured++;
      if (out.status === PaymentStatuses.FAILED) totals.failed++;
    } catch (err) {
      totals.errors++;
      console.error("[capture-recovery] retry failed", doc.id, err instanceof Error ? err.message : String(err));
    }
  }
  return totals;
}
