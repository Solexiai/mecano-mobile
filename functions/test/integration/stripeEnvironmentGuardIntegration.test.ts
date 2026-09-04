// ---------------------------------------------------------------------------
// Test d'intégration — Phase 8B (item 4, "TERMINER PR #17 — DERNIÈRE PASSE") :
// GARDE-FOU D'ISOLATION D'ENVIRONNEMENT sur les 4 opérations financières
// (`captureMissionPayment`, `cancelMissionPaymentAuthorization`,
// `submitDriverPayout`, `refundPayment`) + le trigger qui délègue à la
// 2e d'entre elles (`onMissionEndedClearTracking`).
//
// OBJECTIF (directive utilisateur, item 4) : pour chacune de ces 5
// opérations, prouver par un scénario TEST/LIVE volontairement incohérent
// (référence stockée `stripe_environment` d'un mode, provider ACTIF de
// l'AUTRE mode) que :
//   (a) AUCUN appel externe Stripe n'est jamais effectué (assertion
//       CRITIQUE — comptage explicite via `jest.spyOn` sur les méthodes du
//       provider FAKE actif, jamais une simple lecture d'état final qui
//       pourrait masquer un appel suivi d'une correction silencieuse) ;
//   (b) la transition d'état Firestore appliquée est EXACTEMENT celle déjà
//       documentée pour cette opération (voir paymentOrchestration.ts,
//       commentaires "Phase 8B (item f)") — jamais un nouveau chemin
//       d'erreur inventé pour ce test.
//
// `FakeLivePaymentProvider` (test/testUtils/fakePaymentProvider.ts) simule
// un provider actif en environnement "live" — `FakePaymentProvider` reste
// toujours "test". Chaque scénario ci-dessous construit délibérément
// l'incohérence dans LES DEUX SENS (référence "live" réutilisée par un
// provider "test" actif, ET référence "test" réutilisée par un provider
// "live" actif) au moins une fois sur l'ensemble du fichier, conformément à
// la matrice de vérité déjà couverte unitairement par
// test/unit/stripeEnvironment.test.ts (item 1) — ce fichier ne re-teste PAS
// cette matrice, il prouve son EFFET DE BOUT EN BOUT sur les 5 opérations.
// ---------------------------------------------------------------------------

import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { admin, db } from "../../src/lib/admin";
import {
  captureMissionPayment,
  cancelMissionPaymentAuthorization,
  submitDriverPayout,
  refundPayment,
} from "../../src/payment/paymentOrchestration";
import { onMissionEndedClearTracking } from "../../src/functions/onMissionEndedClearTracking";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, FakeLivePaymentProvider } from "../testUtils/fakePaymentProvider";
import { PaymentStatuses, PayoutStatuses, RefundReasons, RefundStatuses } from "../../src/lib/types";
import { STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE } from "../../src/lib/stripeEnvironment";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

const CUSTOMER_ID = "env_guard_customer_001";
const DRIVER_ID = "env_guard_driver_001";

// -----------------------------------------------------------------------------
// Seed helpers — mêmes conventions déjà validées (financialConcurrency.test.ts,
// refundPayment.test.ts, submitDriverPayoutFailure.test.ts), avec un
// `stripeEnvironment` explicite injecté sur le champ `stripe_environment`.
// -----------------------------------------------------------------------------

async function seedAuthorizedPayment(
  paymentId: string,
  missionId: string,
  amountAuthorizedMinor: number,
  storedEnvironment: "test" | "live" | null
): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db
    .collection("payments")
    .doc(paymentId)
    .set({
      payment_id: paymentId,
      mission_id: missionId,
      customer_id: CUSTOMER_ID,
      driver_id: DRIVER_ID,
      status: PaymentStatuses.AUTHORIZED,
      currency: "CAD",
      amount_authorized_minor: amountAuthorizedMinor,
      amount_captured_minor: 0,
      amount_refunded_minor: 0,
      application_fee_minor: Math.round(amountAuthorizedMinor * 0.15),
      provider: "stripe",
      provider_customer_id: "fake_cus_env_guard",
      provider_payment_method_id: "fake_pm_env_guard",
      provider_payment_intent_id: `fake_pi_${paymentId}`,
      provider_charge_id: null,
      connected_account_id: null,
      idempotency_key: `createPayment:${paymentId}`,
      authorized_at: now,
      created_at: now,
      updated_at: now,
      ...(storedEnvironment ? { stripe_environment: storedEnvironment } : {}),
    });
  await db.collection("delivery_requests").doc(missionId).set({
    customer_id: CUSTOMER_ID,
    driver_id: DRIVER_ID,
    status: "in_progress",
    payment_status: PaymentStatuses.AUTHORIZED,
    active_payment_id: paymentId,
    created_at: now,
  });
}

async function seedCapturedPayment(
  paymentId: string,
  missionId: string,
  amountCapturedMinor: number,
  storedEnvironment: "test" | "live" | null
): Promise<void> {
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
    provider_customer_id: "fake_cus_env_guard",
    provider_payment_method_id: "fake_pm_env_guard",
    provider_payment_intent_id: `fake_pi_${paymentId}`,
    provider_charge_id: `fake_ch_${paymentId}`,
    connected_account_id: null,
    idempotency_key: `createPayment:${paymentId}`,
    captured_at: now,
    created_at: now,
    updated_at: now,
    ...(storedEnvironment ? { stripe_environment: storedEnvironment } : {}),
  });
}

async function seedEligiblePayout(
  payoutId: string,
  amountMinor: number,
  storedEnvironment: "test" | "live" | null
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
      connected_account_id: "fake_acct_env_guard",
      created_at: now,
      scheduled_at: null,
      processing_at: null,
      paid_at: null,
      failed_at: null,
      failure_reason: null,
      reversed_at: null,
      reversal_reason: null,
      idempotency_key: `submitDriverPayout:${payoutId}`,
      ...(storedEnvironment ? { stripe_environment: storedEnvironment } : {}),
    });
}

async function cleanupPayment(paymentId: string, missionId: string): Promise<void> {
  const batch = db.batch();
  batch.delete(db.collection("payments").doc(paymentId));
  batch.delete(db.collection("delivery_requests").doc(missionId));
  batch.delete(db.collection("mission_financial_balance").doc(missionId));
  await batch.commit();
}

async function cleanupPayout(payoutId: string): Promise<void> {
  await db.collection("driver_payouts").doc(payoutId).delete();
}

async function cleanupRefunds(paymentId: string): Promise<void> {
  const snap = await db.collection("refunds").where("payment_id", "==", paymentId).get();
  const batch = db.batch();
  snap.docs.forEach((d) => batch.delete(d.ref));
  await batch.commit();
}

function fakeSnap(data: Record<string, unknown> | undefined): QueryDocumentSnapshot {
  return { data: () => data } as unknown as QueryDocumentSnapshot;
}

function buildMissionEndedEvent(
  missionId: string,
  before: Record<string, unknown> | undefined,
  after: Record<string, unknown> | undefined
): FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }> {
  return {
    data: { before: fakeSnap(before), after: fakeSnap(after) } as unknown as Change<QueryDocumentSnapshot>,
    params: { missionId },
  } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, { missionId: string }>;
}

beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

afterEach(() => {
  setPaymentProviderForTesting(null);
  jest.restoreAllMocks();
});

describe("Phase 8B item 4 — garde-fou d'isolation d'environnement : intégration sur les 5 opérations", () => {
  // -------------------------------------------------------------------------
  // 1. captureMissionPayment — référence "live" réutilisée par un provider
  //    "test" actif => AUCUN appel provider.capturePayment(), paiement FAILED.
  // -------------------------------------------------------------------------
  it(
    "captureMissionPayment : payment stripe_environment=\"live\" + provider actif \"test\" " +
      "=> AUCUN appel capturePayment(), payment FAILED avec failure_code=stripe_environment_mismatch",
    async () => {
      const fakeProvider = new FakePaymentProvider(); // environment: "test"
      setPaymentProviderForTesting(fakeProvider);
      const captureSpy = jest.spyOn(fakeProvider, "capturePayment");

      const paymentId = "pay_env_guard_capture_001";
      const missionId = "mission_env_guard_capture_001";
      await seedAuthorizedPayment(paymentId, missionId, 5000, "live");

      const result = await captureMissionPayment(missionId, paymentId);

      expect(captureSpy).not.toHaveBeenCalled();
      expect(result.success).toBe(false);
      expect(result.status).toBe(PaymentStatuses.FAILED);

      const paymentDoc = (await db.collection("payments").doc(paymentId).get()).data()!;
      expect(paymentDoc.status).toBe(PaymentStatuses.FAILED);
      expect(paymentDoc.failure_code).toBe(STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE);
      expect(paymentDoc.amount_captured_minor).toBe(0); // aucun montant capturé
      expect(paymentDoc.provider_charge_id).toBeNull();

      const missionDoc = (await db.collection("delivery_requests").doc(missionId).get()).data()!;
      expect(missionDoc.payment_status).toBe(PaymentStatuses.FAILED);

      await cleanupPayment(paymentId, missionId);
    }
  );

  // -------------------------------------------------------------------------
  // 2. cancelMissionPaymentAuthorization — référence "test" réutilisée par
  //    un provider "live" actif (sens INVERSE du scénario 1) => AUCUN appel
  //    provider.cancelAuthorization(), retour d'échec générique SANS
  //    transition forcée de payments/{id}.status (reste AUTHORIZED).
  // -------------------------------------------------------------------------
  it(
    "cancelMissionPaymentAuthorization : payment stripe_environment=\"test\" + provider actif \"live\" " +
      "=> AUCUN appel cancelAuthorization(), échec générique, payment reste AUTHORIZED (pas de transition forcée)",
    async () => {
      const fakeLiveProvider = new FakeLivePaymentProvider(); // environment: "live"
      setPaymentProviderForTesting(fakeLiveProvider);
      const cancelSpy = jest.spyOn(fakeLiveProvider, "cancelAuthorization");

      const paymentId = "pay_env_guard_cancel_001";
      const missionId = "mission_env_guard_cancel_001";
      await seedAuthorizedPayment(paymentId, missionId, 5000, "test");

      const result = await cancelMissionPaymentAuthorization(missionId, paymentId);

      expect(cancelSpy).not.toHaveBeenCalled();
      expect(result.success).toBe(false);
      expect(result.alreadyCancelled).toBe(false);
      expect(result.skipped).toBe(false);
      expect(result.status).toBe("error");
      expect(result.failureMessage).toBeTruthy();

      // 🔒 Contrairement à captureMissionPayment, AUCUNE transition Firestore
      // n'est forcée sur mismatch (voir paymentOrchestration.ts, commentaire
      // "Phase 8B (item f)" sur cancelMissionPaymentAuthorization) — le
      // paiement reste EXACTEMENT dans l'état où il était avant l'appel.
      const paymentDoc = (await db.collection("payments").doc(paymentId).get()).data()!;
      expect(paymentDoc.status).toBe(PaymentStatuses.AUTHORIZED);

      const missionDoc = (await db.collection("delivery_requests").doc(missionId).get()).data()!;
      expect(missionDoc.payment_status).toBe(PaymentStatuses.AUTHORIZED);

      await cleanupPayment(paymentId, missionId);
    }
  );

  // -------------------------------------------------------------------------
  // 3. submitDriverPayout — référence "live" réutilisée par un provider
  //    "test" actif => AUCUN appel provider.createDriverPayout(), payout
  //    FAILED avec failure_reason=stripe_environment_mismatch.
  // -------------------------------------------------------------------------
  it(
    "submitDriverPayout : payout stripe_environment=\"live\" + provider actif \"test\" " +
      "=> AUCUN appel createDriverPayout(), payout FAILED avec failure_reason=stripe_environment_mismatch",
    async () => {
      const fakeProvider = new FakePaymentProvider(); // environment: "test"
      setPaymentProviderForTesting(fakeProvider);
      const payoutSpy = jest.spyOn(fakeProvider, "createDriverPayout");

      const payoutId = "payout_env_guard_001";
      await seedEligiblePayout(payoutId, 2000, "live");

      const result = await submitDriverPayout(payoutId);

      expect(payoutSpy).not.toHaveBeenCalled();
      expect(result.success).toBe(false);
      expect(result.status).toBe(PayoutStatuses.FAILED);

      const payoutDoc = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutDoc.status).toBe(PayoutStatuses.FAILED);
      expect(payoutDoc.failure_reason).toBe(STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE);
      expect(payoutDoc.paid_at).toBeNull();
      expect(payoutDoc.provider_payout_id).toBeNull();

      await cleanupPayout(payoutId);
    }
  );

  // -------------------------------------------------------------------------
  // 4. refundPayment — référence "test" réutilisée par un provider "live"
  //    actif (sens INVERSE du scénario 3) => AUCUN appel
  //    provider.refundPayment(), refund PROCESSING->FAILED avec
  //    failed_reason=stripe_environment_mismatch, PaymentDoc PARENT
  //    INCHANGÉ (reste CAPTURED, jamais REFUNDED/PARTIALLY_REFUNDED).
  // -------------------------------------------------------------------------
  it(
    "refundPayment : payment (parent) stripe_environment=\"test\" + provider actif \"live\" " +
      "=> AUCUN appel refundPayment(), refund PROCESSING->FAILED, PaymentDoc parent INCHANGÉ",
    async () => {
      const fakeLiveProvider = new FakeLivePaymentProvider(); // environment: "live"
      setPaymentProviderForTesting(fakeLiveProvider);
      const refundSpy = jest.spyOn(fakeLiveProvider, "refundPayment");

      const paymentId = "pay_env_guard_refund_001";
      const missionId = "mission_env_guard_refund_001";
      await seedCapturedPayment(paymentId, missionId, 5000, "test");

      const result = await refundPayment({
        paymentId,
        amountMinor: 5000,
        reason: RefundReasons.CUSTOMER_REQUEST,
        initiatedByUserId: CUSTOMER_ID,
        initiatedByRole: "customer",
        isAdminInitiated: false,
        requestKey: `refund_env_guard_${paymentId}`,
      });

      expect(refundSpy).not.toHaveBeenCalled();
      expect(result.success).toBe(false);
      expect(result.status).toBe(RefundStatuses.FAILED);

      const refundDoc = (await db.collection("refunds").doc(`refund_env_guard_${paymentId}`).get()).data()!;
      expect(refundDoc.status).toBe(RefundStatuses.FAILED);
      expect(refundDoc.failed_reason).toBe(STRIPE_ENVIRONMENT_MISMATCH_ERROR_CODE);
      expect(refundDoc.provider_refund_id).toBeNull();

      // 🔒 Le PaymentDoc PARENT n'est jamais modifié par cet échec (voir
      // paymentOrchestration.ts, commentaire "Phase 8B (item f)" sur
      // refundPayment) — reste CAPTURED, amount_refunded_minor toujours 0.
      const paymentDoc = (await db.collection("payments").doc(paymentId).get()).data()!;
      expect(paymentDoc.status).toBe(PaymentStatuses.CAPTURED);
      expect(paymentDoc.amount_refunded_minor).toBe(0);

      await cleanupRefunds(paymentId);
      await cleanupPayment(paymentId, missionId);
    }
  );

  // -------------------------------------------------------------------------
  // 5. onMissionEndedClearTracking — délègue à
  //    cancelMissionPaymentAuthorization() sur une transition ENTRANTE vers
  //    'cancelled' : prouve que le garde-fou se déclenche aussi via CE
  //    trigger Firestore (pas seulement via un appel direct de la fonction
  //    d'orchestration) et que le nettoyage `driver_locations` continue de
  //    s'exécuter normalement (comportement indépendant, jamais bloqué par
  //    l'échec du volet paiement).
  // -------------------------------------------------------------------------
  it(
    "onMissionEndedClearTracking : mission annulée avec active_payment_id \"live\" + provider actif \"test\" " +
      "=> AUCUN appel cancelAuthorization() (via cancelMissionPaymentAuthorization), " +
      "payment reste AUTHORIZED, ET le nettoyage driver_locations s'exécute normalement",
    async () => {
      const fakeProvider = new FakePaymentProvider(); // environment: "test"
      setPaymentProviderForTesting(fakeProvider);
      const cancelSpy = jest.spyOn(fakeProvider, "cancelAuthorization");

      const paymentId = "pay_env_guard_trigger_001";
      const missionId = "mission_env_guard_trigger_001";
      await seedAuthorizedPayment(paymentId, missionId, 5000, "live");
      await db
        .collection("driver_locations")
        .doc(DRIVER_ID)
        .set({ active_delivery_id: missionId }, { merge: true });

      await onMissionEndedClearTracking.run(
        buildMissionEndedEvent(
          missionId,
          { status: "in_transit", driver_id: DRIVER_ID, active_payment_id: paymentId },
          { status: "cancelled", driver_id: DRIVER_ID, active_payment_id: paymentId }
        )
      );

      // Volet paiement : garde-fou déclenché, aucun appel provider.
      expect(cancelSpy).not.toHaveBeenCalled();
      const paymentDoc = (await db.collection("payments").doc(paymentId).get()).data()!;
      expect(paymentDoc.status).toBe(PaymentStatuses.AUTHORIZED);

      // Volet tracking : nettoyage INDÉPENDANT toujours exécuté (le trigger
      // ne s'arrête pas parce que le volet paiement a échoué — les deux
      // effets sont séquentiels mais non couplés dans onMissionEndedClearTracking.ts).
      const locationSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
      expect(locationSnap.data()!.active_delivery_id).toBeNull();

      await db.collection("driver_locations").doc(DRIVER_ID).delete();
      await cleanupPayment(paymentId, missionId);
    }
  );

  // -------------------------------------------------------------------------
  // 6. Contrôle positif (non-régression) : cohérence test/test => l'appel
  //    provider a lieu normalement, sur AU MOINS une des 5 opérations
  //    (choisie ici : captureMissionPayment) — garantit que ce fichier ne
  //    "prouve" pas un simple no-op général, mais bien un blocage SPÉCIFIQUE
  //    à l'incohérence d'environnement.
  // -------------------------------------------------------------------------
  it(
    "[contrôle positif] captureMissionPayment : payment stripe_environment=\"test\" + provider actif \"test\" " +
      "=> capturePayment() EST appelé, capture RÉUSSIE normalement",
    async () => {
      const fakeProvider = new FakePaymentProvider(); // environment: "test"
      setPaymentProviderForTesting(fakeProvider);
      const captureSpy = jest.spyOn(fakeProvider, "capturePayment");

      const paymentId = "pay_env_guard_control_001";
      const missionId = "mission_env_guard_control_001";
      await seedAuthorizedPayment(paymentId, missionId, 5000, "test");

      const result = await captureMissionPayment(missionId, paymentId);

      expect(captureSpy).toHaveBeenCalledTimes(1);
      expect(result.success).toBe(true);
      // 🔒 `result.status` reflète le statut BRUT renvoyé par le provider
      // (CapturePaymentResult.status, ex: "succeeded"), PAS le PaymentStatus
      // Firestore — voir CapturePaymentResult dans paymentProvider.ts. La
      // machine d'état applicative (payments/{id}.status) est vérifiée
      // séparément ci-dessous via paymentDoc.status.
      expect(result.status).toBe("succeeded");

      const paymentDoc = (await db.collection("payments").doc(paymentId).get()).data()!;
      expect(paymentDoc.status).toBe(PaymentStatuses.CAPTURED);
      expect(paymentDoc.amount_captured_minor).toBe(5000);

      await cleanupPayment(paymentId, missionId);
    }
  );
});
