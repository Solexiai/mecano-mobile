// ---------------------------------------------------------------------------
// Test d'intégration — refundPayment (Phase 6, directive 38 points, points
// 1 à 6).
//
// Couvre :
//   - remboursement complet
//   - remboursement partiel
//   - plusieurs remboursements partiels successifs (cumul jusqu'à la limite
//     du montant capturé)
//   - refus au-delà du montant capturé
//   - cents entiers stricts (pas de flottant)
//   - idempotence (même requestKey => résultat déjà obtenu, jamais de
//     second appel provider)
//   - deux refunds simultanés avec la MÊME requestKey (concurrence) =>
//     exactement un remboursement effectif
//   - refund AVANT payout (aucun payout PAID lié => is_post_payout=false,
//     ledger source_event="refund_before_payout")
//   - refund APRÈS payout (payout PAID déjà lié via financial_snapshot =>
//     is_post_payout=true, related_payout_id renseigné, payout historique
//     JAMAIS modifié, ledger source_event="refund_after_payout")
//   - paiement non capturable (jamais authorized/captured)
//   - paiement introuvable
//   - utilisateur non autorisé (ni client propriétaire, ni admin)
//   - échec côté provider (FakePaymentProvider forceRefundFailure)
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { refundPayment, RefundPaymentRequest } from "../../src/functions/refundPayment";
import { admin, db } from "../../src/lib/admin";
import { PaymentStatuses, RefundReasons, RefundStatuses } from "../../src/lib/types";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";

const CUSTOMER_ID = "refund_customer_001";
const OTHER_CUSTOMER_ID = "refund_customer_stranger";
const DRIVER_ID = "refund_driver_001";
const ADMIN_ID = "refund_admin_001";
const MISSION_ID = "refund_mission_001";

function buildRequest<T>(uid: string, role: string, data: T): CallableRequest<T> {
  return {
    data,
    auth: {
      uid,
      token: { role } as unknown as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedPayment(
  paymentId: string,
  opts: {
    amountCapturedMinor: number;
    amountRefundedMinor?: number;
    status?: string;
    connectedAccountId?: string | null;
    providerPaymentIntentId?: string | null;
    missionId?: string;
  }
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("payments").doc(paymentId).set({
    payment_id: paymentId,
    mission_id: opts.missionId ?? MISSION_ID,
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: opts.status ?? PaymentStatuses.CAPTURED,
    currency: "CAD",
    amount_authorized_minor: opts.amountCapturedMinor,
    amount_captured_minor: opts.amountCapturedMinor,
    amount_refunded_minor: opts.amountRefundedMinor ?? 0,
    application_fee_minor: Math.round(opts.amountCapturedMinor * 0.15),
    provider: "stripe",
    provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
    provider_payment_method_id: `fake_pm_${CUSTOMER_ID}`,
    provider_payment_intent_id:
      opts.providerPaymentIntentId !== undefined ? opts.providerPaymentIntentId : `fake_pi_${paymentId}`,
    provider_charge_id: `fake_ch_${paymentId}`,
    connected_account_id: opts.connectedAccountId ?? null,
    idempotency_key: `createPayment:${paymentId}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
  });
}

async function seedFinancialSnapshot(id: string, missionId: string, driverId: string): Promise<void> {
  await db.collection("financial_snapshots").doc(id).set({
    snapshot_id: id,
    mission_id: missionId,
    driver_id: driverId,
    status: "confirmed",
    driver_net_mission_earnings: 20,
    included_in_payout_id: null,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function seedPaidPayout(id: string, driverId: string, snapshotIds: string[]): Promise<void> {
  await db.collection("driver_payouts").doc(id).set({
    driver_id: driverId,
    financial_snapshot_ids: snapshotIds,
    amount_minor: 2000,
    currency: "CAD",
    status: "paid",
    payout_hold_period_hours: 0,
    payout_eligible_at: admin.firestore.Timestamp.now(),
    provider_payout_id: "fake_po_seeded",
    connected_account_id: "fake_acct_seeded",
    created_at: admin.firestore.Timestamp.now(),
    paid_at: admin.firestore.Timestamp.now(),
    idempotency_key: `submitDriverPayout:${id}`,
  });
}

async function cleanupAll(paymentIds: string[], missionIds: string[]): Promise<void> {
  const batch = db.batch();
  for (const pid of paymentIds) {
    batch.delete(db.collection("payments").doc(pid));
  }
  const refundsSnap = await db
    .collection("refunds")
    .where("payment_id", "in", paymentIds.length > 0 ? paymentIds.slice(0, 10) : ["__none__"])
    .get();
  refundsSnap.docs.forEach((d) => batch.delete(d.ref));

  for (const mid of missionIds) {
    const ledgerSnap = await db.collection("transaction_ledger").where("mission_id", "==", mid).get();
    ledgerSnap.docs.forEach((d) => batch.delete(d.ref));
    const balanceRef = db.collection("mission_financial_balance").doc(mid);
    batch.delete(balanceRef);
    const snapshotsSnap = await db.collection("financial_snapshots").where("mission_id", "==", mid).get();
    snapshotsSnap.docs.forEach((d) => batch.delete(d.ref));
  }

  const payoutsSnap = await db.collection("driver_payouts").where("driver_id", "==", DRIVER_ID).get();
  payoutsSnap.docs.forEach((d) => batch.delete(d.ref));

  await batch.commit();
}

describe("refundPayment — remboursement réel, complet/partiel, avant/après payout", () => {
  // 🔒 BLOC N — référence conservée à l'instance injectée pour permettre
  // `jest.spyOn(currentFakeProvider, 'refundPayment')` dans le test de
  // concurrence ci-dessous, SANS changer le comportement des autres tests
  // de ce describe (chacun continue de recevoir une instance fraîche).
  let currentFakeProvider: FakePaymentProvider;

  beforeEach(async () => {
    currentFakeProvider = new FakePaymentProvider();
    setPaymentProviderForTesting(currentFakeProvider);
  });

  afterEach(async () => {
    setPaymentProviderForTesting(null);
  });

  it("remboursement COMPLET : payment -> REFUNDED, refund SUCCEEDED, ledger REFUND, cents entiers", async () => {
    const paymentId = "pay_full_refund_1";
    const missionId = "mission_full_refund_1";
    await seedPayment(paymentId, { amountCapturedMinor: 5000, missionId });

    const result = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        reason: RefundReasons.CUSTOMER_REQUEST,
        clientRequestId: "click_full_1",
      })
    );

    expect(result.success).toBe(true);
    expect(result.status).toBe(RefundStatuses.SUCCEEDED);
    expect(Number.isInteger((result as { amountMinor?: number }).amountMinor ?? 5000)).toBe(true);

    const paySnap = await db.collection("payments").doc(paymentId).get();
    const payment = paySnap.data()!;
    expect(payment.status).toBe(PaymentStatuses.REFUNDED);
    expect(payment.amount_refunded_minor).toBe(5000);

    const refundSnap = await db.collection("refunds").doc(result.refundId).get();
    const refund = refundSnap.data()!;
    expect(refund.status).toBe(RefundStatuses.SUCCEEDED);
    expect(refund.amount_minor).toBe(5000);
    expect(Number.isInteger(refund.amount_minor)).toBe(true);
    expect(refund.is_post_payout).toBe(false);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "refund")
      .get();
    expect(ledgerSnap.docs.length).toBe(1);
    expect(ledgerSnap.docs[0].data().amount_minor).toBe(5000);
    expect(ledgerSnap.docs[0].data().source_event).toBe("refund_before_payout");

    await cleanupAll([paymentId], [missionId]);
  });

  it("remboursement PARTIEL : payment -> PARTIALLY_REFUNDED, montant exact conservé", async () => {
    const paymentId = "pay_partial_refund_1";
    const missionId = "mission_partial_refund_1";
    await seedPayment(paymentId, { amountCapturedMinor: 10000, missionId });

    const result = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        amountMinor: 3000,
        reason: RefundReasons.GOODWILL,
        clientRequestId: "click_partial_1",
      })
    );

    expect(result.success).toBe(true);
    const paySnap = await db.collection("payments").doc(paymentId).get();
    const payment = paySnap.data()!;
    expect(payment.status).toBe(PaymentStatuses.PARTIALLY_REFUNDED);
    expect(payment.amount_refunded_minor).toBe(3000);

    await cleanupAll([paymentId], [missionId]);
  });

  it("PLUSIEURS remboursements partiels successifs : cumul correct jusqu'à la limite du capturé", async () => {
    const paymentId = "pay_multi_partial_1";
    const missionId = "mission_multi_partial_1";
    await seedPayment(paymentId, { amountCapturedMinor: 10000, missionId });

    const r1 = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        amountMinor: 4000,
        reason: RefundReasons.PARTIAL_DELIVERY,
        clientRequestId: "multi_1",
      })
    );
    expect(r1.success).toBe(true);

    const r2 = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        amountMinor: 3500,
        reason: RefundReasons.PARTIAL_DELIVERY,
        clientRequestId: "multi_2",
      })
    );
    expect(r2.success).toBe(true);

    let payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.amount_refunded_minor).toBe(7500);
    expect(payment.status).toBe(PaymentStatuses.PARTIALLY_REFUNDED);

    // Le 3e remboursement pousse EXACTEMENT au montant capturé => REFUNDED.
    const r3 = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        amountMinor: 2500,
        reason: RefundReasons.PARTIAL_DELIVERY,
        clientRequestId: "multi_3",
      })
    );
    expect(r3.success).toBe(true);
    payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.amount_refunded_minor).toBe(10000);
    expect(payment.status).toBe(PaymentStatuses.REFUNDED);

    // Un 4e remboursement (même 1 cent) doit être refusé : plus rien de
    // remboursable.
    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 1,
          reason: RefundReasons.PARTIAL_DELIVERY,
          clientRequestId: "multi_4",
        })
      )
    ).rejects.toThrow();

    await cleanupAll([paymentId], [missionId]);
  });

  it("refuse un remboursement dont le montant dépasse le solde restant remboursable", async () => {
    const paymentId = "pay_exceeds_1";
    const missionId = "mission_exceeds_1";
    await seedPayment(paymentId, { amountCapturedMinor: 5000, missionId });

    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 5001,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "exceeds_1",
        })
      )
    ).rejects.toThrow();

    await cleanupAll([paymentId], [missionId]);
  });

  it("IDEMPOTENCE : même requestKey rejouée => renvoie le résultat déjà obtenu, jamais un second RefundDoc", async () => {
    const paymentId = "pay_idempotent_1";
    const missionId = "mission_idempotent_1";
    await seedPayment(paymentId, { amountCapturedMinor: 5000, missionId });

    const req = buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
      paymentId,
      amountMinor: 2000,
      reason: RefundReasons.CUSTOMER_REQUEST,
      clientRequestId: "idem_click_1",
    });

    const first = await refundPayment.run(req);
    expect(first.success).toBe(true);
    expect(first.alreadyProcessed).toBeFalsy();

    const second = await refundPayment.run(req);
    expect(second.success).toBe(true);
    expect(second.alreadyProcessed).toBe(true);
    expect(second.refundId).toBe(first.refundId);

    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    // Un SEUL remboursement de 2000 appliqué, pas deux.
    expect(payment.amount_refunded_minor).toBe(2000);

    const refundsSnap = await db.collection("refunds").where("payment_id", "==", paymentId).get();
    expect(refundsSnap.docs.length).toBe(1);

    await cleanupAll([paymentId], [missionId]);
  });

  it("CONCURRENCE : deux appels simultanés avec la MÊME requestKey => un seul remboursement effectif", async () => {
    const paymentId = "pay_concurrent_1";
    const missionId = "mission_concurrent_1";
    await seedPayment(paymentId, { amountCapturedMinor: 5000, missionId });

    // 🔒 BLOC N — instrumentation EXPLICITE du comptage d'appels provider
    // (directive utilisateur : ne pas se contenter de l'état Firestore
    // final, qui pourrait masquer un doublon d'appel réseau corrigé après
    // coup). `refundPayment()` appelle `provider.refundPayment()` HORS
    // transaction (étape 2, voir paymentOrchestration.ts) : si la garde
    // `refunds/{requestKey}` en étape 1 laissait passer les deux branches,
    // ce spy le révélerait immédiatement (2 appels au lieu de 1).
    const refundSpy = jest.spyOn(currentFakeProvider, "refundPayment");

    const req = buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
      paymentId,
      amountMinor: 2000,
      reason: RefundReasons.CUSTOMER_REQUEST,
      clientRequestId: "concurrent_click_1",
    });

    const results = await Promise.allSettled([refundPayment.run(req), refundPayment.run(req)]);

    // Au moins un des deux doit réussir (ou renvoyer already_processed) ;
    // l'autre peut soit réussir avec alreadyProcessed=true, soit lever
    // REFUND_ALREADY_IN_PROGRESS (aborted) si vraiment simultané.
    const fulfilled = results.filter((r) => r.status === "fulfilled") as PromiseFulfilledResult<
      Awaited<ReturnType<typeof refundPayment.run>>
    >[];
    expect(fulfilled.length).toBeGreaterThanOrEqual(1);

    // 🔒 Assertion CRITIQUE (point 4, comptage EXPLICITE d'appel provider) :
    // quel que soit l'entrelacement exact des deux appels concurrents, le
    // provider (Stripe réel en production, FakePaymentProvider ici) n'est
    // JAMAIS appelé plus d'une fois pour la MÊME requestKey — la garde
    // `refunds/{requestKey}` (doc déterministe lu DANS la transaction
    // Firestore, voir paymentOrchestration.ts:887-955) empêche le second
    // appel concurrent d'atteindre l'étape 2 (appel réseau HORS transaction).
    expect(refundSpy).toHaveBeenCalledTimes(1);

    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    // 🔒 Assertion CRITIQUE (point 4) : quel que soit l'entrelacement exact,
    // JAMAIS plus de 2000 cents remboursés pour cette même requestKey.
    expect(payment.amount_refunded_minor).toBe(2000);
    // Aucun dépassement du montant capturé (5000) même en cas de double
    // tentative — la somme remboursée reste strictement le montant demandé.
    expect(payment.amount_refunded_minor).toBeLessThanOrEqual(payment.amount_captured_minor);

    const refundsSnap = await db.collection("refunds").where("payment_id", "==", paymentId).get();
    // Un seul RefundDoc créé (clé déterministe requestKey) — aucun double
    // ledger compensatoire possible puisqu'un seul refund existe.
    expect(refundsSnap.docs.length).toBe(1);
    expect(refundsSnap.docs[0].data().status).toBe(RefundStatuses.SUCCEEDED);

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "partial_refund")
      .get();
    // Une seule écriture ledger compensatoire, jamais deux, malgré la
    // concurrence.
    expect(ledgerSnap.docs.length).toBe(1);

    await cleanupAll([paymentId], [missionId]);
  });

  it("refund AVANT payout : is_post_payout=false, related_payout_id=null, source_event=refund_before_payout", async () => {
    const paymentId = "pay_before_payout_1";
    const missionId = "mission_before_payout_1";
    await seedPayment(paymentId, { amountCapturedMinor: 4000, missionId });
    // Pas de financial_snapshot ni de driver_payouts liés => pas de payout.

    const result = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        amountMinor: 1000,
        reason: RefundReasons.GOODWILL,
        clientRequestId: "before_payout_1",
      })
    );
    expect(result.success).toBe(true);

    const refund = (await db.collection("refunds").doc(result.refundId).get()).data()!;
    expect(refund.is_post_payout).toBe(false);
    expect(refund.related_payout_id).toBeNull();

    const ledgerSnap = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", missionId)
      .where("type", "==", "partial_refund")
      .get();
    expect(ledgerSnap.docs[0].data().source_event).toBe("refund_before_payout");

    await cleanupAll([paymentId], [missionId]);
  });

  it(
    "refund APRÈS payout : is_post_payout=true, related_payout_id renseigné, le PAYOUT HISTORIQUE " +
      "n'est JAMAIS modifié, source_event=refund_after_payout",
    async () => {
      const paymentId = "pay_after_payout_1";
      const missionId = "mission_after_payout_1";
      const snapshotId = "snap_after_payout_1";
      const payoutId = "payout_after_payout_1";

      await seedPayment(paymentId, { amountCapturedMinor: 4000, missionId });
      await seedFinancialSnapshot(snapshotId, missionId, DRIVER_ID);
      await seedPaidPayout(payoutId, DRIVER_ID, [snapshotId]);

      const payoutBefore = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;

      const result = await refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 1500,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "after_payout_1",
        })
      );
      expect(result.success).toBe(true);

      const refund = (await db.collection("refunds").doc(result.refundId).get()).data()!;
      expect(refund.is_post_payout).toBe(true);
      expect(refund.related_payout_id).toBe(payoutId);

      // 🔒 Assertion CRITIQUE (point 6) : le document driver_payouts
      // historique n'est touché EN AUCUN CHAMP.
      const payoutAfter = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutAfter).toEqual(payoutBefore);

      const ledgerSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", "partial_refund")
        .get();
      expect(ledgerSnap.docs[0].data().source_event).toBe("refund_after_payout");
      expect(ledgerSnap.docs[0].data().reference_id).toBe(payoutId);

      // mission_financial_balance doit être recalculé et refléter le
      // remboursement (même si le payout historique n'a pas bougé).
      const balanceSnap = await db.collection("mission_financial_balance").doc(missionId).get();
      expect(balanceSnap.exists).toBe(true);
      expect(balanceSnap.data()!.customer_refunded_minor).toBe(1500);

      await cleanupAll([paymentId], [missionId]);
    }
  );

  it("refuse (failed-precondition) un remboursement sur un paiement jamais capturé", async () => {
    const paymentId = "pay_not_captured_1";
    const missionId = "mission_not_captured_1";
    await seedPayment(paymentId, {
      amountCapturedMinor: 0,
      status: PaymentStatuses.AUTHORIZED,
      missionId,
    });

    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 100,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "not_captured_1",
        })
      )
    ).rejects.toThrow();

    await cleanupAll([paymentId], [missionId]);
  });

  it("refuse (not-found) si le paiement n'existe pas", async () => {
    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId: "pay_does_not_exist_xyz",
          amountMinor: 100,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "missing_payment_1",
        })
      )
    ).rejects.toThrow();
  });

  it("refuse (permission-denied) si l'appelant n'est ni le client propriétaire ni un admin", async () => {
    const paymentId = "pay_unauthorized_1";
    const missionId = "mission_unauthorized_1";
    await seedPayment(paymentId, { amountCapturedMinor: 3000, missionId });

    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(OTHER_CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 100,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "unauthorized_1",
        })
      )
    ).rejects.toThrow();

    await cleanupAll([paymentId], [missionId]);
  });

  it("autorise un ADMIN à rembourser le paiement d'un autre client (remboursement administratif)", async () => {
    const paymentId = "pay_admin_initiated_1";
    const missionId = "mission_admin_initiated_1";
    await seedPayment(paymentId, { amountCapturedMinor: 3000, missionId });

    const result = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(ADMIN_ID, "admin", {
        paymentId,
        amountMinor: 1000,
        reason: RefundReasons.ADMINISTRATIVE,
        clientRequestId: "admin_initiated_1",
      })
    );
    expect(result.success).toBe(true);

    const refund = (await db.collection("refunds").doc(result.refundId).get()).data()!;
    expect(refund.is_admin_initiated).toBe(true);
    expect(refund.initiated_by_user_id).toBe(ADMIN_ID);

    await cleanupAll([paymentId], [missionId]);
  });

  it("échec provider (FakePaymentProvider forceRefundFailure) : refund FAILED, payment INCHANGÉ", async () => {
    setPaymentProviderForTesting(new FakePaymentProvider({ forceRefundFailure: true }));
    const paymentId = "pay_provider_failure_1";
    const missionId = "mission_provider_failure_1";
    await seedPayment(paymentId, { amountCapturedMinor: 3000, missionId });

    const result = await refundPayment.run(
      buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId,
        amountMinor: 1000,
        reason: RefundReasons.CUSTOMER_REQUEST,
        clientRequestId: "provider_failure_1",
      })
    );
    expect(result.success).toBe(false);
    expect(result.status).toBe(RefundStatuses.FAILED);

    const refund = (await db.collection("refunds").doc(result.refundId).get()).data()!;
    expect(refund.status).toBe(RefundStatuses.FAILED);

    // Le paiement ne doit PAS avoir été modifié (aucun montant remboursé
    // appliqué en cas d'échec provider).
    const payment = (await db.collection("payments").doc(paymentId).get()).data()!;
    expect(payment.amount_refunded_minor).toBe(0);
    expect(payment.status).toBe(PaymentStatuses.CAPTURED);

    await cleanupAll([paymentId], [missionId]);
  });

  it("refuse (invalid-argument) un reason invalide", async () => {
    const paymentId = "pay_invalid_reason_1";
    const missionId = "mission_invalid_reason_1";
    await seedPayment(paymentId, { amountCapturedMinor: 3000, missionId });

    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 100,
          reason: "not_a_valid_reason" as unknown as RefundPaymentRequest["reason"],
          clientRequestId: "invalid_reason_1",
        })
      )
    ).rejects.toThrow();

    await cleanupAll([paymentId], [missionId]);
  });

  it("refuse (invalid-argument) un amountMinor non entier ou négatif", async () => {
    const paymentId = "pay_invalid_amount_1";
    const missionId = "mission_invalid_amount_1";
    await seedPayment(paymentId, { amountCapturedMinor: 3000, missionId });

    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: 10.5,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "invalid_amount_1",
        })
      )
    ).rejects.toThrow();

    await expect(
      refundPayment.run(
        buildRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId,
          amountMinor: -100,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: "invalid_amount_2",
        })
      )
    ).rejects.toThrow();

    await cleanupAll([paymentId], [missionId]);
  });
});
