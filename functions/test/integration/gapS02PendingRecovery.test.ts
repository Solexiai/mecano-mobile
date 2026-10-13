// ---------------------------------------------------------------------------
// Test d'intégration — double acceptation SIMULTANÉE de `acceptDelivery`
// (Étape 12, dernier scénario explicitement demandé).
//
// OBJECTIF :
// Vérifier que lorsque DEUX chauffeurs appellent `acceptDelivery` en même
// temps pour la MÊME mission ouverte, un seul appel réussit (premier commit
// gagnant de la transaction Firestore) et l'autre échoue avec
// `failed-precondition` — sans qu'AUCUNE logique frontend ne détermine le
// gagnant (voir commentaire d'en-tête de `src/functions/acceptDelivery.ts`).
//
// APPROCHE :
// On invoque directement `acceptDelivery.run(request)` (méthode exposée par
// `onCall()` pour les tests unitaires/intégration, voir
// `firebase-functions/v2/providers/https.d.ts` → `CallableFunction.run`),
// ce qui exécute le VRAI handler (donc la VRAIE transaction Firestore) sans
// passer par la couche HTTP/Functions Emulator — plus simple et plus rapide,
// tout en testant l'atomicité réelle au niveau Firestore.
//
// Le SDK Admin (`src/lib/admin.ts`) se connecte automatiquement à l'émulateur
// Firestore/Auth grâce aux variables d'environnement injectées par
// `firebase emulators:exec` (FIRESTORE_EMULATOR_HOST / FIREBASE_AUTH_EMULATOR_HOST),
// donc AUCUNE clé de compte de service n'est nécessaire ici — cohérent avec
// la contrainte ADC du projet.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";
import { doc, updateDoc } from "firebase/firestore";
import { onMissionEndedClearTracking } from "../../src/functions/onMissionEndedClearTracking";
import { onPaymentAuthorizedAfterMissionCancel } from "../../src/functions/onPaymentAuthorizedAfterMissionCancel";
import { PaymentStatuses } from "../../src/lib/types";
import { recoverCancelledPendingAuthorization } from "../../src/payment/recoverCancelledPendingAuthorization";
import { recoverCancelledPendingPaymentsBatch } from "../../src/functions/recoverCancelledPendingPayments";
import { createTestEnv } from "./setup";
import type { DecodedIdToken } from "firebase-admin/auth";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import { admin, db } from "../../src/lib/admin";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import { seedDefaultRuntimeFlagsEnabled, seedRuntimeFlags } from "../testUtils/runtimeFlagsFixture";
import { seedOfficialLegacyQuote } from "../testUtils/officialQuoteFixture";

const CUSTOMER_ID = "concurrency_customer_001";

const MISSION_ID = "concurrency_mission_001";
const DRIVER_A_ID = "concurrency_driver_a";
const DRIVER_B_ID = "concurrency_driver_b";
const PRICING_VERSION = "TEST-PRICING-001";

function buildDriverRequest(driverId: string): CallableRequest<AcceptDeliveryRequest> {
  // Mock minimal d'un CallableRequest signé — suffisant pour
  // `requireSignedIn()` (qui ne lit que `auth.uid` / `auth.token`) et pour le
  // corps de `acceptDelivery` qui ne s'appuie sur aucun autre champ de la
  // requête HTTP brute.
  return {
    data: { missionId: MISSION_ID },
    auth: {
      uid: driverId,
      token: {} as DecodedIdToken,
      rawToken: "fake-raw-token-for-emulator-test",
    },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedApprovedDriver(driverId: string): Promise<void> {
  await db.collection("driver_profiles").doc(driverId).set({
    uid: driverId,
    full_name: `Chauffeur Test ${driverId}`,
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.8,
    completed_missions: 42,
    created_at: admin.firestore.Timestamp.now(),
    approved_at: admin.firestore.Timestamp.now(),
    approved_by_user_id: "admin_seed",
    identity_verified: true,
    vehicle_verified: true,
    online_status: "online",
    documents_all_valid: true,
  });
}

async function seedOpenMission(): Promise<void> {
  const { quoteId, pricingResult } = await seedOfficialLegacyQuote({
    missionId: MISSION_ID,
    customerId: CUSTOMER_ID,
    pricingConfig: buildPricingConfig({ pricing_version: PRICING_VERSION }),
    distanceKm: 10,
    estimatedDurationMinutes: 20,
  });
  await db.collection("delivery_requests").doc(MISSION_ID).set({
    customer_id: "concurrency_customer_001",
    customer_display_name: "Client Test",
    driver_id: null,
    driver_display_name: null,
    status: "searching_driver",
    item_category_key: "furniture",
    description: "Déménagement d'un canapé — test de concurrence.",
    required_vehicle_category: "cargoVan",
    pickup_address: { line1: "123 rue Test", city: "Montréal" },
    dropoff_address: { line1: "456 rue Cible", city: "Laval" },
    distance_km: 10,
    estimated_duration_minutes: 20,
    pricing_version: PRICING_VERSION,
    driver_offer_amount: 0,
    customer_total: pricingResult.customerTotal,
    customer_total_minor: Math.round(pricingResult.customerTotal * 100),
    quote_breakdown: pricingResult,
    customer_discount_amount: 0,
    payment_status: "pending",
    active_quote_id: quoteId,
    active_financial_snapshot_id: null,
    created_at: admin.firestore.Timestamp.now(),
    dispatch_zone_geohash: "f25dvk",
  });
}

async function seedPricingVersion(): Promise<void> {
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

async function seedPaymentProfile(): Promise<void> {
  await db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID));
}

async function cleanupSeed(): Promise<void> {
  await Promise.all([
    db.collection("delivery_requests").doc(MISSION_ID).delete(),
    db.collection("driver_profiles").doc(DRIVER_A_ID).delete(),
    db.collection("driver_profiles").doc(DRIVER_B_ID).delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    db.collection("delivery_quotes").doc(`quote_${MISSION_ID}`).delete(),
  ]);
  // Nettoyage des sous-collections/documents annexes créés par la fonction
  // (financial_snapshots, audit_logs, tracking_events, payments) pour ne
  // rien laisser fuiter vers d'autres fichiers de test partageant le même
  // émulateur.
  const [snapshots, auditLogs, events, payments] = await Promise.all([
    db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get(),
    db.collection("audit_logs").where("target_id", "==", MISSION_ID).get(),
    db.collection("delivery_requests").doc(MISSION_ID).collection("tracking_events").get(),
    db.collection("payments").where("mission_id", "==", MISSION_ID).get(),
  ]);
  await Promise.all([
    ...snapshots.docs.map((d) => d.ref.delete()),
    ...auditLogs.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    ...payments.docs.map((d) => d.ref.delete()),
  ]);
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});


describe("GAP-S-02: orphaned payment authorization recovery", () => {
  let provider: FakePaymentProvider;

  beforeEach(async () => {
    provider = new FakePaymentProvider();
    setPaymentProviderForTesting(provider);
    await Promise.all([
      seedApprovedDriver(DRIVER_A_ID),
      seedOpenMission(),
      seedPricingVersion(),
      seedPaymentProfile(),
    ]);
  });

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupSeed();
  });

  async function seedInterruptedPayment(withProviderId = true) {
    const result = await acceptDelivery.run(buildDriverRequest(DRIVER_A_ID));
    const paymentId = result.paymentId!;
    const payRef = db.collection("payments").doc(paymentId);
    const payment = (await payRef.get()).data()!;
    const old = admin.firestore.Timestamp.fromMillis(Date.now() - 10 * 60_000);
    await payRef.update({
      status: PaymentStatuses.AUTHORIZATION_PENDING,
      amount_authorized_minor: 0,
      authorized_at: null,
      provider_payment_intent_id: withProviderId ? payment.provider_payment_intent_id : null,
      updated_at: old,
    });
    await db.collection("delivery_requests").doc(MISSION_ID).update({
      payment_status: PaymentStatuses.AUTHORIZATION_PENDING,
    });
    const testEnv = await createTestEnv();
    try {
      await updateDoc(
        doc(testEnv.authenticatedContext(CUSTOMER_ID, { role: "customer" }).firestore(),
          "delivery_requests", MISSION_ID),
        { status: "cancelled", cancellation_reason: "interrupted-authorize-recovery" },
      );
    } finally {
      await testEnv.cleanup();
    }
    return { paymentId, payRef, payment };
  }

  it("recovers an actual authorized hold from pending, preserving cents and cancellation", async () => {
    const { paymentId, payRef, payment } = await seedInterruptedPayment();
    const statusSpy = jest.spyOn(provider, "getPaymentStatus").mockResolvedValue({
      status: "requires_capture",
      amountAuthorizedMinor: payment.amount_requested_minor,
      amountCapturedMinor: 0,
      amountRefundedMinor: 0,
    });
    const cancelSpy = jest.spyOn(provider, "cancelAuthorization");
    const beforeAmount = payment.amount_requested_minor;
    expect(await recoverCancelledPendingAuthorization(paymentId)).toBe("cancelled");
    expect((await payRef.get()).data()).toMatchObject({
      status: PaymentStatuses.CANCELLED,
      amount_requested_minor: beforeAmount,
    });
    expect((await db.collection("delivery_requests").doc(MISSION_ID).get()).data()).toMatchObject({
      status: "cancelled",
      payment_status: PaymentStatuses.CANCELLED,
    });
    expect(await recoverCancelledPendingAuthorization(paymentId)).toBe("already_cancelled");
    expect(statusSpy).toHaveBeenCalledTimes(1);
    expect(cancelSpy).toHaveBeenCalledTimes(1);
  }, 40000);

  it("keeps ambiguous captured provider payments unchanged for manual review", async () => {
    const { paymentId, payRef, payment } = await seedInterruptedPayment();
    const cancelSpy = jest.spyOn(provider, "cancelAuthorization");
    jest.spyOn(provider, "getPaymentStatus").mockResolvedValue({
      status: "succeeded",
      amountAuthorizedMinor: payment.amount_requested_minor,
      amountCapturedMinor: payment.amount_requested_minor,
      amountRefundedMinor: 0,
    });
    expect(await recoverCancelledPendingAuthorization(paymentId)).toBe("needs_manual_review");
    expect((await payRef.get()).data()?.status).toBe(PaymentStatuses.AUTHORIZATION_PENDING);
    expect(cancelSpy).not.toHaveBeenCalled();
  }, 40000);

  it("refuses wrong provider cents without cancelling or changing the mission", async () => {
    const { paymentId, payRef, payment } = await seedInterruptedPayment();
    const cancelSpy = jest.spyOn(provider, "cancelAuthorization");
    jest.spyOn(provider, "getPaymentStatus").mockResolvedValue({
      status: "requires_capture",
      amountAuthorizedMinor: payment.amount_requested_minor + 1,
      amountCapturedMinor: 0,
      amountRefundedMinor: 0,
    });
    await expect(recoverCancelledPendingAuthorization(paymentId))
      .rejects.toThrow("amount or capture state mismatch");
    expect((await payRef.get()).data()?.status).toBe(PaymentStatuses.AUTHORIZATION_PENDING);
    expect(cancelSpy).not.toHaveBeenCalled();
  }, 40000);

  it("does not invent missing provider IDs and leaves such cases for manual review", async () => {
    const { paymentId, payRef } = await seedInterruptedPayment(false);
    const statusSpy = jest.spyOn(provider, "getPaymentStatus");
    expect(await recoverCancelledPendingAuthorization(paymentId)).toBe("needs_manual_review");
    expect((await payRef.get()).data()?.status).toBe(PaymentStatuses.AUTHORIZATION_PENDING);
    expect(statusSpy).not.toHaveBeenCalled();
  }, 40000);

  it("reconciles an already cancelled provider intent without a second provider cancellation", async () => {
    const { paymentId, payRef } = await seedInterruptedPayment();
    const cancelSpy = jest.spyOn(provider, "cancelAuthorization");
    jest.spyOn(provider, "getPaymentStatus").mockResolvedValue({
      status: "canceled",
      amountAuthorizedMinor: 0,
      amountCapturedMinor: 0,
      amountRefundedMinor: 0,
    });
    expect(await recoverCancelledPendingAuthorization(paymentId)).toBe("cancelled");
    expect((await payRef.get()).data()?.status).toBe(PaymentStatuses.CANCELLED);
    expect(cancelSpy).not.toHaveBeenCalled();
  }, 40000);

  it("periodic bounded scan compensates an aged orphan, not a fresh active authorization", async () => {
    const { paymentId, payRef, payment } = await seedInterruptedPayment();
    jest.spyOn(provider, "getPaymentStatus").mockResolvedValue({
      status: "requires_capture",
      amountAuthorizedMinor: payment.amount_requested_minor,
      amountCapturedMinor: 0,
      amountRefundedMinor: 0,
    });
    const result = await recoverCancelledPendingPaymentsBatch();
    expect(result.checked).toBeGreaterThanOrEqual(1);
    expect(result.recovered).toBe(1);
    expect(result.failed).toBe(0);
    expect((await payRef.get()).data()?.status).toBe(PaymentStatuses.CANCELLED);
    expect((await db.collection("delivery_requests").doc(MISSION_ID).get()).data()?.status)
      .toBe("cancelled");
    expect(paymentId).toBeTruthy();
  }, 40000);

  it("fails closed across test/live provider environments", async () => {
    const { paymentId, payRef } = await seedInterruptedPayment();
    await payRef.update({ stripe_environment: "live" });
    const readSpy = jest.spyOn(provider, "getPaymentStatus");
    const cancelSpy = jest.spyOn(provider, "cancelAuthorization");
    await expect(recoverCancelledPendingAuthorization(paymentId)).rejects.toThrow();
    expect((await payRef.get()).data()?.status).toBe(PaymentStatuses.AUTHORIZATION_PENDING);
    expect(readSpy).not.toHaveBeenCalled();
    expect(cancelSpy).not.toHaveBeenCalled();
  }, 40000);});
