// ---------------------------------------------------------------------------
// Test d'intégration — BLOC N (Phase 6, directive 38 points) : CONCURRENCE
// FINANCIÈRE. Prouve, pour chaque opération d'argent réel, qu'un doublon
// d'appel (concurrent OU rejoué) ne produit JAMAIS un second mouvement
// financier effectif — en comptant EXPLICITEMENT les appels au
// PaymentProvider via `jest.spyOn`, pas seulement en lisant l'état Firestore
// final (un état final correct pourrait masquer un appel provider en double
// suivi d'une correction silencieuse — ce test élimine cette ambiguïté).
//
// Scénarios couverts (directive utilisateur) :
//   1. Double capture concurrente (captureMissionPayment × 2, même paymentId)
//   2. Double payout concurrent (submitDriverPayout × 2, même payoutId)
//   3. Collision cron + manuel (processScheduledDriverPayouts.run() en
//      parallèle d'un submitDriverPayout() direct, même payout ELIGIBLE)
//
// Le refund concurrent (extension de refundPayment.test.ts) et le webhook
// dupliqué (extension de processStripeWebhook.test.ts) sont traités dans
// leurs fichiers respectifs, pas ici.
// ---------------------------------------------------------------------------

import { admin, db } from "../../src/lib/admin";
import {
  captureMissionPayment,
  submitDriverPayout,
} from "../../src/payment/paymentOrchestration";
import { processScheduledDriverPayouts } from "../../src/functions/processScheduledDriverPayouts";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";
import { PaymentStatuses, PayoutStatuses } from "../../src/lib/types";
import type { ScheduledEvent } from "firebase-functions/v2/scheduler";

const DRIVER_ID = "concurrency_fin_driver_001";

// -----------------------------------------------------------------------------
// Seed helpers — formes minimales conformes à PaymentDoc / DriverPayoutDoc
// (src/lib/types.ts), réutilisant les conventions déjà validées dans
// refundPayment.test.ts / reverseDriverPayout.test.ts.
// -----------------------------------------------------------------------------

async function seedAuthorizedPayment(
  paymentId: string,
  missionId: string,
  amountAuthorizedMinor: number,
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db
    .collection("payments")
    .doc(paymentId)
    .set({
      payment_id: paymentId,
      mission_id: missionId,
      customer_id: "concurrency_fin_customer_001",
      driver_id: DRIVER_ID,
      status: PaymentStatuses.AUTHORIZED,
      currency: "CAD",
      amount_authorized_minor: amountAuthorizedMinor,
      amount_captured_minor: 0,
      amount_refunded_minor: 0,
      application_fee_minor: Math.round(amountAuthorizedMinor * 0.15),
      provider: "stripe",
      provider_customer_id: "fake_cus_concurrency_fin",
      provider_payment_method_id: "fake_pm_concurrency_fin",
      provider_payment_intent_id: `fake_pi_${paymentId}`,
      provider_charge_id: null,
      connected_account_id: null,
      idempotency_key: `createPayment:${paymentId}`,
      authorized_at: now,
      created_at: now,
      updated_at: now,
    });
  // captureMissionPayment() met à jour delivery_requests/{missionId}.payment_status
  // dans la même transaction — le document mission doit exister.
  await db.collection("delivery_requests").doc(missionId).set({
    customer_id: "concurrency_fin_customer_001",
    driver_id: DRIVER_ID,
    status: "in_progress",
    payment_status: PaymentStatuses.AUTHORIZED,
    created_at: now,
  });
}

async function seedEligiblePayout(
  payoutId: string,
  amountMinor: number,
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db
    .collection("driver_payouts")
    .doc(payoutId)
    .set({
      driver_id: DRIVER_ID,
      financial_snapshot_ids: [],
      amount_minor: amountMinor,
      currency: "CAD",
      status: PayoutStatuses.ELIGIBLE,
      payout_hold_period_hours: 0,
      payout_eligible_at: now,
      provider_payout_id: null,
      connected_account_id: "fake_acct_concurrency_fin",
      created_at: now,
      scheduled_at: null,
      processing_at: null,
      paid_at: null,
      failed_at: null,
      failure_reason: null,
      reversed_at: null,
      reversal_reason: null,
      idempotency_key: `submitDriverPayout:${payoutId}`,
    });
}

async function cleanupPayment(
  paymentId: string,
  missionId: string,
): Promise<void> {
  const batch = db.batch();
  batch.delete(db.collection("payments").doc(paymentId));
  batch.delete(db.collection("delivery_requests").doc(missionId));
  batch.delete(db.collection("mission_financial_balance").doc(missionId));
  await batch.commit();
  const ledgerSnap = await db
    .collection("transaction_ledger")
    .where("mission_id", "==", missionId)
    .get();
  const batch2 = db.batch();
  ledgerSnap.docs.forEach((d) => batch2.delete(d.ref));
  await batch2.commit();
}

async function cleanupPayout(payoutId: string): Promise<void> {
  await db.collection("driver_payouts").doc(payoutId).delete();
}

function buildFakeScheduledEvent(): ScheduledEvent {
  return {
    scheduleTime: new Date().toISOString(),
    jobName: "processScheduledDriverPayouts-test",
  } as unknown as ScheduledEvent;
}

describe("BLOC N — concurrence financière : double capture / double payout / collision cron+manuel", () => {
  let fakeProvider: FakePaymentProvider;

  beforeEach(() => {
    fakeProvider = new FakePaymentProvider();
    setPaymentProviderForTesting(fakeProvider);
  });

  afterEach(() => {
    setPaymentProviderForTesting(null);
    jest.restoreAllMocks();
  });

  // ---------------------------------------------------------------------
  // SCÉNARIO 1 — DOUBLE CAPTURE
  // ---------------------------------------------------------------------
  it(
    "DOUBLE CAPTURE : deux appels concurrents à captureMissionPayment() sur le MÊME paymentId " +
      "=> exactement 1 appel provider capturePayment(), 1 capture effective, pas de double ledger",
    async () => {
      const paymentId = "pay_concurrent_capture_001";
      const missionId = "mission_concurrent_capture_001";
      await seedAuthorizedPayment(paymentId, missionId, 5000);

      const captureSpy = jest.spyOn(fakeProvider, "capturePayment");

      const results = await Promise.allSettled([
        captureMissionPayment(missionId, paymentId),
        captureMissionPayment(missionId, paymentId),
      ]);

      // 🔒 Assertion CRITIQUE #1 : le provider n'a été appelé qu'UNE SEULE
      // fois, quel que soit l'entrelacement — la garde vient de
      // `assertValidPaymentTransition(status, CAPTURE_PENDING)` : le second
      // appel qui relit AUTHORIZED->CAPTURE_PENDING échoue AVANT d'atteindre
      // l'appel provider (voir paymentOrchestration.ts:375-400, étape 1).
      expect(captureSpy).toHaveBeenCalledTimes(1);

      // L'un des deux appels doit avoir échoué avec InvalidPaymentTransitionError
      // (transition refusée par la state machine, pas un crash arbitraire).
      const rejected = results.filter(
        (r) => r.status === "rejected",
      ) as PromiseRejectedResult[];
      const fulfilled = results.filter((r) => r.status === "fulfilled");
      expect(rejected.length).toBe(1);
      expect(fulfilled.length).toBe(1);
      expect(String(rejected[0].reason)).toMatch(
        /Transition de paiement invalide/,
      );

      // État final : capturé UNE fois, montant exact, aucun double mouvement.
      const paymentDoc = (
        await db.collection("payments").doc(paymentId).get()
      ).data()!;
      expect(paymentDoc.status).toBe(PaymentStatuses.CAPTURED);
      expect(paymentDoc.amount_captured_minor).toBe(5000);

      // Aucune écriture ledger de capture en double (captureMissionPayment
      // n'écrit pas lui-même de transaction_ledger — vérifie simplement
      // qu'aucune entrée parasite n'a été créée par un double passage).
      const ledgerSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .get();
      expect(ledgerSnap.docs.length).toBe(0);

      const missionDoc = (
        await db.collection("delivery_requests").doc(missionId).get()
      ).data()!;
      expect(missionDoc.payment_status).toBe(PaymentStatuses.CAPTURED);

      await cleanupPayment(paymentId, missionId);
    },
  );

  // ---------------------------------------------------------------------
  // SCÉNARIO 2 — DOUBLE PAYOUT
  // ---------------------------------------------------------------------
  it(
    "DOUBLE PAYOUT : deux appels concurrents à submitDriverPayout() sur le MÊME payoutId " +
      "=> exactement 1 appel provider createDriverPayout(), 1 versement effectif",
    async () => {
      const payoutId = "payout_concurrent_001";
      await seedEligiblePayout(payoutId, 3000);

      const payoutSpy = jest.spyOn(fakeProvider, "createDriverPayout");

      const results = await Promise.allSettled([
        submitDriverPayout(payoutId),
        submitDriverPayout(payoutId),
      ]);

      // 🔒 Assertion CRITIQUE #2 : un seul appel provider — la garde vient de
      // `assertValidPayoutTransition(status, SCHEDULED)` puis
      // `assertValidPayoutTransition(SCHEDULED, PROCESSING)` (étape 1 de
      // submitDriverPayout, paymentOrchestration.ts:498-545) : le second
      // appel qui relit un statut déjà PROCESSING échoue avant l'appel réseau.
      expect(payoutSpy).toHaveBeenCalledTimes(1);

      const rejected = results.filter(
        (r) => r.status === "rejected",
      ) as PromiseRejectedResult[];
      const fulfilled = results.filter(
        (r) => r.status === "fulfilled",
      ) as PromiseFulfilledResult<
        Awaited<ReturnType<typeof submitDriverPayout>>
      >[];

      // Le "perdant" échoue soit par rejet direct (InvalidPayoutTransitionError
      // si la garde intercepte la relecture avant l'appel provider), soit en
      // résolvant avec success:false si sa propre transaction d'étape 1
      // s'est exécutée AVANT que le gagnant ne passe en PROCESSING (dans ce
      // cas la garde intercepte quand même le second à l'étape suivante).
      // Dans tous les cas : au plus 1 appel provider, jamais 2.
      expect(rejected.length + fulfilled.length).toBe(2);
      if (rejected.length > 0) {
        expect(String(rejected[0].reason)).toMatch(
          /Transition de versement invalide/,
        );
      }

      const payoutDoc = (
        await db.collection("driver_payouts").doc(payoutId).get()
      ).data()!;
      expect(payoutDoc.status).toBe(PayoutStatuses.PAID);
      expect(payoutDoc.provider_payout_id).toBeTruthy();

      // Pas de double ledger : submitDriverPayout() lui-même n'écrit pas de
      // transaction_ledger (c'est calculateDriverPayout.ts qui le fait en
      // amont, lors de la création du payout, hors scope de ce test) —
      // vérifie l'absence d'écriture PARASITE dans audit_logs "payout_submitted".
      const auditSnap = await db
        .collection("audit_logs")
        .where("target_id", "==", payoutId)
        .where("action", "==", "payout_submitted")
        .get();
      expect(auditSnap.size).toBe(1);

      await cleanupPayout(payoutId);
      await db
        .collection("audit_logs")
        .where("target_id", "==", payoutId)
        .get()
        .then((s) => {
          const batch = db.batch();
          s.docs.forEach((d) => batch.delete(d.ref));
          return batch.commit();
        });
    },
  );

  // ---------------------------------------------------------------------
  // SCÉNARIO 3 — COLLISION CRON + MANUEL
  // ---------------------------------------------------------------------
  it(
    "COLLISION CRON + MANUEL : processScheduledDriverPayouts.run() concurrent à un submitDriverPayout() " +
      "direct sur le MÊME payout ELIGIBLE => exactement 1 appel provider createDriverPayout()",
    async () => {
      const payoutId = "payout_cron_collision_001";
      await seedEligiblePayout(payoutId, 4200);

      const payoutSpy = jest.spyOn(fakeProvider, "createDriverPayout");

      // Le cron (Step A) promeut PENDING/HELD->ELIGIBLE puis (Step B) appelle
      // submitDriverPayout() pour CHAQUE payout ELIGIBLE trouvé — notre seed
      // est déjà ELIGIBLE, donc il sera repris par le cron ET par l'appel
      // manuel direct, en parallèle réel autant que le harness le permet.
      const results = await Promise.allSettled([
        (
          processScheduledDriverPayouts as unknown as {
            run: (e: ScheduledEvent) => Promise<void>;
          }
        ).run(buildFakeScheduledEvent()),
        submitDriverPayout(payoutId),
      ]);

      // 🔒 Assertion CRITIQUE #3 : peu importe lequel des deux chemins
      // "gagne" la transaction ELIGIBLE->SCHEDULED->PROCESSING, un seul
      // appel réseau au provider doit avoir eu lieu.
      expect(payoutSpy).toHaveBeenCalledTimes(1);

      // Le cron lui-même catch ses propres erreurs par-payout (Promise.all
      // avec try/catch interne) donc il ne rejette jamais globalement ; seul
      // l'appel manuel direct peut être rejected si le cron a gagné.
      const cronResult = results[0];
      const manualResult = results[1];
      expect(cronResult.status).toBe("fulfilled");
      // Le manuel peut être fulfilled (il a gagné) ou rejected (le cron a
      // gagné) — dans les deux cas, un seul appel provider est acceptable.
      expect(["fulfilled", "rejected"]).toContain(manualResult.status);

      const payoutDoc = (
        await db.collection("driver_payouts").doc(payoutId).get()
      ).data()!;
      expect(payoutDoc.status).toBe(PayoutStatuses.PAID);
      expect(payoutDoc.provider_payout_id).toBeTruthy();

      // Un seul audit "payout_submitted" pour ce payout, malgré les 2 chemins
      // d'entrée concurrents.
      const auditSnap = await db
        .collection("audit_logs")
        .where("target_id", "==", payoutId)
        .where("action", "==", "payout_submitted")
        .get();
      expect(auditSnap.size).toBe(1);

      await cleanupPayout(payoutId);
      const auditCleanup = await db
        .collection("audit_logs")
        .where("target_id", "==", payoutId)
        .get();
      const batch = db.batch();
      auditCleanup.docs.forEach((d) => batch.delete(d.ref));
      await batch.commit();
    },
  );
});
