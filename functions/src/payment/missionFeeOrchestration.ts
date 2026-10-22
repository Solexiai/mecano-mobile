// -----------------------------------------------------------------------------
// missionFeeOrchestration.ts — collects a mission fee (late cancellation or
// wasted trip, see lib/missionFees.ts) on a cancelled mission.
//
// Same 3-step pattern as captureMissionPayment (paymentOrchestration.ts):
//   1. transaction: AUTHORIZED -> CAPTURE_PENDING, fee "pending" -> "capturing";
//   2. Stripe call OUTSIDE any transaction, with a stable idempotency key;
//   3. transaction: apply the result (payment, mission fee, financial snapshot
//      for the driver share, ledger entries, audit log).
// Called only by onMissionEndedClearTracking on the transition to "cancelled"
// when the mission carries `cancellation_fee.status == "pending"`. Idempotent:
// a retry after a crash between steps 1 and 3 resumes with the same key.
// The fee amounts were frozen on the mission when the fee was decided and
// shown to the customer; they are never recomputed here.
// -----------------------------------------------------------------------------

import { admin, db } from "../lib/admin";
import { writeAuditLogInTransaction } from "../lib/audit";
import { buildIdempotencyKey } from "../lib/idempotency";
import { recalculateMissionFinancialBalance } from "../lib/missionFinancialBalance";
import { toMajorUnits, DEFAULT_CURRENCY } from "../lib/money";
import {
  logFinancialFailure,
  logFinancialSuccess,
  resolveCorrelationId,
  startFinancialOperationTimer,
} from "../lib/observability";
import { assertValidPaymentTransition } from "../lib/paymentStateMachine";
import { assertStripeReferenceEnvironmentConsistencyOrLog } from "../lib/stripeEnvironment";
import {
  LedgerDirections,
  LedgerEntryStatuses,
  LedgerEntryTypes,
  LedgerParties,
  MissionStatuses,
  PaymentDoc,
  PaymentStatuses,
} from "../lib/types";
import { getPaymentProvider } from "./paymentProviderFactory";

export type MissionFeeChargeResult =
  | "captured"
  | "already_done"
  | "not_collectable"
  | "failed"
  | "not_applicable";

/** Deterministic id: one fee snapshot per mission, never duplicated by a retry. */
export function missionFeeSnapshotId(missionId: string): string {
  return `fee_${missionId}`;
}

export async function chargeMissionFee(missionId: string): Promise<MissionFeeChargeResult> {
  const correlationId = resolveCorrelationId(undefined);
  const startedAt = startFinancialOperationTimer();
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const provider = getPaymentProvider();

  // ---- Step 1: reserve the capture ------------------------------------------
  const prepared = await db.runTransaction(async (tx) => {
    const missionSnap = await tx.get(missionRef);
    const mission = missionSnap.data();
    const fee = mission?.cancellation_fee;
    if (!mission || mission.status !== MissionStatuses.CANCELLED || !fee) {
      return { outcome: "not_applicable" as const };
    }
    if (fee.status === "captured" || fee.status === "failed" || fee.status === "not_collectable") {
      return { outcome: "already_done" as const };
    }
    const paymentId = fee.payment_id;
    const payRef = typeof paymentId === "string" && paymentId ? db.collection("payments").doc(paymentId) : null;
    const paySnap = payRef ? await tx.get(payRef) : null;
    const payment = paySnap?.data() as PaymentDoc | undefined;
    const now = admin.firestore.Timestamp.now();
    const resuming = fee.status === "capturing" && payment?.status === PaymentStatuses.CAPTURE_PENDING;
    const usable =
      !!payRef && !!payment &&
      mission.active_payment_id === paymentId &&
      payment.mission_id === missionId &&
      (payment.status === PaymentStatuses.AUTHORIZED || resuming) &&
      typeof payment.provider_payment_intent_id === "string" && !!payment.provider_payment_intent_id &&
      Number.isSafeInteger(fee.total_minor) && fee.total_minor > 0 &&
      fee.total_minor <= payment.amount_authorized_minor &&
      fee.driver_minor + fee.platform_minor === fee.total_minor;
    if (!usable) {
      tx.update(missionRef, {
        "cancellation_fee.status": "not_collectable",
        "cancellation_fee.failure_code": "no_authorized_payment",
        "cancellation_fee.updated_at": now,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: "system", actorRole: "system", action: "mission_fee_not_collectable",
        sourceFunction: "chargeMissionFee", targetId: missionId,
        metadata: { kind: fee.kind, paymentId: paymentId ?? null, paymentStatus: payment?.status ?? null },
      });
      return { outcome: "not_collectable" as const };
    }
    if (!resuming) {
      assertValidPaymentTransition(payment!.status, PaymentStatuses.CAPTURE_PENDING);
      tx.update(payRef!, { status: PaymentStatuses.CAPTURE_PENDING, updated_at: now });
      tx.update(missionRef, { "cancellation_fee.status": "capturing", "cancellation_fee.updated_at": now });
    }
    return {
      outcome: "capture" as const,
      paymentId: paymentId as string,
      providerPaymentIntentId: payment!.provider_payment_intent_id!,
      connected: !!payment!.connected_account_id,
      storedEnvironment: payment!.stripe_environment ?? null,
      kind: fee.kind as string,
      totalMinor: fee.total_minor as number,
      driverMinor: fee.driver_minor as number,
      platformMinor: fee.platform_minor as number,
      policyVersion: fee.policy_version as string,
      driverId: (mission.driver_id as string | null) ?? payment!.driver_id,
      customerId: mission.customer_id as string,
    };
  });
  if (prepared.outcome !== "capture") return prepared.outcome;

  const ids = { missionId, paymentId: prepared.paymentId };
  let envOk = true;
  try {
    assertStripeReferenceEnvironmentConsistencyOrLog({
      activeEnvironment: provider.environment,
      storedEnvironment: prepared.storedEnvironment,
      operation: "capture_mission_fee",
      operationStartedAt: startedAt,
      correlationId,
      identifiers: ids,
      refType: `payments/${prepared.paymentId}`,
    });
  } catch {
    envOk = false;
  }

  // ---- Step 2: partial capture, outside any transaction ---------------------
  // Destination charge: Movi-K keeps `platformMinor` as the application fee,
  // Stripe transfers the rest (the driver share) to the connected account.
  const result = envOk
    ? await provider.capturePayment({
        providerPaymentIntentId: prepared.providerPaymentIntentId,
        amountToCaptureMinor: prepared.totalMinor,
        ...(prepared.connected ? { applicationFeeMinor: prepared.platformMinor } : {}),
        idempotencyKey: buildIdempotencyKey("captureMissionFee", prepared.paymentId),
      })
    : { success: false, status: "failed", amountCapturedMinor: 0, providerChargeId: null,
        failureMessage: "stripe_environment_mismatch" };

  // ---- Step 3: apply the result --------------------------------------------
  await db.runTransaction(async (tx) => {
    const payRef = db.collection("payments").doc(prepared.paymentId);
    const snapshotRef = db.collection("financial_snapshots").doc(missionFeeSnapshotId(missionId));
    const [paySnap, existingSnapshot] = await Promise.all([tx.get(payRef), tx.get(snapshotRef)]);
    const payment = paySnap.data() as PaymentDoc | undefined;
    if (!payment || payment.status !== PaymentStatuses.CAPTURE_PENDING) return; // already applied
    const now = admin.firestore.Timestamp.now();
    const captured = result.success && result.amountCapturedMinor === prepared.totalMinor;

    if (!captured) {
      assertValidPaymentTransition(payment.status, PaymentStatuses.FAILED);
      tx.update(payRef, {
        status: PaymentStatuses.FAILED,
        failed_at: now,
        failure_code: "mission_fee_capture_failed",
        failure_message: result.failureMessage ?? "Capture des frais refusée par le fournisseur.",
        updated_at: now,
      });
      tx.update(missionRef, {
        payment_status: PaymentStatuses.FAILED,
        "cancellation_fee.status": "failed",
        "cancellation_fee.failure_code": "capture_failed",
        "cancellation_fee.updated_at": now,
      });
      writeAuditLogInTransaction(tx, {
        actorUserId: "system", actorRole: "system", action: "mission_fee_capture_failed",
        sourceFunction: "chargeMissionFee", targetId: missionId,
        metadata: { kind: prepared.kind, paymentId: prepared.paymentId, totalMinor: prepared.totalMinor },
      });
      return;
    }

    assertValidPaymentTransition(payment.status, PaymentStatuses.CAPTURED);
    tx.update(payRef, {
      status: PaymentStatuses.CAPTURED,
      amount_captured_minor: result.amountCapturedMinor,
      application_fee_minor: prepared.connected ? prepared.platformMinor : payment.application_fee_minor,
      provider_charge_id: result.providerChargeId,
      capture_purpose: "mission_fee",
      captured_at: now,
      updated_at: now,
    });
    tx.update(missionRef, {
      payment_status: PaymentStatuses.CAPTURED,
      "cancellation_fee.status": "captured",
      "cancellation_fee.captured_minor": result.amountCapturedMinor,
      "cancellation_fee.captured_at": now,
      "cancellation_fee.updated_at": now,
    });

    // Driver share: a CONFIRMED snapshot so the normal payout batch
    // (calculateDriverPayout) includes it. Distinct from the mission's own
    // quote snapshot, which stays untouched.
    const total = toMajorUnits(prepared.totalMinor, DEFAULT_CURRENCY);
    const driverShare = toMajorUnits(prepared.driverMinor, DEFAULT_CURRENCY);
    const platformShare = toMajorUnits(prepared.platformMinor, DEFAULT_CURRENCY);
    if (!existingSnapshot.exists) {
      tx.set(snapshotRef, {
        snapshot_kind: "mission_fee",
        fee_kind: prepared.kind,
        fee_policy_version: prepared.policyVersion,
        mission_id: missionId,
        customer_id: prepared.customerId,
        driver_id: prepared.driverId,
        payment_id: prepared.paymentId,
        customer_total: total,
        customer_total_minor: prepared.totalMinor,
        customer_service_fee: 0,
        customer_tax: 0,
        platform_commission_amount: platformShare,
        driver_offer_amount: driverShare,
        driver_net_mission_earnings: driverShare,
        driver_total_payout: driverShare,
        created_at: now,
        confirmed_at: now,
        status: "confirmed",
      });
    }

    const entries: Array<Record<string, unknown>> = [
      { type: LedgerEntryTypes.CUSTOMER_CHARGE, amount: total, amount_minor: prepared.totalMinor,
        direction: LedgerDirections.DEBIT, party: LedgerParties.CUSTOMER },
      { type: LedgerEntryTypes.PLATFORM_COMMISSION, amount: platformShare, amount_minor: prepared.platformMinor,
        direction: LedgerDirections.CREDIT, party: LedgerParties.PLATFORM },
      { type: LedgerEntryTypes.DRIVER_EARNING, amount: driverShare, amount_minor: prepared.driverMinor,
        direction: LedgerDirections.CREDIT, party: LedgerParties.DRIVER },
    ];
    for (const entry of entries) {
      const ref = db.collection("transaction_ledger").doc();
      tx.set(ref, {
        ledger_entry_id: ref.id,
        mission_id: missionId,
        transaction_id: prepared.paymentId,
        currency: DEFAULT_CURRENCY,
        created_at: now,
        created_by: "chargeMissionFee",
        source_event: "mission_fee_captured",
        fee_kind: prepared.kind,
        status: LedgerEntryStatuses.CONFIRMED,
        reference_id: snapshotRef.id,
        ...entry,
      });
    }
    writeAuditLogInTransaction(tx, {
      actorUserId: "system", actorRole: "system", action: "mission_fee_captured",
      sourceFunction: "chargeMissionFee", targetId: missionId,
      metadata: {
        kind: prepared.kind, paymentId: prepared.paymentId, totalMinor: prepared.totalMinor,
        driverMinor: prepared.driverMinor, platformMinor: prepared.platformMinor,
        policyVersion: prepared.policyVersion,
      },
    });
  });

  await recalculateMissionFinancialBalance(missionId);
  const success = result.success && result.amountCapturedMinor === prepared.totalMinor;
  if (success) {
    logFinancialSuccess("capture_mission_fee", startedAt, ids,
      { correlationId, metadata: { amountCapturedMinor: result.amountCapturedMinor, kind: prepared.kind } });
    return "captured";
  }
  logFinancialFailure("capture_mission_fee", startedAt, "mission_fee_capture_failed", ids,
    { correlationId, message: result.failureMessage ?? null });
  return "failed";
}
