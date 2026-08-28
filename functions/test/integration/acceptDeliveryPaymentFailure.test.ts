// ---------------------------------------------------------------------------
// Test d'intégration — Phase 7, Bloc B (E2E Client, scénario MIS-C-04 :
// paiement refusé au moment de l'acceptation par le chauffeur).
//
// CONTEXTE : aucun test existant n'exerçait le chemin d'échec
// `FakePaymentProvider({ forceAuthorizeFailure: true })` à travers l'appel
// RÉEL de `acceptDelivery()` (grep exhaustif de `forceAuthorizeFailure` dans
// `test/` : seule sa définition dans `fakePaymentProvider.ts` existait, zéro
// usage). Le mécanisme de compensation (`failMissionPayment()` dans
// `paymentOrchestration.ts`) existe et est câblé depuis Phase 6, mais n'avait
// jamais été prouvé par un test réel bout-en-bout. Ce fichier comble ce trou
// de couverture (TEST → (succès attendu ici, pas de bug caché) → RETEST).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import { createDeliveryRequest, CreateDeliveryRequestRequest, StopInput } from "../../src/functions/createDeliveryRequest";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses, PaymentStatuses } from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

const CUSTOMER_ID = "payfail_customer_001";
const DRIVER_ID = "payfail_driver_001";
const PRICING_VERSION = "PAYFAIL-PRICING-001";

function authedRequest<T>(uid: string | undefined, data: T): CallableRequest<T> {
  return {
    data,
    auth: uid ? { uid, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" } : undefined,
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

async function seedApprovedDriver(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    full_name: "Chauffeur Paiement Refusé",
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.8,
    completed_missions: 1,
    created_at: admin.firestore.Timestamp.now(),
    approved_at: admin.firestore.Timestamp.now(),
    approved_by_user_id: "admin_seed",
    identity_verified: true,
    vehicle_verified: true,
    online_status: "online",
    documents_all_valid: true,
  });
}

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "1 rue Refus", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "2 rue Fin", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

async function cleanupAll(missionId: string | null): Promise<void> {
  if (!missionId) return;
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const [stops, events, snapshots, payments] = await Promise.all([
    missionRef.collection("stops").get(),
    missionRef.collection("tracking_events").get(),
    db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
    db.collection("payments").where("mission_id", "==", missionId).get(),
  ]);
  await Promise.all([
    ...stops.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    ...snapshots.docs.map((d) => d.ref.delete()),
    ...payments.docs.map((d) => d.ref.delete()),
    missionRef.delete(),
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("driver_locations").doc(DRIVER_ID).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
}


// Bloc X (X-11) — fixture standard : "Movi-K fonctionne normalement, tous les
// services critiques sont actifs" (voir test/testUtils/runtimeFlagsFixture.ts).
// Suite historique (pré-Bloc X) : ne teste PAS elle-même les kill switches.
beforeEach(async () => {
  await seedDefaultRuntimeFlagsEnabled();
});

describe("Phase 7 — Bloc B (MIS-C-04) : paiement refusé à l'acceptation", () => {
  let missionId: string | null = null;

  afterEach(async () => {
    setPaymentProviderForTesting(null);
    await cleanupAll(missionId);
    missionId = null;
  });

  it("bascule la mission en payment_failed, désassigne le chauffeur et ne crée aucun payment AUTHORIZED", async () => {
    // Provider configuré pour refuser systématiquement l'autorisation
    // (carte refusée simulée) — exerce le chemin d'échec réel.
    setPaymentProviderForTesting(
      new FakePaymentProvider({ forceAuthorizeFailure: true, failureCode: "card_declined", failureMessage: "Carte refusée (test MIS-C-04)." })
    );

    await Promise.all([
      seedPricing(),
      seedApprovedDriver(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
    ]);

    const quote = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
        vehicleCategory: "cargoVan",
        distanceKm: 12,
        estimatedDurationMinutes: 25,
      })
    );
    const created = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
        quoteId: quote.quoteId,
        itemCategoryKey: "furniture",
        description: "Test MIS-C-04 paiement refusé.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 12,
        estimatedDurationMinutes: 25,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Refus Paiement",
      })
    );
    missionId = created.missionId;
    const mid = missionId as string;

    // ---- acceptDelivery() DOIT rejeter l'appel avec failed-precondition ----
    await expect(
      acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: mid }))
    ).rejects.toMatchObject({ code: "failed-precondition" });

    // ---- Mission bascule en payment_failed, désassignée ----
    const missionSnap = await db.collection("delivery_requests").doc(mid).get();
    const mission = missionSnap.data()!;
    expect(mission.status).toBe(MissionStatuses.PAYMENT_FAILED);
    expect(mission.payment_status).toBe(PaymentStatuses.FAILED);
    expect(mission.driver_id).toBeNull();

    // ---- Le chauffeur redevient disponible (pas bloqué "on_mission" pour rien) ----
    const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
    expect(driverSnap.data()!.online_status).toBe("online");

    // ---- Aucun payment AUTHORIZED n'existe pour cette mission — le seul
    // document créé (s'il existe) doit être FAILED, jamais AUTHORIZED. ----
    const paymentsSnap = await db.collection("payments").where("mission_id", "==", mid).get();
    for (const doc of paymentsSnap.docs) {
      expect(doc.data().status).not.toBe(PaymentStatuses.AUTHORIZED);
    }

    // ---- Un event de tracking 'payment_failed' documente l'échec ----
    const eventsSnap = await db
      .collection("delivery_requests")
      .doc(mid)
      .collection("tracking_events")
      .where("event_type", "==", "payment_failed")
      .get();
    expect(eventsSnap.size).toBeGreaterThanOrEqual(1);
  });

  it("[retry après correction du moyen de paiement] le client peut soumettre une NOUVELLE demande après payment_failed (pas de blocage permanent)", async () => {
    setPaymentProviderForTesting(new FakePaymentProvider({ forceAuthorizeFailure: true }));

    await Promise.all([
      seedPricing(),
      seedApprovedDriver(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
    ]);

    const quote1 = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
        vehicleCategory: "cargoVan",
        distanceKm: 10,
        estimatedDurationMinutes: 20,
      })
    );
    const created1 = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
        quoteId: quote1.quoteId,
        itemCategoryKey: "furniture",
        description: "Première tentative (paiement refusé).",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 10,
        estimatedDurationMinutes: 20,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Retry",
      })
    );
    const firstMissionId = created1.missionId;

    await expect(
      acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: firstMissionId }))
    ).rejects.toMatchObject({ code: "failed-precondition" });

    // Le client "corrige" son moyen de paiement (provider bascule sur succès)
    // et soumet une NOUVELLE demande, indépendante de la première.
    setPaymentProviderForTesting(new FakePaymentProvider());

    const quote2 = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
        vehicleCategory: "cargoVan",
        distanceKm: 10,
        estimatedDurationMinutes: 20,
      })
    );
    const created2 = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
        quoteId: quote2.quoteId,
        itemCategoryKey: "furniture",
        description: "Deuxième tentative (paiement corrigé).",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 10,
        estimatedDurationMinutes: 20,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Retry",
      })
    );
    missionId = created2.missionId; // pour cleanup
    const secondMissionId = created2.missionId;
    expect(secondMissionId).not.toBe(firstMissionId);

    const acceptResult2 = await acceptDelivery.run(
      authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: secondMissionId })
    );
    expect(acceptResult2.success).toBe(true);
    expect(acceptResult2.paymentId).toBeTruthy();

    const secondMissionSnap = await db.collection("delivery_requests").doc(secondMissionId).get();
    expect(secondMissionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
    expect(secondMissionSnap.data()!.payment_status).toBe(PaymentStatuses.AUTHORIZED);

    // Cleanup de la première mission (échouée), non couverte par le
    // `missionId` unique du afterEach (qui ne nettoie que la seconde).
    const firstRef = db.collection("delivery_requests").doc(firstMissionId);
    const [firstEvents, firstPayments] = await Promise.all([
      firstRef.collection("tracking_events").get(),
      db.collection("payments").where("mission_id", "==", firstMissionId).get(),
    ]);
    await Promise.all([
      ...firstEvents.docs.map((d) => d.ref.delete()),
      ...firstPayments.docs.map((d) => d.ref.delete()),
      firstRef.delete(),
    ]);
  });
});
