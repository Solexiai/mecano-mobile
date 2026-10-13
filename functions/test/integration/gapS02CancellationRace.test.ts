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

describe("GAP-S-02 deterministic authorization cancellation race diagnostic", () => {
  beforeEach(async () => {
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

  it("must not authorize an already-cancelled mission after payment authorization starts", async () => {
    const provider = new FakePaymentProvider();
    let resume: () => void = () => undefined;
    let reached: () => void = () => undefined;
    const pause = new Promise<void>((resolve) => { resume = resolve; });
    const atAuthorization = new Promise<void>((resolve) => { reached = resolve; });
    const originalAuthorize = provider.authorizePayment.bind(provider);
    jest.spyOn(provider, "authorizePayment").mockImplementation(async (params) => {
      reached();
      await pause;
      return originalAuthorize(params);
    });
    setPaymentProviderForTesting(provider);

    const testEnv = await createTestEnv();
    let pending: ReturnType<typeof acceptDelivery.run> | null = null;
    try {
      pending = acceptDelivery.run(buildDriverRequest(DRIVER_A_ID));
      await atAuthorization;

      const missionRef = db.collection("delivery_requests").doc(MISSION_ID);
      const before = (await missionRef.get()).data()!;
      expect(before.status).toBe("assigned");
      expect(before.active_payment_id).toBeTruthy();
      const preparedPayment = (await db.collection("payments")
        .doc(before.active_payment_id).get()).data()!;
      expect(preparedPayment.status).toBe(PaymentStatuses.AUTHORIZATION_PENDING);
      expect(preparedPayment.provider_payment_intent_id).toBeTruthy();
      expect(preparedPayment.amount_requested_minor).toBeGreaterThan(0);
      const customer = testEnv.authenticatedContext(CUSTOMER_ID, { role: "customer" });
      await updateDoc(doc(customer.firestore(), "delivery_requests", MISSION_ID), {
        status: "cancelled",
        cancellation_reason: "diagnostic-concurrent-cancel",
      });
      const after = (await missionRef.get()).data()!;
      expect(after.status).toBe("cancelled");

      const event = {
        params: { missionId: MISSION_ID },
        data: {
          before: { data: () => before },
          after: { data: () => after },
        },
      } as Parameters<typeof onMissionEndedClearTracking.run>[0];
      await onMissionEndedClearTracking.run(event);
      resume();

      await expect(pending).rejects.toMatchObject({ code: "failed-precondition" });
      const payment = (await db.collection("payments").doc(after.active_payment_id).get()).data()!;
      const finalMission = (await missionRef.get()).data()!;
      expect(finalMission.status).toBe("cancelled");
      // Security expectation. Fails if payment authorization completes
      // after cancellation without another compensation trigger.
      expect(payment.status).not.toBe("authorized");
      expect(finalMission.payment_status).not.toBe("authorized");
    } finally {
      resume();
      if (pending) await pending.catch(() => undefined);
      await testEnv.cleanup();
    }
  }, 40000);

  it("releases a late authorized payment through the durable event and handles replay", async () => {
    const provider = new FakePaymentProvider();
    const cancellations = jest.spyOn(provider, "cancelAuthorization");
    setPaymentProviderForTesting(provider);
    const accepted = await acceptDelivery.run(buildDriverRequest(DRIVER_A_ID));
    const paymentId = accepted.paymentId!;
    const missionRef = db.collection("delivery_requests").doc(MISSION_ID);
    const testEnv = await createTestEnv();
    try {
      await updateDoc(
        doc(testEnv.authenticatedContext(CUSTOMER_ID, { role: "customer" }).firestore(),
          "delivery_requests", MISSION_ID),
        { status: "cancelled", cancellation_reason: "after-authorization" }
      );
      const before = { status: PaymentStatuses.AUTHORIZATION_PENDING };
      const after = (await db.collection("payments").doc(paymentId).get()).data()!;
      expect(after.status).toBe(PaymentStatuses.AUTHORIZED);
      const event = {
        params: { paymentId },
        data: { before: { data: () => before }, after: { data: () => after } },
      } as unknown as Parameters<typeof onPaymentAuthorizedAfterMissionCancel.run>[0];
      await onPaymentAuthorizedAfterMissionCancel.run(event);
      await onPaymentAuthorizedAfterMissionCancel.run(event);
      expect((await missionRef.get()).data()?.status).toBe("cancelled");
      expect((await db.collection("payments").doc(paymentId).get()).data()?.status)
        .toBe(PaymentStatuses.CANCELLED);
      expect(cancellations).toHaveBeenCalledTimes(1);
    } finally {
      await testEnv.cleanup();
    }
  }, 40000);

  it("retries the authorized-payment compensation after a provider cancellation failure", async () => {
    const provider = new FakePaymentProvider();
    const cancellations = jest.spyOn(provider, "cancelAuthorization")
      .mockResolvedValueOnce({ success: false, status: "failed" });
    setPaymentProviderForTesting(provider);
    const accepted = await acceptDelivery.run(buildDriverRequest(DRIVER_A_ID));
    const paymentId = accepted.paymentId!;
    const testEnv = await createTestEnv();
    try {
      await updateDoc(
        doc(testEnv.authenticatedContext(CUSTOMER_ID, { role: "customer" }).firestore(),
          "delivery_requests", MISSION_ID),
        { status: "cancelled", cancellation_reason: "provider-retry-test" }
      );
      const after = (await db.collection("payments").doc(paymentId).get()).data()!;
      const event = {
        params: { paymentId },
        data: {
          before: { data: () => ({ status: PaymentStatuses.AUTHORIZATION_PENDING }) },
          after: { data: () => after },
        },
      } as unknown as Parameters<typeof onPaymentAuthorizedAfterMissionCancel.run>[0];
      await expect(onPaymentAuthorizedAfterMissionCancel.run(event)).rejects.toThrow(
        "compensation was not confirmed"
      );
      expect((await db.collection("payments").doc(paymentId).get()).data()?.status)
        .toBe(PaymentStatuses.AUTHORIZED);
      await onPaymentAuthorizedAfterMissionCancel.run(event);
      expect((await db.collection("payments").doc(paymentId).get()).data()?.status)
        .toBe(PaymentStatuses.CANCELLED);
      expect(cancellations).toHaveBeenCalledTimes(2);
    } finally {
      await testEnv.cleanup();
    }
  }, 40000);

  it("keeps cancellation terminal when authorization is declined after the customer cancels", async () => {
    const provider = new FakePaymentProvider({ forceAuthorizeFailure: true });
    let resume: () => void = () => undefined;
    let reached: () => void = () => undefined;
    const pause = new Promise<void>((resolve) => { resume = resolve; });
    const atAuthorization = new Promise<void>((resolve) => { reached = resolve; });
    const originalAuthorize = provider.authorizePayment.bind(provider);
    jest.spyOn(provider, "authorizePayment").mockImplementation(async (params) => {
      reached();
      await pause;
      return originalAuthorize(params);
    });
    setPaymentProviderForTesting(provider);
    const testEnv = await createTestEnv();
    let pending: ReturnType<typeof acceptDelivery.run> | null = null;
    try {
      pending = acceptDelivery.run(buildDriverRequest(DRIVER_A_ID));
      await atAuthorization;
      const missionRef = db.collection("delivery_requests").doc(MISSION_ID);
      await updateDoc(
        doc(testEnv.authenticatedContext(CUSTOMER_ID, { role: "customer" }).firestore(),
          "delivery_requests", MISSION_ID),
        { status: "cancelled", cancellation_reason: "declined-during-cancel" }
      );
      const after = (await missionRef.get()).data()!;
      expect(after.status).toBe("cancelled");
      resume();
      await expect(pending).rejects.toMatchObject({ code: "failed-precondition" });
      const payment = (await db.collection("payments").doc(after.active_payment_id).get()).data()!;
      const finalMission = (await missionRef.get()).data()!;
      expect(payment.status).toBe(PaymentStatuses.FAILED);
      expect(finalMission.status).toBe("cancelled");
      expect(finalMission.payment_status).toBe(PaymentStatuses.FAILED);
    } finally {
      resume();
      if (pending) await pending.catch(() => undefined);
      await testEnv.cleanup();
    }
  }, 40000);
});
