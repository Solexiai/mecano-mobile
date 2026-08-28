// ---------------------------------------------------------------------------
// Test d'intégration E2E — BLOC Q (Phase 6, directive 38 points) : CYCLE
// REFUND COMPLET, en utilisant EXCLUSIVEMENT les vraies Cloud Functions
// (jamais une écriture Firestore directe pour simuler une transition
// métier déjà couverte par une fonction existante).
//
// Chaîne testée (deux scénarios) :
//   SCÉNARIO 1 — REFUND PARTIEL (post-capture) :
//     devis -> mission -> acceptDelivery (paiement autorisé) -> cycle
//     livraison -> completeDelivery (capture) -> refundPayment (PARTIEL,
//     réel via Cloud Function) -> refund SUCCEEDED -> provider refund ->
//     ledger PARTIAL_REFUND compensatoire -> mission_financial_balance
//     recalculée (customer_refunded_minor, outstanding_customer_balance) ->
//     réconciliation cohérente (aucune anomalie pertinente).
//
//   SCÉNARIO 2 — REFUND TOTAL (post-capture) :
//     même chaîne jusqu'à completeDelivery -> refundPayment (montant omis
//     => remboursement TOTAL du solde capturé) -> payment REFUNDED ->
//     ledger REFUND (pas PARTIAL_REFUND) -> mission_financial_balance
//     (customer_refunded_minor == customer_charged_minor,
//     outstanding_customer_balance_minor == 0) -> réconciliation cohérente.
//
// AUCUNE simulation de transition Firestore directe pour une opération que
// refundPayment() (Cloud Function réelle, déléguant à
// payment/paymentOrchestration.ts::refundPayment) doit effectuer.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";

import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import { createDeliveryRequest, CreateDeliveryRequestRequest, StopInput } from "../../src/functions/createDeliveryRequest";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import {
  updateMissionTrackingStatus,
  UpdateMissionTrackingStatusRequest,
} from "../../src/functions/updateMissionTrackingStatus";
import { completePickup, CompletePickupRequest } from "../../src/functions/completePickup";
import { completeDelivery, CompleteDeliveryRequest } from "../../src/functions/completeDelivery";
import { refundPayment, RefundPaymentRequest } from "../../src/functions/refundPayment";
import { runReconciliationNow, RunReconciliationNowRequest } from "../../src/functions/runReconciliation";

import { admin, db } from "../../src/lib/admin";
import {
  LedgerEntryTypes,
  MissionStatuses,
  PaymentStatuses,
  RefundReasons,
  RefundStatuses,
} from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import { DEFAULT_CURRENCY, toMinorUnits } from "../../src/lib/money";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import type { ProviderPaymentSummary, ProviderRefundSummary } from "../../src/payment/paymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

// ---------------------------------------------------------------------------
// Constantes du scénario — préfixe dédié pour ne jamais interférer avec les
// autres fichiers de test exécutés dans la même suite (voir e2eFinancialLifecycle.test.ts).
// ---------------------------------------------------------------------------
const CUSTOMER_ID = "e2erefund_customer_001";
const DRIVER_ID = "e2erefund_driver_001";
const PRICING_VERSION = "E2EREFUND-PRICING-001";

function authedRequest<T>(uid: string | undefined, role: string | undefined, data: T): CallableRequest<T> {
  return {
    data,
    auth: uid
      ? { uid, token: (role ? { role } : {}) as unknown as DecodedIdToken, rawToken: "fake-raw-token" }
      : undefined,
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedPricing(): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

async function seedPaymentProfile(): Promise<void> {
  await db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID));
}

async function seedApprovedDriver(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur E2E Refund",
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.9,
    completed_missions: 6,
    created_at: admin.firestore.Timestamp.now(),
    approved_at: admin.firestore.Timestamp.now(),
    approved_by_user_id: "admin_seed",
    identity_verified: true,
    vehicle_verified: true,
    online_status: "online",
    documents_all_valid: true,
    stripe_connected_account_id: null,
  });
}

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "10 rue Refund Départ", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "20 rue Refund Arrivée", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

/**
 * Exécute la chaîne complète client -> devis -> mission -> acceptation ->
 * cycle livraison -> completeDelivery (capture), EXCLUSIVEMENT via les
 * vraies Cloud Functions. Retourne les identifiants nécessaires aux
 * scénarios de remboursement (points communs aux deux scénarios Bloc Q).
 */
async function runToCapturedCompletion(): Promise<{
  missionId: string;
  activePaymentId: string;
  amountCapturedMinor: number;
}> {
  const quote = await calculateDeliveryQuote.run(
    authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, undefined, {
      vehicleCategory: "cargoVan",
      distanceKm: 12,
      estimatedDurationMinutes: 25,
    })
  );

  const created = await createDeliveryRequest.run(
    authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, undefined, {
      quoteId: quote.quoteId,
      itemCategoryKey: "furniture",
      description: "Déménagement E2E refund — bibliothèque + chaises.",
      requiredVehicleCategory: "cargoVan",
      distanceKm: 12,
      estimatedDurationMinutes: 25,
      stops: [pickupStop, dropoffStop],
      customerDisplayName: "Client E2E Refund",
    })
  );
  const missionId = created.missionId;

  const accepted = await acceptDelivery.run(
    authedRequest<AcceptDeliveryRequest>(DRIVER_ID, undefined, { missionId })
  );
  expect(accepted.success).toBe(true);

  const missionSnapAfterAccept = await db.collection("delivery_requests").doc(missionId).get();
  const activePaymentId = missionSnapAfterAccept.data()!.active_payment_id as string;
  expect(activePaymentId).toBeTruthy();

  await updateMissionTrackingStatus.run(
    authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
      missionId,
      targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
    })
  );
  await updateMissionTrackingStatus.run(
    authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
      missionId,
      targetStatus: MissionStatuses.ARRIVED_AT_PICKUP,
    })
  );
  await completePickup.run(authedRequest<CompletePickupRequest>(DRIVER_ID, undefined, { missionId }));
  await updateMissionTrackingStatus.run(
    authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
      missionId,
      targetStatus: MissionStatuses.IN_TRANSIT,
    })
  );
  await updateMissionTrackingStatus.run(
    authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
      missionId,
      targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF,
    })
  );

  const PROOF_URL = `https://storage.googleapis.com/movik-test/delivery_proofs/${missionId}/proof.jpg`;
  const completed = await completeDelivery.run(
    authedRequest<CompleteDeliveryRequest>(DRIVER_ID, undefined, {
      missionId,
      proofOfDeliveryUrl: PROOF_URL,
    })
  );
  expect(completed.success).toBe(true);
  expect(completed.paymentCaptured).toBe(true);

  const paymentAfterCapture = await db.collection("payments").doc(activePaymentId).get();
  expect(paymentAfterCapture.data()!.status).toBe(PaymentStatuses.CAPTURED);
  const amountCapturedMinor = paymentAfterCapture.data()!.amount_captured_minor as number;
  expect(amountCapturedMinor).toBeGreaterThan(0);

  return { missionId, activePaymentId, amountCapturedMinor };
}

async function cleanupAll(missionId: string | null): Promise<void> {
  if (missionId) {
    const missionRef = db.collection("delivery_requests").doc(missionId);
    const [stops, events, ledger, snapshots, payments, balance] = await Promise.all([
      missionRef.collection("stops").get(),
      missionRef.collection("tracking_events").get(),
      db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
      db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
      db.collection("payments").where("mission_id", "==", missionId).get(),
      db.collection("mission_financial_balance").doc(missionId).get(),
    ]);
    const paymentIds = payments.docs.map((d) => d.id);
    const refundsSnap = await db
      .collection("refunds")
      .where("payment_id", "in", paymentIds.length > 0 ? paymentIds.slice(0, 10) : ["__none__"])
      .get();
    await Promise.all([
      ...stops.docs.map((d) => d.ref.delete()),
      ...events.docs.map((d) => d.ref.delete()),
      ...ledger.docs.map((d) => d.ref.delete()),
      ...snapshots.docs.map((d) => d.ref.delete()),
      ...payments.docs.map((d) => d.ref.delete()),
      ...refundsSnap.docs.map((d) => d.ref.delete()),
      balance.exists ? balance.ref.delete() : Promise.resolve(),
      missionRef.delete(),
      db
        .collection("audit_logs")
        .where("target_id", "==", missionId)
        .get()
        .then((s) => Promise.all(s.docs.map((d) => d.ref.delete()))),
      ...paymentIds.map((pid) =>
        db
          .collection("audit_logs")
          .where("target_id", "==", pid)
          .get()
          .then((s) => Promise.all(s.docs.map((d) => d.ref.delete())))
      ),
    ]);
  }
  const reconAudit = await db
    .collection("audit_logs")
    .where("action", "==", "reconciliation_anomaly_detected")
    .get();
  await Promise.all(
    reconAudit.docs
      .filter((d) => (d.data().metadata?.periodStartMillis ?? 0) > Date.now() - 24 * 3600 * 1000)
      .map((d) => d.ref.delete())
  );
  await Promise.all([
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
  const refundAudit = await db
    .collection("audit_logs")
    .where("action", "in", ["refund_requested", "refund_succeeded", "refund_failed"])
    .get();
  await Promise.all(
    refundAudit.docs
      .filter((d) => (d.data().metadata?.correlationId ? true : false) || true)
      .filter((d) => {
        // Nettoyage ciblé : ne supprime que les audit_logs dont target_id
        // correspond à un des paymentIds de CE fichier (préfixe e2erefund
        // porté par CUSTOMER_ID -> impossible de filtrer directement sur
        // target_id ici sans le connaître ; on filtre donc par récence
        // (fenêtre des 24h) pour rester conservateur sans toucher aux
        // audit_logs d'autres suites plus anciennes).
        const createdAtMs = (d.data().created_at as FirebaseFirestore.Timestamp)?.toMillis?.() ?? 0;
        return createdAtMs > Date.now() - 24 * 3600 * 1000;
      })
      .map((d) => d.ref.delete())
  );
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("E2E REFUND (Bloc P->Q) — paiement capturé -> remboursement réel -> ledger compensatoire -> balance -> réconciliation", () => {
  let fakeProvider: FakePaymentProvider;
  let providerPayments: ProviderPaymentSummary[];
  let providerRefunds: ProviderRefundSummary[];
  let currentMissionId: string | null = null;

  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  // 🔒 Une instance FRAÎCHE de FakePaymentProvider par test (et non
  // partagée via beforeAll) — indispensable pour que `jest.spyOn(...,
  // "refundPayment")` ne comptabilise QUE les appels du test courant.
  // Chaque scénario reçoit ses propres tableaux providerPayments/Refunds
  // mutables, alimentés APRÈS coup avec les identifiants provider
  // réellement générés à l'exécution (même pattern que
  // e2eFinancialLifecycle.test.ts, Bloc P).
  beforeEach(async () => {
    providerPayments = [];
    providerRefunds = [];
    fakeProvider = new FakePaymentProvider({ providerPayments, providerRefunds });
    setPaymentProviderForTesting(fakeProvider);
    await Promise.all([seedPricing(), seedApprovedDriver(), seedPaymentProfile()]);
  });

  afterEach(async () => {
    await cleanupAll(currentMissionId);
    currentMissionId = null;
    setPaymentProviderForTesting(null);
  });

  it(
    "SCÉNARIO 1 — REFUND PARTIEL : payment capturé -> refundPayment (partiel) -> " +
      "refund SUCCEEDED -> ledger PARTIAL_REFUND -> mission_financial_balance recalculée -> réconciliation cohérente",
    async () => {
      const refundSpy = jest.spyOn(fakeProvider, "refundPayment");

      const { missionId, activePaymentId, amountCapturedMinor } = await runToCapturedCompletion();
      currentMissionId = missionId;

      // ===== REFUND PARTIEL (40% du montant capturé, cents entiers) =====
      const partialAmountMinor = Math.floor(amountCapturedMinor * 0.4);
      expect(partialAmountMinor).toBeGreaterThan(0);

      const refundResult = await refundPayment.run(
        authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId: activePaymentId,
          amountMinor: partialAmountMinor,
          reason: RefundReasons.PARTIAL_DELIVERY,
          clientRequestId: `e2erefund_partial_click_${missionId}`,
        })
      );
      expect(refundResult.success).toBe(true);
      expect(refundResult.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundSpy).toHaveBeenCalledTimes(1);

      // ---- payment : PARTIALLY_REFUNDED, amount_refunded_minor exact ----
      const paymentAfterRefund = await db.collection("payments").doc(activePaymentId).get();
      expect(paymentAfterRefund.data()!.status).toBe(PaymentStatuses.PARTIALLY_REFUNDED);
      expect(paymentAfterRefund.data()!.amount_refunded_minor).toBe(partialAmountMinor);
      expect(Number.isInteger(paymentAfterRefund.data()!.amount_refunded_minor)).toBe(true);

      // ---- refunds/{id} : SUCCEEDED, provider_refund_id renseigné (appel réel provider) ----
      const refundDoc = await db.collection("refunds").doc(refundResult.refundId).get();
      expect(refundDoc.exists).toBe(true);
      const refundData = refundDoc.data()!;
      expect(refundData.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundData.amount_minor).toBe(partialAmountMinor);
      expect(refundData.provider_refund_id).toBeTruthy();
      expect(refundData.is_post_payout).toBe(false); // aucun payout PAID lié dans ce scénario

      // ---- ledger : exactement 1 entrée PARTIAL_REFUND, montant exact ----
      const ledgerRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.PARTIAL_REFUND)
        .get();
      expect(ledgerRefundSnap.size).toBe(1);
      expect(ledgerRefundSnap.docs[0].data().amount_minor).toBe(partialAmountMinor);
      expect(ledgerRefundSnap.docs[0].data().source_event).toBe("refund_before_payout");

      // ---- mission_financial_balance recalculée (point 7 Phase 6) ----
      const balanceAfterRefund = await db.collection("mission_financial_balance").doc(missionId).get();
      expect(balanceAfterRefund.exists).toBe(true);
      const bal = balanceAfterRefund.data()!;
      expect(bal.customer_charged_minor).toBe(amountCapturedMinor);
      expect(bal.customer_refunded_minor).toBe(partialAmountMinor);
      expect(bal.outstanding_customer_balance_minor).toBe(amountCapturedMinor - partialAmountMinor);

      // ===== RÉCONCILIATION : injecte le paiement ET le refund provider =====
      // 🔒 Le moteur de réconciliation vérifie AUSSI que chaque paiement
      // capturé (montant CAPTURÉ, pas net du refund) existe côté provider
      // (vérification 2/3, payment_missing_in_provider/amount_mismatch) —
      // sans cette injection, le paiement capturé de ce test serait
      // signalé absent, faussant le test (bug de test, pas de backend).
      providerPayments.push({
        providerPaymentIntentId: paymentAfterRefund.data()!.provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });
      providerRefunds.push({
        providerRefundId: refundData.provider_refund_id as string,
        providerPaymentIntentId: paymentAfterRefund.data()!.provider_payment_intent_id as string,
        amountMinor: partialAmountMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });

      const periodStartMillis = Date.now() - 3600 * 1000;
      const periodEndMillis = Date.now() + 3600 * 1000;
      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>("e2erefund_admin_001", "admin", {
          periodStartMillis,
          periodEndMillis,
        })
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) => a.mission_id === missionId || a.payment_id === activePaymentId || a.refund_id === refundResult.refundId
      );
      expect(relevantAnomalies).toHaveLength(0);
    }
  );

  it(
    "SCÉNARIO 2 — REFUND TOTAL : payment capturé -> refundPayment (montant omis = TOTAL) -> " +
      "payment REFUNDED -> ledger REFUND -> mission_financial_balance (solde client à zéro) -> réconciliation cohérente",
    async () => {
      const refundSpy = jest.spyOn(fakeProvider, "refundPayment");

      const { missionId, activePaymentId, amountCapturedMinor } = await runToCapturedCompletion();
      currentMissionId = missionId;

      // ===== REFUND TOTAL : amountMinor OMIS => solde restant intégral =====
      const refundResult = await refundPayment.run(
        authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId: activePaymentId,
          reason: RefundReasons.CUSTOMER_REQUEST,
          clientRequestId: `e2erefund_full_click_${missionId}`,
        })
      );
      expect(refundResult.success).toBe(true);
      expect(refundResult.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundSpy).toHaveBeenCalledTimes(1);

      // ---- payment : REFUNDED (pas PARTIALLY_REFUNDED), montant = capturé exact ----
      const paymentAfterRefund = await db.collection("payments").doc(activePaymentId).get();
      expect(paymentAfterRefund.data()!.status).toBe(PaymentStatuses.REFUNDED);
      expect(paymentAfterRefund.data()!.amount_refunded_minor).toBe(amountCapturedMinor);

      // ---- refunds/{id} : montant = capturé exact ----
      const refundDoc = await db.collection("refunds").doc(refundResult.refundId).get();
      const refundData = refundDoc.data()!;
      expect(refundData.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundData.amount_minor).toBe(amountCapturedMinor);
      expect(refundData.provider_refund_id).toBeTruthy();

      // ---- ledger : exactement 1 entrée REFUND (pas PARTIAL_REFUND) ----
      const ledgerFullRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.REFUND)
        .get();
      expect(ledgerFullRefundSnap.size).toBe(1);
      expect(ledgerFullRefundSnap.docs[0].data().amount_minor).toBe(amountCapturedMinor);

      const ledgerPartialRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.PARTIAL_REFUND)
        .get();
      expect(ledgerPartialRefundSnap.size).toBe(0);

      // ---- mission_financial_balance : solde client entièrement remboursé ----
      const balanceAfterRefund = await db.collection("mission_financial_balance").doc(missionId).get();
      const bal = balanceAfterRefund.data()!;
      expect(bal.customer_charged_minor).toBe(amountCapturedMinor);
      expect(bal.customer_refunded_minor).toBe(amountCapturedMinor);
      expect(bal.outstanding_customer_balance_minor).toBe(0);

      // Un second remboursement (même 1 cent) doit être refusé : plus rien à rembourser.
      await expect(
        refundPayment.run(
          authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
            paymentId: activePaymentId,
            amountMinor: 1,
            reason: RefundReasons.CUSTOMER_REQUEST,
            clientRequestId: `e2erefund_full_click_second_${missionId}`,
          })
        )
      ).rejects.toThrow();

      // ===== RÉCONCILIATION : injecte le paiement ET le refund provider =====
      providerPayments.push({
        providerPaymentIntentId: paymentAfterRefund.data()!.provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });
      providerRefunds.push({
        providerRefundId: refundData.provider_refund_id as string,
        providerPaymentIntentId: paymentAfterRefund.data()!.provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });

      const periodStartMillis = Date.now() - 3600 * 1000;
      const periodEndMillis = Date.now() + 3600 * 1000;
      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>("e2erefund_admin_001", "admin", {
          periodStartMillis,
          periodEndMillis,
        })
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) => a.mission_id === missionId || a.payment_id === activePaymentId || a.refund_id === refundResult.refundId
      );
      expect(relevantAnomalies).toHaveLength(0);
    }
  );
});
