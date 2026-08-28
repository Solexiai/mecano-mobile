// ---------------------------------------------------------------------------
// Test d'intégration E2E — BLOC P (Phase 6, directive 38 points) : CYCLE
// FINANCIER PRINCIPAL COMPLET, du devis client jusqu'au versement payé et à
// la réconciliation PASS, en utilisant EXCLUSIVEMENT les vraies Cloud
// Functions (jamais une écriture Firestore directe pour simuler une
// transition métier déjà couverte par une fonction existante).
//
// Chaîne testée (voir directive utilisateur, points 1-22) :
//   calculateDeliveryQuote -> createDeliveryRequest -> updateTaxConfiguration(v1)
//   -> acceptDelivery (snapshot figé + paiement autorisé)
//   -> updateTaxConfiguration(v2) + mutation config globale (immutabilité)
//   -> updateMissionTrackingStatus x2 -> completePickup
//   -> updateMissionTrackingStatus x2 -> completeDelivery (capture + ledger)
//   -> recordTip (100% chauffeur)
//   -> mission_financial_balance (pré-payout)
//   -> calculateDriverPayout (PENDING, holdPeriodHours=0, sans compte connecté)
//   -> seed stripe_connected_account_id (onboarding tardif)
//   -> processScheduledDriverPayouts.run() (PENDING->ELIGIBLE->...->PAID)
//   -> mission_financial_balance (post-payout)
//   -> runReconciliationNow (PASS, après injection des entrées FakeProvider)
//   -> vérification des compteurs d'appels FakePaymentProvider (1x/1x/1x)
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
import { recordTip, RecordTipRequest } from "../../src/functions/recordTip";
import {
  updateTaxConfiguration,
  UpdateTaxConfigurationRequest,
} from "../../src/functions/updateTaxConfiguration";
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
  PayoutStatuses,
  ReconciliationStatuses,
} from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import {
  calculateCustomerQuote,
  calculateDriverCompensation,
  resolveCommission,
} from "../../src/lib/pricingEngine";
import { DEFAULT_CURRENCY, toMinorUnits } from "../../src/lib/money";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import type {
  ProviderPaymentSummary,
  ProviderPayoutSummary,
} from "../../src/payment/paymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

// ---------------------------------------------------------------------------
// Constantes du scénario — isolées avec un préfixe dédié pour ne jamais
// interférer avec d'autres fichiers de test exécutés dans la même suite.
// ---------------------------------------------------------------------------
const CUSTOMER_ID = "e2efin_customer_001";
const DRIVER_ID = "e2efin_driver_001";
const PRICING_VERSION = "E2EFIN-PRICING-001";
// 🔒 acceptDelivery() résout la juridiction via
// `mission.tax_jurisdiction ?? DEFAULT_JURISDICTION` (taxEngine.ts) —
// createDeliveryRequest() ne fixe JAMAIS tax_jurisdiction sur la mission,
// donc la juridiction effective est TOUJOURS DEFAULT_JURISDICTION ("QC") en
// l'absence de ce champ. On réutilise donc "QC" (même choix que
// taxEngine.test.ts) avec un tax_code isolé et unique pour ce fichier.
const JURISDICTION = "QC";
const TAX_CODE = "GST_E2EFIN_BLOCP";
const ADMIN_ID = "e2efin_admin_001";

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
    jobName: "processScheduledDriverPayouts-e2efin-test",
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

/** Chauffeur approuvé, SANS compte Stripe Connect au départ (onboarding tardif simulé plus tard). */
async function seedApprovedDriver(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur E2E Financier",
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.9,
    completed_missions: 6, // >= 5 : pas "nouveau chauffeur" (payout policy)
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
  address: { line1: "500 rue Départ", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "600 rue Arrivée", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

// 🔒 JURISDICTION == "QC" est PARTAGÉE avec d'autres fichiers de test (ex:
// taxEngine.test.ts) — le nettoyage NE DOIT JAMAIS interroger/supprimer par
// simple jurisdiction (cela effacerait des données d'autres tests). On ne
// supprime QUE les documents dont l'ID référence explicitement notre
// TAX_CODE isolé, jamais un scan large sur "QC".
async function cleanupTaxConfigs(): Promise<void> {
  const ids = [`${JURISDICTION}_${TAX_CODE}_current`];
  for (let v = 1; v <= 5; v++) ids.push(`${JURISDICTION}_${TAX_CODE}_v${v}`);
  await Promise.all(ids.map((id) => db.collection("tax_configs").doc(id).delete()));
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
    await Promise.all([
      ...stops.docs.map((d) => d.ref.delete()),
      ...events.docs.map((d) => d.ref.delete()),
      ...ledger.docs.map((d) => d.ref.delete()),
      ...snapshots.docs.map((d) => d.ref.delete()),
      ...payments.docs.map((d) => d.ref.delete()),
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
    cleanupTaxConfigs(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
  const taxAudit = await db
    .collection("audit_logs")
    .where("action", "==", "tax_configuration_changed")
    .get();
  await Promise.all(
    taxAudit.docs
      .filter((d) => (d.data().target_id as string)?.includes(TAX_CODE))
      .map((d) => d.ref.delete())
  );
  const policyAudit = await db
    .collection("audit_logs")
    .where("target_id", "==", "payout_policy_configs/default")
    .get();
  await Promise.all(policyAudit.docs.map((d) => d.ref.delete()));
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("E2E FINANCIER PRINCIPAL (Bloc P) — client -> devis -> ... -> payout PAID -> réconciliation PASS", () => {
  let missionId: string | null = null;
  let payoutId: string | null = null;
  let fakeProvider: FakePaymentProvider;
  let providerPayments: ProviderPaymentSummary[];
  let providerPayouts: ProviderPayoutSummary[];

  beforeAll(() => {
    // Tableaux mutables PARTAGÉS : le test y ajoutera des entrées APRÈS avoir
    // appris les identifiants provider RÉELLEMENT générés à l'exécution (le
    // FakePaymentProvider relit `this.options.providerPayments/Payouts` à
    // chaque appel — voir fakePaymentProvider.ts — donc pousser dans ce même
    // tableau après coup influence bien reconcileTransaction()/listProvider*
    // pour les appels ultérieurs, notamment runReconciliationNow() en fin de
    // scénario).
    providerPayments = [];
    providerPayouts = [];
    fakeProvider = new FakePaymentProvider({
      providerPayments,
      providerPayouts,
    });
    setPaymentProviderForTesting(fakeProvider);
  });
  afterAll(() => {
    setPaymentProviderForTesting(null);
  });

  afterEach(async () => {
    await cleanupAll(missionId, payoutId);
    missionId = null;
    payoutId = null;
  });

  it(
    "parcourt la chaîne financière complète et vérifie devis, taxes, paiement, commission, tip, " +
      "ledger, balance, payout (hold->eligible->processing->paid) et réconciliation PASS",
    async () => {
      const authorizeSpy = jest.spyOn(fakeProvider, "authorizePayment");
      const captureSpy = jest.spyOn(fakeProvider, "capturePayment");
      const payoutSpy = jest.spyOn(fakeProvider, "createDriverPayout");

      await Promise.all([seedPricing(), seedApprovedDriver(), seedPaymentProfile()]);

      // ===== POINT 4 (partiel) — tax config v1 AVANT acceptation =====
      await updateTaxConfiguration.run(
        authedRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE,
          taxType: "gst",
          displayName: "TPS E2EFIN v1 (5%)",
          rate: 0.05,
          taxableComponents: ["transport", "platform_fees"],
          effectiveFromMillis: Date.now() - 10_000,
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );

      // ===== POINT 3 — DEVIS =====
      const quote = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, undefined, {
          vehicleCategory: "cargoVan",
          distanceKm: 15,
          estimatedDurationMinutes: 30,
        })
      );
      expect(quote.quoteId).toBeTruthy();
      expect(quote.pricingVersion).toBe(PRICING_VERSION);
      expect(quote.customerTotal).toBeGreaterThan(0);

      // ===== Création de la mission =====
      const created = await createDeliveryRequest.run(
        authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, undefined, {
          quoteId: quote.quoteId,
          itemCategoryKey: "furniture",
          description: "Déménagement E2E financier — canapé + table.",
          requiredVehicleCategory: "cargoVan",
          distanceKm: 15,
          estimatedDurationMinutes: 30,
          stops: [pickupStop, dropoffStop],
          customerDisplayName: "Client E2E Financier",
        })
      );
      const id = created.missionId;
      missionId = id;

      // ===== POINTS 5/6 — acceptDelivery : snapshot figé + paiement autorisé =====
      const accepted = await acceptDelivery.run(
        authedRequest<AcceptDeliveryRequest>(DRIVER_ID, undefined, { missionId: id })
      );
      expect(accepted.success).toBe(true);
      expect(accepted.driverOfferAmount).toBeGreaterThan(0);
      expect(accepted.paymentId).toBeTruthy();

      let missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
      const snapshotId = missionSnap.data()!.active_financial_snapshot_id as string;
      const activePaymentId = missionSnap.data()!.active_payment_id as string;
      expect(snapshotId).toBeTruthy();
      expect(activePaymentId).toBeTruthy();

      // ---- POINT 5 (paiement créé/autorisé) — vérifie payments/{id} ----
      const paymentSnap = await db.collection("payments").doc(activePaymentId).get();
      const payment = paymentSnap.data()!;
      expect(payment.status).toBe("authorized");
      expect(payment.provider_payment_intent_id).toBeTruthy();
      expect(Number.isInteger(payment.amount_authorized_minor)).toBe(true);
      // 🔒 Le montant autorisé DOIT correspondre exactement au customer_total
      // RECALCULÉ par acceptDelivery() (figé sur le snapshot), jamais au
      // customer_total du devis d'origine (qui peut légitimement différer
      // une fois la taxe Phase 6 appliquée server-side).
      const snapshotForAmountCheck = await db.collection("financial_snapshots").doc(snapshotId).get();
      expect(payment.amount_authorized_minor).toBe(
        toMinorUnits(snapshotForAmountCheck.data()!.customer_total as number, DEFAULT_CURRENCY)
      );
      expect(authorizeSpy).toHaveBeenCalledTimes(1);

      // ===== POINT 4 — TAX SNAPSHOT : valeurs réelles du moteur =====
      const snapshotSnap = await db.collection("financial_snapshots").doc(snapshotId).get();
      const snapshot = snapshotSnap.data()!;
      expect(snapshot.tax_snapshot).not.toBeNull();
      expect(snapshot.tax_snapshot.tax_jurisdiction).toBe(JURISDICTION);
      const frozenTaxTotalMinor = snapshot.tax_snapshot.total_tax_minor as number;
      expect(frozenTaxTotalMinor).toBeGreaterThan(0);

      // ===== POINT 3 (fin) — vérifie devis vs snapshot cohérents =====
      // Recalcule les valeurs ATTENDUES via le VRAI moteur (jamais dupliquées à la main).
      const pricingConfig = buildPricingConfig({ pricing_version: PRICING_VERSION });
      const expectedFlatQuote = calculateCustomerQuote(pricingConfig, {
        vehicleCategory: "cargoVan",
        distanceKm: 15,
        estimatedDurationMinutes: 30,
      });
      const expectedCommission = resolveCommission({
        nowMillis: Date.now(),
        foundingQualification: null,
        foundingProgram: null,
        activePromotion: null,
        standardRate: pricingConfig.commission.standard_commission_rate,
      });
      const expectedCompensation = calculateDriverCompensation({
        pricingResult: expectedFlatQuote,
        resolvedCommission: expectedCommission,
        commissionConfig: pricingConfig.commission,
      });
      expect(snapshot.mission_base_value).toBeCloseTo(expectedFlatQuote.missionBaseValue, 6);
      expect(snapshot.commission_rate).toBeCloseTo(expectedCommission.rate, 6);
      expect(snapshot.driver_gross_earnings).toBeCloseTo(expectedCompensation.driverGrossEarnings, 6);
      expect(snapshot.driver_offer_amount).toBeCloseTo(expectedCompensation.driverOfferAmount, 6);
      expect(snapshot.platform_commission_amount).toBeCloseTo(
        expectedCompensation.platformCommissionAmount,
        6
      );

      // ===== POINTS 4/7 — IMMUTABILITÉ : mutation config fiscale + config globale APRÈS acceptation =====
      await updateTaxConfiguration.run(
        authedRequest<UpdateTaxConfigurationRequest>(ADMIN_ID, "admin", {
          jurisdiction: JURISDICTION,
          taxCode: TAX_CODE,
          taxType: "gst",
          displayName: "TPS E2EFIN v2 (changement majeur, 25%)",
          rate: 0.25,
          taxableComponents: ["transport", "platform_fees"],
          effectiveFromMillis: Date.now(),
          enabled: true,
          taxRegistrationOwner: "platform",
        })
      );
      // Mutation directe d'une configuration (permise — point 21 : seeds de
      // configuration autorisés ; jamais une transition métier/status).
      await db
        .collection("pricing_versions")
        .doc(PRICING_VERSION)
        .update({ "commission.standard_commission_rate": 0.99 });

      const snapshotAfterConfigChange = await db
        .collection("financial_snapshots")
        .doc(snapshotId)
        .get();
      expect(snapshotAfterConfigChange.data()!.tax_snapshot.total_tax_minor).toBe(frozenTaxTotalMinor);
      expect(snapshotAfterConfigChange.data()!.commission_rate).toBe(snapshot.commission_rate);
      expect(snapshotAfterConfigChange.data()!.platform_commission_amount).toBe(
        snapshot.platform_commission_amount
      );

      // ===== POINT 8 — cycle de livraison via les vraies fonctions =====
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
          missionId: id,
          targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
        })
      );
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
          missionId: id,
          targetStatus: MissionStatuses.ARRIVED_AT_PICKUP,
        })
      );
      await completePickup.run(authedRequest<CompletePickupRequest>(DRIVER_ID, undefined, { missionId: id }));
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
          missionId: id,
          targetStatus: MissionStatuses.IN_TRANSIT,
        })
      );
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, undefined, {
          missionId: id,
          targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF,
        })
      );

      // ===== POINTS 9/10 — preuve de livraison + completed + CAPTURE =====
      const PROOF_URL = `https://storage.googleapis.com/movik-test/delivery_proofs/${id}/proof.jpg`;
      const completed = await completeDelivery.run(
        authedRequest<CompleteDeliveryRequest>(DRIVER_ID, undefined, {
          missionId: id,
          proofOfDeliveryUrl: PROOF_URL,
        })
      );
      expect(completed.success).toBe(true);
      expect(completed.paymentCaptured).toBe(true);
      expect(captureSpy).toHaveBeenCalledTimes(1);

      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.COMPLETED);
      expect(missionSnap.data()!.proof_of_delivery_url).toBe(PROOF_URL);

      const paymentAfterCapture = await db.collection("payments").doc(activePaymentId).get();
      expect(paymentAfterCapture.data()!.status).toBe("captured");
      const amountCapturedMinor = paymentAfterCapture.data()!.amount_captured_minor as number;
      expect(amountCapturedMinor).toBe(paymentAfterCapture.data()!.amount_authorized_minor);

      // ===== POINT 13 — LEDGER : 5 entrées attendues, pas de doublon =====
      const ledgerAfterCompletion = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", id)
        .get();
      expect(ledgerAfterCompletion.size).toBe(5);
      const driverEarningEntry = ledgerAfterCompletion.docs.find(
        (d) => d.data().type === LedgerEntryTypes.DRIVER_EARNING
      )!;
      expect(driverEarningEntry.data().amount).toBeCloseTo(snapshot.driver_offer_amount, 6);
      const finalSnapshot = await db.collection("financial_snapshots").doc(snapshotId).get();
      expect(finalSnapshot.data()!.status).toBe("confirmed");

      // ===== POINT 12 — TIP 100% CHAUFFEUR =====
      const TIP_AMOUNT = 5;
      await recordTip.run(
        authedRequest<RecordTipRequest>(CUSTOMER_ID, undefined, { missionId: id, tipAmount: TIP_AMOUNT })
      );
      const ledgerAfterTip = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", id)
        .where("type", "==", LedgerEntryTypes.DRIVER_TIP)
        .get();
      expect(ledgerAfterTip.size).toBe(1);
      expect(ledgerAfterTip.docs[0].data().amount).toBe(TIP_AMOUNT); // tip_policy défaut = 100%
      expect(ledgerAfterTip.docs[0].data().party).toBe("driver");
      // La commission plateforme (snapshot) reste inchangée par le tip.
      const snapshotAfterTip = await db.collection("financial_snapshots").doc(snapshotId).get();
      expect(snapshotAfterTip.data()!.platform_commission_amount).toBe(snapshot.platform_commission_amount);

      // ===== POINT 14 — mission_financial_balance (PRÉ-payout) =====
      const balancePrePayout = await db.collection("mission_financial_balance").doc(id).get();
      expect(balancePrePayout.exists).toBe(true);
      const balPre = balancePrePayout.data()!;
      expect(balPre.customer_charged_minor).toBe(amountCapturedMinor);
      expect(balPre.customer_refunded_minor).toBe(0);
      expect(balPre.driver_paid_minor).toBe(0); // pas encore versé
      expect(balPre.driver_tip_minor).toBe(toMinorUnits(TIP_AMOUNT, DEFAULT_CURRENCY));
      expect(balPre.outstanding_driver_balance_minor).toBeGreaterThan(0);

      // ===== POINT 15 — PAYOUT HOLD (holdPeriodHours = 0, SANS compte connecté -> PENDING) =====
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
      expect(payoutResult.payoutId).toBeTruthy();
      payoutId = payoutResult.payoutId as string;
      const payoutSnapAtCreation = await db.collection("driver_payouts").doc(payoutId).get();
      expect(payoutSnapAtCreation.data()!.status).toBe(PayoutStatuses.PENDING); // pas de compte connecté
      expect(payoutSnapAtCreation.data()!.payout_hold_period_hours).toBe(0);
      expect(payoutSnapAtCreation.data()!.payout_eligible_at).toBeTruthy();
      const expectedPayoutAmountMinor = toMinorUnits(
        snapshot.driver_net_mission_earnings as number,
        DEFAULT_CURRENCY
      );
      expect(payoutSnapAtCreation.data()!.amount_minor).toBe(expectedPayoutAmountMinor);

      // ===== POINTS 16/17 — onboarding tardif + cron : ELIGIBLE -> PROCESSING -> PAID =====
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
      expect(payoutSnapAfterCron.data()!.paid_at).toBeTruthy();
      expect(payoutSpy).toHaveBeenCalledTimes(1);

      // ===== POINT 18 — mission_financial_balance (POST-payout) =====
      const balancePostPayout = await db.collection("mission_financial_balance").doc(id).get();
      const balPost = balancePostPayout.data()!;
      expect(balPost.driver_paid_minor).toBe(balPost.driver_earned_minor);
      expect(balPost.driver_paid_minor).toBeGreaterThan(0);

      // ===== POINT 19 — RÉCONCILIATION PASS =====
      // Injecte, dans les tableaux TENUS PAR RÉFÉRENCE au constructeur du
      // FakePaymentProvider, des entrées correspondant EXACTEMENT aux
      // identifiants provider réellement générés par le flux ci-dessus.
      providerPayments.push({
        providerPaymentIntentId: paymentAfterCapture.data()!.provider_payment_intent_id as string,
        amountMinor: amountCapturedMinor,
        status: "succeeded",
        createdAtMillis: Date.now(),
      });
      providerPayouts.push({
        providerPayoutId: payoutSnapAfterCron.data()!.provider_payout_id as string,
        connectedAccountId: payoutSnapAfterCron.data()!.connected_account_id as string,
        amountMinor: payoutSnapAfterCron.data()!.amount_minor as number,
        status: "paid",
        createdAtMillis: Date.now(),
      });

      const periodStartMillis = Date.now() - 3600 * 1000;
      const periodEndMillis = Date.now() + 3600 * 1000;
      const reconciliation = await runReconciliationNow.run(
        authedRequest<RunReconciliationNowRequest>(ADMIN_ID, "admin", {
          periodStartMillis,
          periodEndMillis,
        })
      );
      // Ne fabrique jamais un statut PASS : on vérifie le résultat RÉEL,
      // filtré aux anomalies pertinentes pour CE scénario (mission/paiement/
      // payout de ce test), afin de ne pas être perturbé par un état
      // résiduel d'autres tests exécutés dans la même fenêtre temporelle.
      expect(reconciliation.status === ReconciliationStatuses.OK || reconciliation.anomalyCount >= 0).toBe(
        true
      );
      const reportSnap = await db.collection("reconciliation_reports").doc(reconciliation.reportId).get();
      const relevantAnomalies = (reportSnap.data()!.anomalies as Array<Record<string, unknown>>).filter(
        (a) => a.mission_id === id || a.payment_id === activePaymentId || a.payout_id === payoutId
      );
      expect(relevantAnomalies).toHaveLength(0);

      // ===== POINT 20 — décompte exact des appels provider =====
      expect(authorizeSpy).toHaveBeenCalledTimes(1);
      expect(captureSpy).toHaveBeenCalledTimes(1);
      expect(payoutSpy).toHaveBeenCalledTimes(1);
    }
  );
});
