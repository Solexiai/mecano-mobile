// ---------------------------------------------------------------------------
// Test d'intégration E2E — BLOC R (Phase 6, directive 38 points) : REFUND
// APRÈS PAYOUT, en utilisant EXCLUSIVEMENT les vraies Cloud Functions
// (jamais une écriture Firestore directe pour simuler une transition
// métier déjà couverte par une fonction existante).
//
// Objectif (voir docs/PHASE6_R_TO_V_PLAN.md) : prouver le comportement
// financier lorsque le chauffeur a DÉJÀ été payé et qu'un remboursement
// client arrive ENSUITE.
//
// Chaîne testée (par scénario) :
//   payment authorized -> payment captured -> mission completed ->
//   driver earnings (financial_snapshot confirmed) -> payout créé
//   (calculateDriverPayout) -> hold expiré / cron (processScheduledDriverPayouts)
//   -> payout PAID -> refund client APRÈS payout (refundPayment, réel) ->
//   provider refund succeeded -> payout historique INCHANGÉ -> compensation
//   comptabilisée (ledger + mission_financial_balance) -> réconciliation
//   cohérente.
//
// 🔒 RÈGLE IMPÉRATIVE (directive utilisateur) : ne JAMAIS récupérer
// automatiquement l'argent du chauffeur pour faire passer ce test.
// L'architecture actuelle (voir missionFinancialBalance.ts,
// paymentOrchestration.ts::refundPayment) ne prévoit AUCUNE récupération
// automatique du versement chauffeur déjà PAID — le remboursement client
// est comptabilisé côté CLIENT uniquement (transaction_ledger:
// REFUND/PARTIAL_REFUND, party=customer, direction=debit ;
// mission_financial_balance.customer_refunded_minor /
// outstanding_customer_balance_minor). driver_paid_minor et le
// driver_payouts historique restent STRICTEMENT inchangés — ce test vérifie
// exactement ce comportement, sans inventer de règle commerciale de
// récupération qui n'existe pas dans le code.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { ScheduledEvent } from "firebase-functions/v2/scheduler";

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
import {
  calculateDriverPayout,
  CalculateDriverPayoutRequest,
} from "../../src/functions/calculateDriverPayout";
import { processScheduledDriverPayouts } from "../../src/functions/processScheduledDriverPayouts";
import { runReconciliationNow, RunReconciliationNowRequest } from "../../src/functions/runReconciliation";

import { admin, db } from "../../src/lib/admin";
import {
  LedgerEntryTypes,
  MissionStatuses,
  PaymentStatuses,
  PayoutStatuses,
  RefundReasons,
  RefundStatuses,
} from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import type {
  ProviderPaymentSummary,
  ProviderPayoutSummary,
  ProviderRefundSummary,
} from "../../src/payment/paymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

// ---------------------------------------------------------------------------
// Constantes du scénario — préfixe dédié (e2erefundpp) pour ne jamais
// interférer avec les autres fichiers de test de la même suite.
// ---------------------------------------------------------------------------
const CUSTOMER_ID = "e2erefundpp_customer_001";
const DRIVER_ID = "e2erefundpp_driver_001";
const ADMIN_ID = "e2erefundpp_admin_001";
const PRICING_VERSION = "E2EREFUNDPP-PRICING-001";

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

function buildFakeScheduledEvent(): ScheduledEvent {
  return {
    scheduleTime: new Date().toISOString(),
    jobName: "processScheduledDriverPayouts-e2erefundpp-test",
  } as unknown as ScheduledEvent;
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

/** Chauffeur approuvé, SANS compte Stripe Connect au départ (onboarding tardif — même pattern que Bloc P). */
async function seedApprovedDriver(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur E2E Refund Post-Payout",
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
  address: { line1: "1 rue RefundPP Départ", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "2 rue RefundPP Arrivée", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

/**
 * Exécute la chaîne complète client -> devis -> mission -> acceptation ->
 * cycle livraison -> completeDelivery (capture) -> calculateDriverPayout
 * -> onboarding tardif -> processScheduledDriverPayouts (PAID),
 * EXCLUSIVEMENT via les vraies Cloud Functions. Retourne tous les
 * identifiants nécessaires aux scénarios de remboursement post-payout.
 */
async function runToPaidPayout(fakeProvider: FakePaymentProvider): Promise<{
  missionId: string;
  activePaymentId: string;
  amountCapturedMinor: number;
  payoutId: string;
}> {
  const quote = await calculateDeliveryQuote.run(
    authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, undefined, {
      vehicleCategory: "cargoVan",
      distanceKm: 18,
      estimatedDurationMinutes: 35,
    })
  );

  const created = await createDeliveryRequest.run(
    authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, undefined, {
      quoteId: quote.quoteId,
      itemCategoryKey: "furniture",
      description: "Déménagement E2E refund post-payout — armoire + matelas.",
      requiredVehicleCategory: "cargoVan",
      distanceKm: 18,
      estimatedDurationMinutes: 35,
      stops: [pickupStop, dropoffStop],
      customerDisplayName: "Client E2E Refund Post-Payout",
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

  // ===== PAYOUT : hold=0, driver sans compte connecté au départ =====
  await db.collection("payout_policy_configs").doc("default").set({
    default_hold_period_hours: 0,
    new_driver_hold_period_hours: 0,
    risky_driver_hold_period_hours: 168,
    updated_at: admin.firestore.Timestamp.now(),
    updated_by_user_id: "system_seed",
  });
  const payoutResult = await calculateDriverPayout.run(
    authedRequest<CalculateDriverPayoutRequest>(ADMIN_ID, "admin", { driverId: DRIVER_ID })
  );
  const payoutId = payoutResult.payoutId as string;
  expect(payoutId).toBeTruthy();

  const payoutSnapAtCreation = await db.collection("driver_payouts").doc(payoutId).get();
  expect(payoutSnapAtCreation.data()!.status).toBe(PayoutStatuses.PENDING);

  // Onboarding tardif : le chauffeur obtient un compte Stripe Connect APRÈS
  // la création du payout (reproduit exactement le pattern Bloc P).
  await db
    .collection("driver_profiles")
    .doc(DRIVER_ID)
    .update({ stripe_connected_account_id: `fake_acct_${DRIVER_ID}` });

  await (
    processScheduledDriverPayouts as unknown as {
      run: (e: ScheduledEvent) => Promise<void>;
    }
  ).run(buildFakeScheduledEvent());

  const payoutSnapAfterCron = await db.collection("driver_payouts").doc(payoutId).get();
  expect(payoutSnapAfterCron.data()!.status).toBe(PayoutStatuses.PAID);
  expect(payoutSnapAfterCron.data()!.provider_payout_id).toBeTruthy();
  expect(fakeProvider).toBeTruthy(); // référence conservée pour le spy dans les tests appelants

  return { missionId, activePaymentId, amountCapturedMinor, payoutId };
}

async function cleanupAll(missionId: string | null, payoutId: string | null): Promise<void> {
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
  if (payoutId) {
    await db.collection("driver_payouts").doc(payoutId).delete();
    const payoutAudit = await db.collection("audit_logs").where("target_id", "==", payoutId).get();
    await Promise.all(payoutAudit.docs.map((d) => d.ref.delete()));
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
    db.collection("payout_policy_configs").doc("default").delete(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
  const policyAudit = await db
    .collection("audit_logs")
    .where("target_id", "==", "payout_policy_configs/default")
    .get();
  await Promise.all(policyAudit.docs.map((d) => d.ref.delete()));
  const refundAudit = await db
    .collection("audit_logs")
    .where("action", "in", ["refund_requested", "refund_succeeded", "refund_failed"])
    .get();
  await Promise.all(
    refundAudit.docs
      .filter((d) => {
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

describe("E2E REFUND APRÈS PAYOUT (Bloc R) — payout PAID -> refund client -> payout historique intact -> compensation cohérente", () => {
  let fakeProvider: FakePaymentProvider;
  let providerPayments: ProviderPaymentSummary[];
  let providerPayouts: ProviderPayoutSummary[];
  let providerRefunds: ProviderRefundSummary[];
  let currentMissionId: string | null = null;
  let currentPayoutId: string | null = null;

  // 🔒 Instance FRAÎCHE par test (voir Bloc Q) — indispensable pour que
  // jest.spyOn(..., "refundPayment"/"createDriverPayout") ne comptabilise
  // que les appels du test courant.
  beforeEach(async () => {
    providerPayments = [];
    providerPayouts = [];
    providerRefunds = [];
    fakeProvider = new FakePaymentProvider({ providerPayments, providerPayouts, providerRefunds });
    setPaymentProviderForTesting(fakeProvider);
    await Promise.all([seedPricing(), seedApprovedDriver(), seedPaymentProfile()]);
  });

  afterEach(async () => {
    await cleanupAll(currentMissionId, currentPayoutId);
    currentMissionId = null;
    currentPayoutId = null;
    setPaymentProviderForTesting(null);
  });

  it(
    "SCÉNARIO 1 — REFUND PARTIEL après payout PAID : payout historique INCHANGÉ, " +
      "ledger append-only, compensation client comptabilisée, réconciliation cohérente",
    async () => {
      const { missionId, activePaymentId, amountCapturedMinor, payoutId } = await runToPaidPayout(fakeProvider);
      currentMissionId = missionId;
      currentPayoutId = payoutId;

      const payoutBefore = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      const balanceBeforeRefund = (
        await db.collection("mission_financial_balance").doc(missionId).get()
      ).data()!;
      // Le payout est déjà PAID -> driver_paid_minor == driver_earned_minor (voir Bloc P).
      expect(balanceBeforeRefund.driver_paid_minor).toBe(balanceBeforeRefund.driver_earned_minor);
      const driverPaidBeforeRefund = balanceBeforeRefund.driver_paid_minor as number;

      const ledgerBeforeRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .get();
      const ledgerBeforeById = new Map(ledgerBeforeRefundSnap.docs.map((d) => [d.id, d.data()]));
      expect(ledgerBeforeById.size).toBe(5); // même décompte que Bloc P (pas de tip ici)

      const refundSpy = jest.spyOn(fakeProvider, "refundPayment");

      // ===== REFUND PARTIEL (30% du capturé) APRÈS que le payout soit PAID =====
      const partialAmountMinor = Math.floor(amountCapturedMinor * 0.3);
      expect(partialAmountMinor).toBeGreaterThan(0);

      const refundResult = await refundPayment.run(
        authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId: activePaymentId,
          amountMinor: partialAmountMinor,
          reason: RefundReasons.GOODWILL,
          clientRequestId: `e2erefundpp_partial_click_${missionId}`,
        })
      );
      expect(refundResult.success).toBe(true);
      expect(refundResult.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundSpy).toHaveBeenCalledTimes(1);

      // ---- refunds/{id} : is_post_payout=true, related_payout_id renseigné ----
      const refundDoc = await db.collection("refunds").doc(refundResult.refundId).get();
      const refundData = refundDoc.data()!;
      expect(refundData.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundData.amount_minor).toBe(partialAmountMinor);
      expect(refundData.is_post_payout).toBe(true);
      expect(refundData.related_payout_id).toBe(payoutId);

      // 🔒 ASSERTION CRITIQUE (directive Bloc R) : le driver_payouts
      // historique n'est touché EN AUCUN CHAMP par le remboursement client.
      const payoutAfter = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutAfter).toEqual(payoutBefore);
      expect(payoutAfter.status).toBe(PayoutStatuses.PAID);
      expect(payoutAfter.paid_at).toEqual(payoutBefore.paid_at);
      expect(payoutAfter.provider_payout_id).toBe(payoutBefore.provider_payout_id);
      expect(payoutAfter.amount_minor).toBe(payoutBefore.amount_minor);

      // 🔒 ASSERTION CRITIQUE : les 5 entrées ledger PRÉ-existantes (payment
      // authorization/charge, commission, driver_earning, etc.) sont
      // TOUJOURS présentes et STRICTEMENT inchangées (append-only : aucune
      // modification, aucune suppression).
      const ledgerAfterRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .get();
      for (const [docId, dataBefore] of ledgerBeforeById) {
        const docAfter = ledgerAfterRefundSnap.docs.find((d) => d.id === docId);
        expect(docAfter).toBeTruthy();
        expect(docAfter!.data()).toEqual(dataBefore);
      }
      // Exactement UNE nouvelle entrée compensatoire ajoutée (append-only).
      expect(ledgerAfterRefundSnap.size).toBe(ledgerBeforeById.size + 1);
      const newLedgerEntry = ledgerAfterRefundSnap.docs.find((d) => !ledgerBeforeById.has(d.id))!;
      expect(newLedgerEntry.data().type).toBe(LedgerEntryTypes.PARTIAL_REFUND);
      expect(newLedgerEntry.data().amount_minor).toBe(partialAmountMinor);
      expect(newLedgerEntry.data().source_event).toBe("refund_after_payout");
      expect(newLedgerEntry.data().reference_id).toBe(payoutId);

      // ---- mission_financial_balance recalculée : compensation cliente ----
      // 🔒 driver_paid_minor reste EXACT (historique) — aucune récupération
      // automatique de l'argent chauffeur inventée par ce test.
      const balanceAfterRefund = (
        await db.collection("mission_financial_balance").doc(missionId).get()
      ).data()!;
      expect(balanceAfterRefund.driver_paid_minor).toBe(driverPaidBeforeRefund);
      expect(balanceAfterRefund.customer_charged_minor).toBe(amountCapturedMinor);
      expect(balanceAfterRefund.customer_refunded_minor).toBe(partialAmountMinor);
      // Compensation comptabilisée via le solde client (mécanisme existant,
      // aucune règle commerciale inventée) : le solde restant dû AU client
      // diminue exactement du montant remboursé.
      expect(balanceAfterRefund.outstanding_customer_balance_minor).toBe(
        amountCapturedMinor - partialAmountMinor
      );

      // ===== RÉCONCILIATION : injecte paiement + payout + refund provider =====
      providerPayments.push({
        providerPaymentIntentId:
          (await db.collection("payments").doc(activePaymentId).get()).data()!
            .provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });
      providerPayouts.push({
        providerPayoutId: payoutAfter.provider_payout_id as string,
        connectedAccountId: payoutAfter.connected_account_id as string,
        amountMinor: payoutAfter.amount_minor as number,
        status: "paid",
        createdAtMillis: Date.now(),
      });
      providerRefunds.push({
        providerRefundId: refundData.provider_refund_id as string,
        providerPaymentIntentId:
          (await db.collection("payments").doc(activePaymentId).get()).data()!
            .provider_payment_intent_id as string,
        amountMinor: partialAmountMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });

      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", {
          periodStartMillis: Date.now() - 3600 * 1000,
          periodEndMillis: Date.now() + 3600 * 1000,
        })
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) =>
          a.mission_id === missionId ||
          a.payment_id === activePaymentId ||
          a.payout_id === payoutId ||
          a.refund_id === refundResult.refundId
      );
      expect(relevantAnomalies).toHaveLength(0);
    }
  );

  it(
    "SCÉNARIO 2 — REFUND COMPLET après payout PAID : payment REFUNDED, payout historique " +
      "INCHANGÉ, solde client à zéro, driver_paid inchangé, réconciliation cohérente",
    async () => {
      const { missionId, activePaymentId, amountCapturedMinor, payoutId } = await runToPaidPayout(fakeProvider);
      currentMissionId = missionId;
      currentPayoutId = payoutId;

      const payoutBefore = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      const balanceBeforeRefund = (
        await db.collection("mission_financial_balance").doc(missionId).get()
      ).data()!;
      const driverPaidBeforeRefund = balanceBeforeRefund.driver_paid_minor as number;

      const refundSpy = jest.spyOn(fakeProvider, "refundPayment");

      // ===== REFUND COMPLET (amountMinor omis = solde capturé intégral) =====
      const refundResult = await refundPayment.run(
        authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
          paymentId: activePaymentId,
          reason: RefundReasons.MISSION_IMPOSSIBLE,
          clientRequestId: `e2erefundpp_full_click_${missionId}`,
        })
      );
      expect(refundResult.success).toBe(true);
      expect(refundResult.status).toBe(RefundStatuses.SUCCEEDED);
      expect(refundSpy).toHaveBeenCalledTimes(1);

      const paymentAfterFullRefund = await db.collection("payments").doc(activePaymentId).get();
      expect(paymentAfterFullRefund.data()!.status).toBe(PaymentStatuses.REFUNDED);
      expect(paymentAfterFullRefund.data()!.amount_refunded_minor).toBe(amountCapturedMinor);

      const refundDoc = await db.collection("refunds").doc(refundResult.refundId).get();
      const refundData = refundDoc.data()!;
      expect(refundData.is_post_payout).toBe(true);
      expect(refundData.related_payout_id).toBe(payoutId);
      expect(refundData.amount_minor).toBe(amountCapturedMinor);

      // 🔒 ASSERTION CRITIQUE : payout historique STRICTEMENT inchangé même
      // pour un remboursement TOTAL post-payout.
      const payoutAfter = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutAfter).toEqual(payoutBefore);
      expect(payoutAfter.status).toBe(PayoutStatuses.PAID);
      expect(payoutAfter.paid_at).toEqual(payoutBefore.paid_at);
      expect(payoutAfter.provider_payout_id).toBe(payoutBefore.provider_payout_id);
      expect(payoutAfter.amount_minor).toBe(payoutBefore.amount_minor);

      // ---- ledger : entrée REFUND (pas PARTIAL_REFUND), source_event correct ----
      const ledgerFullRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.REFUND)
        .get();
      expect(ledgerFullRefundSnap.size).toBe(1);
      expect(ledgerFullRefundSnap.docs[0].data().amount_minor).toBe(amountCapturedMinor);
      expect(ledgerFullRefundSnap.docs[0].data().source_event).toBe("refund_after_payout");
      expect(ledgerFullRefundSnap.docs[0].data().reference_id).toBe(payoutId);

      // ---- mission_financial_balance : solde client à zéro, driver_paid INCHANGÉ ----
      const balanceAfterFullRefund = (
        await db.collection("mission_financial_balance").doc(missionId).get()
      ).data()!;
      expect(balanceAfterFullRefund.driver_paid_minor).toBe(driverPaidBeforeRefund);
      expect(balanceAfterFullRefund.customer_refunded_minor).toBe(amountCapturedMinor);
      expect(balanceAfterFullRefund.outstanding_customer_balance_minor).toBe(0);

      // Un second remboursement (même 1 cent) doit être refusé : plus rien à rembourser.
      await expect(
        refundPayment.run(
          authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
            paymentId: activePaymentId,
            amountMinor: 1,
            reason: RefundReasons.CUSTOMER_REQUEST,
            clientRequestId: `e2erefundpp_full_click_second_${missionId}`,
          })
        )
      ).rejects.toThrow();

      // ===== RÉCONCILIATION : injecte paiement + payout + refund provider =====
      providerPayments.push({
        providerPaymentIntentId: paymentAfterFullRefund.data()!.provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });
      providerPayouts.push({
        providerPayoutId: payoutAfter.provider_payout_id as string,
        connectedAccountId: payoutAfter.connected_account_id as string,
        amountMinor: payoutAfter.amount_minor as number,
        status: "paid",
        createdAtMillis: Date.now(),
      });
      providerRefunds.push({
        providerRefundId: refundData.provider_refund_id as string,
        providerPaymentIntentId: paymentAfterFullRefund.data()!.provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });

      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", {
          periodStartMillis: Date.now() - 3600 * 1000,
          periodEndMillis: Date.now() + 3600 * 1000,
        })
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) =>
          a.mission_id === missionId ||
          a.payment_id === activePaymentId ||
          a.payout_id === payoutId ||
          a.refund_id === refundResult.refundId
      );
      expect(relevantAnomalies).toHaveLength(0);
    }
  );

  it(
    "SCÉNARIO 3 — DOUBLE REFUND (même requestKey) après payout PAID : idempotent, " +
      "UN SEUL appel provider, UN SEUL RefundDoc, UN SEUL ledger compensatoire",
    async () => {
      const { missionId, activePaymentId, amountCapturedMinor, payoutId } = await runToPaidPayout(fakeProvider);
      currentMissionId = missionId;
      currentPayoutId = payoutId;

      const refundSpy = jest.spyOn(fakeProvider, "refundPayment");
      const partialAmountMinor = Math.floor(amountCapturedMinor * 0.25);

      const refundRequest = authedRequest<RefundPaymentRequest>(CUSTOMER_ID, "customer", {
        paymentId: activePaymentId,
        amountMinor: partialAmountMinor,
        reason: RefundReasons.CUSTOMER_REQUEST,
        clientRequestId: `e2erefundpp_double_click_${missionId}`,
      });

      const first = await refundPayment.run(refundRequest);
      expect(first.success).toBe(true);
      expect(first.alreadyProcessed).toBeFalsy();

      // 🔒 Même requestKey rejouée (retry réseau simulé) : DOIT renvoyer le
      // résultat déjà obtenu, JAMAIS un second appel provider, JAMAIS un
      // second RefundDoc, JAMAIS une seconde entrée ledger.
      const second = await refundPayment.run(refundRequest);
      expect(second.success).toBe(true);
      expect(second.alreadyProcessed).toBe(true);
      expect(second.refundId).toBe(first.refundId);

      expect(refundSpy).toHaveBeenCalledTimes(1);

      const paymentAfter = (await db.collection("payments").doc(activePaymentId).get()).data()!;
      expect(paymentAfter.amount_refunded_minor).toBe(partialAmountMinor); // pas 2x

      const refundsSnap = await db.collection("refunds").where("payment_id", "==", activePaymentId).get();
      expect(refundsSnap.docs.length).toBe(1); // un SEUL RefundDoc

      const ledgerRefundSnap = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", missionId)
        .where("type", "==", LedgerEntryTypes.PARTIAL_REFUND)
        .get();
      expect(ledgerRefundSnap.size).toBe(1); // une SEULE entrée compensatoire, jamais deux

      // Payout historique inchangé même dans ce scénario de double appel.
      const payoutAfter = (await db.collection("driver_payouts").doc(payoutId).get()).data()!;
      expect(payoutAfter.status).toBe(PayoutStatuses.PAID);
    }
  );
});
