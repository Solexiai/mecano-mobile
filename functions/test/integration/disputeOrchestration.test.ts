// ---------------------------------------------------------------------------
// Test d'intégration — openDispute / transitionDisputeStatus /
// updateDisputeStatus (Phase 6, directive 38 points, point 8 et 9).
//
// Couvre :
//   - ouverture d'un litige : payment -> DISPUTED, ledger CHARGEBACK_FEE
//   - idempotence à l'ouverture (même provider_dispute_id rejoué)
//   - transition OPENED -> UNDER_REVIEW -> WON : payment -> CAPTURED,
//     ledger CHARGEBACK_WON
//   - transition OPENED -> UNDER_REVIEW -> LOST : payment -> CHARGEBACK,
//     ledger CHARGEBACK_LOST
//   - transition LOST -> REVERSED : payment -> REFUNDED, ledger
//     CHARGEBACK_REVERSAL
//   - transitions invalides refusées (ex: WON -> LOST direct)
//   - self-transition idempotente (même statut rejoué => skipped=true,
//     aucun doublon ledger)
//   - updateDisputeStatus : admin uniquement (permission-denied sinon)
//   - mission_financial_balance recalculé après chaque transition effective
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { openDispute, transitionDisputeStatus } from "../../src/payment/disputeOrchestration";
import { updateDisputeStatus, UpdateDisputeStatusRequest } from "../../src/functions/updateDisputeStatus";
import { admin, db } from "../../src/lib/admin";
import { DisputeStatuses, PaymentStatuses } from "../../src/lib/types";

const CUSTOMER_ID = "dispute_customer_001";
const DRIVER_ID = "dispute_driver_001";
const ADMIN_ID = "dispute_admin_001";

function buildRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { role } as unknown as DecodedIdToken, rawToken: "fake-raw-token" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedPayment(paymentId: string, missionId: string, amountCapturedMinor = 5000): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("payments").doc(paymentId).set({
    payment_id: paymentId,
    mission_id: missionId,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: amountCapturedMinor,
    amount_captured_minor: amountCapturedMinor,
    amount_refunded_minor: 0,
    application_fee_minor: Math.round(amountCapturedMinor * 0.15),
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    provider_payment_method_id: `fake_pm_${CUSTOMER_ID}`,
    provider_payment_intent_id: `fake_pi_${paymentId}`,
    provider_charge_id: `fake_ch_${paymentId}`,
    connected_account_id: null,
    idempotency_key: `createPayment:${paymentId}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
  });
}

async function cleanup(paymentIds: string[], missionIds: string[], disputeIds: string[]): Promise<void> {
  const batch = db.batch();
  for (const pid of paymentIds) batch.delete(db.collection("payments").doc(pid));
  for (const did of disputeIds) batch.delete(db.collection("disputes").doc(did));
  for (const mid of missionIds) {
    const ledgerSnap = await db.collection("transaction_ledger").where("mission_id", "==", mid).get();
    ledgerSnap.docs.forEach((d) => batch.delete(d.ref));
    batch.delete(db.collection("mission_financial_balance").doc(mid));
  }
  const auditSnap = await db.collection("audit_logs").where("source_function", "in", ["openDispute", "transitionDisputeStatus", "updateDisputeStatus"]).get();
  auditSnap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

describe("disputeOrchestration — openDispute / transitionDisputeStatus", () => {
  it("ouvre un litige : payment -> DISPUTED, ledger CHARGEBACK_FEE, mission_financial_balance recalculé", async () => {
    const paymentId = "pay_dispute_open_1";
    const missionId = "mission_dispute_open_1";
    const disputeId = "dp_open_1";
    await seedPayment(paymentId, missionId);

    const result = await openDispute({
      providerDisputeId: disputeId,
      paymentId,
      amountMinor: 5000,
      reason: "fraudulent",
    });
    expect(result.alreadyExisted).toBe(false);
    expect(result.disputeId).toBe(disputeId);

    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.status).toBe(PaymentStatuses.DISPUTED);

    const dispute = (await db.collection("disputes").doc(disputeId).get()).data()!;
    expect(dispute.status).toBe(DisputeStatuses.OPENED);
    expect(dispute.amount_minor).toBe(5000);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_fee")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);

    const balance = (await db.collection("mission_financial_balance").doc(missionId).get()).data();
    expect(balance).toBeDefined();

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("IDEMPOTENCE à l'ouverture : rejouer le même provider_dispute_id ne crée pas de doublon ledger", async () => {
    const paymentId = "pay_dispute_idem_1";
    const missionId = "mission_dispute_idem_1";
    const disputeId = "dp_idem_1";
    await seedPayment(paymentId, missionId);

    const first = await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });
    expect(first.alreadyExisted).toBe(false);

    const second = await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });
    expect(second.alreadyExisted).toBe(true);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_fee")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("OPENED -> UNDER_REVIEW -> WON : payment repasse CAPTURED, ledger CHARGEBACK_WON", async () => {
    const paymentId = "pay_dispute_won_1";
    const missionId = "mission_dispute_won_1";
    const disputeId = "dp_won_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });

    await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.UNDER_REVIEW });
    const outcome = await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.WON });
    expect(outcome.status).toBe(DisputeStatuses.WON);
    expect(outcome.skipped).toBe(false);

    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.status).toBe(PaymentStatuses.CAPTURED);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_won")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("OPENED -> LOST direct : payment -> CHARGEBACK, ledger CHARGEBACK_LOST (débit)", async () => {
    const paymentId = "pay_dispute_lost_1";
    const missionId = "mission_dispute_lost_1";
    const disputeId = "dp_lost_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });

    const outcome = await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.LOST });
    expect(outcome.status).toBe(DisputeStatuses.LOST);

    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.status).toBe(PaymentStatuses.CHARGEBACK);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_lost")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);
    expect(ledgerSnap.docs[0].data().direction).toBe("debit");

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("LOST -> REVERSED (late-win) : payment -> REFUNDED, ledger CHARGEBACK_REVERSAL (crédit)", async () => {
    const paymentId = "pay_dispute_reversed_1";
    const missionId = "mission_dispute_reversed_1";
    const disputeId = "dp_reversed_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });
    await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.LOST });

    const outcome = await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.REVERSED });
    expect(outcome.status).toBe(DisputeStatuses.REVERSED);

    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.status).toBe(PaymentStatuses.REFUNDED);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_reversal")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);
    expect(ledgerSnap.docs[0].data().direction).toBe("credit");

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("refuse une transition invalide (WON -> LOST direct)", async () => {
    const paymentId = "pay_dispute_invalid_1";
    const missionId = "mission_dispute_invalid_1";
    const disputeId = "dp_invalid_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });
    await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.WON });

    await expect(transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.LOST })).rejects.toThrow();

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("self-transition idempotente : rejouer le MÊME statut => skipped=true, aucun doublon ledger", async () => {
    const paymentId = "pay_dispute_selftx_1";
    const missionId = "mission_dispute_selftx_1";
    const disputeId = "dp_selftx_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });
    await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.LOST });

    const replay = await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.LOST });
    expect(replay.skipped).toBe(true);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "chargeback_lost")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("closed_at renseigné lors du passage à un statut terminal (WON -> CLOSED)", async () => {
    const paymentId = "pay_dispute_closed_1";
    const missionId = "mission_dispute_closed_1";
    const disputeId = "dp_closed_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });
    await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.WON });
    await transitionDisputeStatus({ disputeId, newStatus: DisputeStatuses.CLOSED });

    const dispute = (await db.collection("disputes").doc(disputeId).get()).data()!;
    expect(dispute.status).toBe(DisputeStatuses.CLOSED);
    expect(dispute.closed_at).toBeTruthy();

    await cleanup([paymentId], [missionId], [disputeId]);
  });
});

describe("updateDisputeStatus — Cloud Function callable (admin uniquement)", () => {
  it("permet à un admin de faire transiter un litige", async () => {
    const paymentId = "pay_dispute_admin_1";
    const missionId = "mission_dispute_admin_1";
    const disputeId = "dp_admin_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });

    const result = await updateDisputeStatus.run(
      buildRequest<UpdateDisputeStatusRequest>(ADMIN_ID, "admin", {
        disputeId,
        newStatus: DisputeStatuses.UNDER_REVIEW,
      })
    );
    expect(result.status).toBe(DisputeStatuses.UNDER_REVIEW);

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("refuse (permission-denied) un non-admin", async () => {
    const paymentId = "pay_dispute_nonadmin_1";
    const missionId = "mission_dispute_nonadmin_1";
    const disputeId = "dp_nonadmin_1";
    await seedPayment(paymentId, missionId);
    await openDispute({ providerDisputeId: disputeId, paymentId, amountMinor: 5000, reason: "fraudulent" });

    await expect(
      updateDisputeStatus.run(
        buildRequest<UpdateDisputeStatusRequest>(CUSTOMER_ID, "customer", {
          disputeId,
          newStatus: DisputeStatuses.UNDER_REVIEW,
        })
      )
    ).rejects.toThrow();

    await cleanup([paymentId], [missionId], [disputeId]);
  });

  it("refuse (invalid-argument) un newStatus invalide", async () => {
    await expect(
      updateDisputeStatus.run(
        buildRequest<UpdateDisputeStatusRequest>(ADMIN_ID, "admin", {
          disputeId: "does_not_matter",
          newStatus: "not_a_status" as unknown as UpdateDisputeStatusRequest["newStatus"],
        })
      )
    ).rejects.toThrow();
  });
});
