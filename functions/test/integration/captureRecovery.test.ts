// -----------------------------------------------------------------------------
// captureRecovery.test.ts — PAY-03 / PAY-11 (rapport pré-lancement
// 2026-10-27, décisions de Daniel : 2 relances sur 3 jours puis manuel).
//
// Scénarios :
//   1. capture refusée après livraison -> CAPTURE_FAILED (pas FAILED),
//      relance planifiée à J+1, mission toujours `completed`, client notifié ;
//   2. relance réussie (après mise à jour de carte) -> CAPTURED sur un
//      NOUVEAU PaymentIntent, l'ancien conservé ;
//   3. trois refus -> FAILED terminal + `capture_abandoned_after_retries`,
//      mission marquée pour le recouvrement manuel ;
//   4. réponse non concluante (PAY-11) -> reste CAPTURE_PENDING, recontrôle
//      planifié, puis résolution par rejeu avec la MÊME clé d'idempotence ;
//   5. le cron balaie les deux files ;
//   6. la callable client refuse un étranger et un paiement déjà encaissé.
// -----------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses, PaymentDoc, PaymentStatuses } from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";
import { captureMissionPayment } from "../../src/payment/paymentOrchestration";
import {
  FINAL_FAILURE_CODE,
  INDETERMINATE_RECHECK_MS,
  MAX_CAPTURE_ATTEMPTS,
  processCaptureRecoveryBatch,
  resolveIndeterminateCapture,
  retryFailedCapture,
  RETRY_DELAYS_MS,
} from "../../src/payment/captureRecovery";
import { retryFailedCapture as retryFailedCaptureCallable } from "../../src/functions/captureRecovery";

const CUSTOMER_ID = "caprec_customer_001";
const OTHER_CUSTOMER_ID = "caprec_customer_other";
const DRIVER_ID = "caprec_driver_001";
const DAY = 24 * 60 * 60 * 1000;

function request<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { role, roles: [role] } as unknown as DecodedIdToken, rawToken: "fake" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seed(tag: string, priceMinor = 4500): Promise<{ missionId: string; paymentId: string }> {
  const missionId = `caprec_mission_${tag}`;
  const paymentId = `caprec_pay_${tag}`;
  const now = admin.firestore.Timestamp.now();
  await db.collection("delivery_requests").doc(missionId).set({
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: MissionStatuses.COMPLETED,
    completed_at: now,
    active_payment_id: paymentId,
    payment_status: PaymentStatuses.AUTHORIZED,
    assignment_mode: "standard",
    created_at: now,
    updated_at: now,
  });
  await db.collection("payment_profiles").doc(CUSTOMER_ID).set({
    customer_id: CUSTOMER_ID,
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    default_payment_method_id: "pm_original",
    stripe_environment: "test",
    created_at: now,
    updated_at: now,
  });
  await db.collection("payments").doc(paymentId).set({
    payment_id: paymentId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: PaymentStatuses.AUTHORIZED,
    currency: "CAD",
    amount_requested_minor: priceMinor,
    amount_authorized_minor: priceMinor,
    service_amount_minor: priceMinor,
    amount_captured_minor: 0,
    amount_refunded_minor: 0,
    application_fee_minor: 900,
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    provider_payment_method_id: "pm_original",
    provider_payment_intent_id: `fake_pi_${paymentId}`,
    provider_charge_id: null,
    connected_account_id: "acct_fake_driver",
    idempotency_key: `createPayment:${paymentId}`,
    stripe_environment: "test",
    authorized_at: now,
    created_at: now,
    updated_at: now,
  });
  return { missionId, paymentId };
}

async function payment(id: string): Promise<PaymentDoc> {
  return (await db.collection("payments").doc(id).get()).data() as PaymentDoc;
}

async function cleanup(ids: { missionId: string; paymentId: string }[]): Promise<void> {
  const batch = db.batch();
  for (const { missionId, paymentId } of ids) {
    batch.delete(db.collection("payments").doc(paymentId));
    batch.delete(db.collection("delivery_requests").doc(missionId));
    batch.delete(db.collection("mission_financial_balance").doc(missionId));
  }
  await batch.commit();
  const audits = await db.collection("audit_logs").where("source_function", "==", "captureRecovery").get();
  const b2 = db.batch();
  audits.docs.forEach((d) => b2.delete(d.ref));
  await b2.commit();
}

afterEach(() => setPaymentProviderForTesting(null));

describe("PAY-03 — capture refusée après livraison", () => {
  it("1. bascule en CAPTURE_FAILED avec une relance à J+1, mission toujours completed", async () => {
    const seeded = await seed("refused");
    setPaymentProviderForTesting(new FakePaymentProvider({ forceCaptureFailure: true, failureCode: "card_declined" }));

    const outcome = await captureMissionPayment(seeded.missionId, seeded.paymentId);
    expect(outcome.success).toBe(false);
    expect(outcome.status).toBe(PaymentStatuses.CAPTURE_FAILED);

    const p = await payment(seeded.paymentId);
    expect(p.status).toBe(PaymentStatuses.CAPTURE_FAILED);
    expect(p.capture_attempt_count).toBe(1);
    expect(p.failure_code).toBe("card_declined");
    const retryAt = p.capture_retry_at!.toMillis();
    expect(retryAt - Date.now()).toBeGreaterThan(RETRY_DELAYS_MS[1] - 60_000);
    expect(retryAt - Date.now()).toBeLessThanOrEqual(RETRY_DELAYS_MS[1]);

    const mission = (await db.collection("delivery_requests").doc(seeded.missionId).get()).data()!;
    expect(mission.status).toBe(MissionStatuses.COMPLETED);
    expect(mission.payment_status).toBe(PaymentStatuses.CAPTURE_FAILED);
    expect(mission.payment_failure_kind).toBeUndefined();

    await cleanup([seeded]);
  });

  it("2. une relance réussie encaisse sur un NOUVEAU PaymentIntent avec la carte mise à jour", async () => {
    const seeded = await seed("retry_ok");
    setPaymentProviderForTesting(new FakePaymentProvider({ forceCaptureFailure: true }));
    await captureMissionPayment(seeded.missionId, seeded.paymentId);

    // Le client enregistre une nouvelle carte (completeSavedSetup aurait fait cette écriture).
    await db.collection("payment_profiles").doc(CUSTOMER_ID).update({ default_payment_method_id: "pm_new_card" });

    const provider = new FakePaymentProvider();
    setPaymentProviderForTesting(provider);
    const outcome = await retryFailedCapture(seeded.paymentId, { trigger: "customer", actorUserId: CUSTOMER_ID });
    expect(outcome.success).toBe(true);
    expect(outcome.attempt).toBe(2);

    expect(provider.chargedSavedMethodParams).toHaveLength(1);
    expect(provider.chargedSavedMethodParams[0]).toMatchObject({
      providerPaymentMethodId: "pm_new_card",
      amountMinor: 4500,
      connectedAccountId: "acct_fake_driver",
      applicationFeeMinor: 900,
      idempotencyKey: `captureRetry:${seeded.paymentId}:2`,
    });

    const p = await payment(seeded.paymentId);
    expect(p.status).toBe(PaymentStatuses.CAPTURED);
    expect(p.amount_captured_minor).toBe(4500);
    expect(p.original_payment_intent_id).toBe(`fake_pi_${seeded.paymentId}`);
    expect(p.provider_payment_intent_id).not.toBe(`fake_pi_${seeded.paymentId}`);
    expect(p.capture_retry_at).toBeNull();
    const mission = (await db.collection("delivery_requests").doc(seeded.missionId).get()).data()!;
    expect(mission.payment_status).toBe(PaymentStatuses.CAPTURED);

    await cleanup([seeded]);
  });

  it("3. après MAX_CAPTURE_ATTEMPTS refus : FAILED terminal, recouvrement manuel", async () => {
    const seeded = await seed("exhausted");
    setPaymentProviderForTesting(new FakePaymentProvider({ forceCaptureFailure: true, forceChargeFailure: true }));
    await captureMissionPayment(seeded.missionId, seeded.paymentId);
    let p = await payment(seeded.paymentId);
    expect(p.capture_retry_at!.toMillis() - Date.now()).toBeLessThanOrEqual(DAY);

    await retryFailedCapture(seeded.paymentId, { trigger: "cron", actorUserId: "system" });
    p = await payment(seeded.paymentId);
    expect(p.status).toBe(PaymentStatuses.CAPTURE_FAILED);
    expect(p.capture_attempt_count).toBe(2);
    expect(p.capture_retry_at!.toMillis() - Date.now()).toBeGreaterThan(DAY); // J+3 après la 1re relance

    const last = await retryFailedCapture(seeded.paymentId, { trigger: "cron", actorUserId: "system" });
    expect(last.status).toBe(PaymentStatuses.FAILED);
    p = await payment(seeded.paymentId);
    expect(p.capture_attempt_count).toBe(MAX_CAPTURE_ATTEMPTS);
    expect(p.failure_code).toBe(FINAL_FAILURE_CODE);
    expect(p.capture_retry_at).toBeNull();
    expect(p.recovery_payment_intent_ids).toHaveLength(2);
    const mission = (await db.collection("delivery_requests").doc(seeded.missionId).get()).data()!;
    expect(mission.payment_status).toBe(PaymentStatuses.FAILED);
    expect(mission.payment_failure_kind).toBe("capture_abandoned");

    // Plus aucune relance automatique ni client ; FAILED est terminal.
    await expect(
      retryFailedCapture(seeded.paymentId, { trigger: "cron", actorUserId: "system" })
    ).resolves.toMatchObject({ status: PaymentStatuses.FAILED, success: false });

    await cleanup([seeded]);
  });

  it("4. PAY-11 : réponse non concluante -> reste CAPTURE_PENDING, puis rejeu avec la même clé", async () => {
    const seeded = await seed("indeterminate");
    const flaky = new FakePaymentProvider({ forceCaptureIndeterminate: true });
    setPaymentProviderForTesting(flaky);
    const outcome = await captureMissionPayment(seeded.missionId, seeded.paymentId);
    expect(outcome.success).toBe(false);
    expect(outcome.status).toBe(PaymentStatuses.CAPTURE_PENDING);

    let p = await payment(seeded.paymentId);
    expect(p.status).toBe(PaymentStatuses.CAPTURE_PENDING);
    expect(p.capture_indeterminate_at).toBeTruthy();
    expect(p.capture_retry_at!.toMillis() - Date.now()).toBeLessThanOrEqual(INDETERMINATE_RECHECK_MS);

    // Stripe répond cette fois : même appel, même clé d'idempotence.
    const healthy = new FakePaymentProvider();
    setPaymentProviderForTesting(healthy);
    const resolved = await resolveIndeterminateCapture(seeded.paymentId);
    expect(resolved.success).toBe(true);
    expect(healthy.capturedPaymentParams[0].idempotencyKey).toBe(`capturePayment:${seeded.paymentId}`);
    expect(healthy.chargedSavedMethodParams).toHaveLength(0); // jamais un nouveau débit
    p = await payment(seeded.paymentId);
    expect(p.status).toBe(PaymentStatuses.CAPTURED);
    expect(p.capture_indeterminate_at).toBeNull();

    await cleanup([seeded]);
  });

  it("5. le cron relance ce qui est échu et recontrôle ce qui est en attente", async () => {
    const due = await seed("cron_due");
    const notDue = await seed("cron_not_due");
    setPaymentProviderForTesting(new FakePaymentProvider({ forceCaptureFailure: true }));
    await captureMissionPayment(due.missionId, due.paymentId);
    await captureMissionPayment(notDue.missionId, notDue.paymentId);

    setPaymentProviderForTesting(new FakePaymentProvider());
    const beforeDue = await processCaptureRecoveryBatch(Date.now());
    expect(beforeDue.retried).toBe(0);

    // J+1 : seul `due` est échu (on avance son échéance).
    await db.collection("payments").doc(due.paymentId).update({
      capture_retry_at: admin.firestore.Timestamp.fromMillis(Date.now() - 1000),
    });
    const result = await processCaptureRecoveryBatch(Date.now());
    expect(result.retried).toBe(1);
    expect(result.captured).toBe(1);
    expect((await payment(due.paymentId)).status).toBe(PaymentStatuses.CAPTURED);
    expect((await payment(notDue.paymentId)).status).toBe(PaymentStatuses.CAPTURE_FAILED);

    await cleanup([due, notDue]);
  });

  it("6. callable : propriétaire accepté, étranger refusé, paiement encaissé refusé", async () => {
    const seeded = await seed("callable");
    setPaymentProviderForTesting(new FakePaymentProvider({ forceCaptureFailure: true }));
    await captureMissionPayment(seeded.missionId, seeded.paymentId);

    await expect(
      retryFailedCaptureCallable.run(request(OTHER_CUSTOMER_ID, "customer", { paymentId: seeded.paymentId }))
    ).rejects.toThrow();

    setPaymentProviderForTesting(new FakePaymentProvider());
    const ok = await retryFailedCaptureCallable.run(request(CUSTOMER_ID, "customer", { paymentId: seeded.paymentId }));
    expect(ok.success).toBe(true);
    expect(ok.attempt).toBe(2);

    await expect(
      retryFailedCaptureCallable.run(request(CUSTOMER_ID, "customer", { paymentId: seeded.paymentId }))
    ).rejects.toThrow(/encaissé/);

    await cleanup([seeded]);
  });
});
