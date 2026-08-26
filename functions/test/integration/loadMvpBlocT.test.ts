// ---------------------------------------------------------------------------
// Test d'intégration — BLOC T (Phase 7) : LOAD MVP.
//
// Objectif : vérifier que Movi-K supporte une charge RAISONNABLE de
// pilote/MVP sur les chemins les plus exposés à la concurrence/volume :
// création de missions en burst, tracking GPS multi-écritures, finance sur
// plusieurs missions indépendantes en parallèle.
//
// Ce N'EST PAS un test de charge à l'échelle production (voir matrice
// docs/PHASE7_QA_MATRIX.md, Bloc T) — les volumes utilisés (5-10 opérations
// concurrentes) correspondent à un pilote réaliste, pas à un stress test.
//
// T-1 (concurrence acceptation, N>2 chauffeurs) et T-5 (finance sur
// plusieurs missions indépendantes, aucune collision cross-mission) sont
// couverts ici. T-2 (burst créations) réutilise le pattern de
// createDeliveryRequest.test.ts. T-3 (tracking) réutilise le pattern de
// recordTrackingPoint.test.ts avec un volume plus élevé.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import { HttpsError } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import {
  createDeliveryRequest,
  CreateDeliveryRequestRequest,
  StopInput,
} from "../../src/functions/createDeliveryRequest";
import { recordTrackingPoint, RecordTrackingPointRequest } from "../../src/functions/recordTrackingPoint";
import { admin, db } from "../../src/lib/admin";
import { buildPricingConfig } from "../unit/fixtures";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider, buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";

const PRICING_VERSION = "TEST-PRICING-LOAD-001";

function driverRequest(driverId: string, missionId: string): CallableRequest<AcceptDeliveryRequest> {
  return {
    data: { missionId },
    auth: { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function customerRequest(
  customerId: string,
  data: CreateDeliveryRequestRequest
): CallableRequest<CreateDeliveryRequestRequest> {
  return {
    data,
    auth: { uid: customerId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function trackingRequest(driverId: string, data: RecordTrackingPointRequest): CallableRequest<RecordTrackingPointRequest> {
  return {
    data,
    auth: { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

// -----------------------------------------------------------------------------
// T-1 — CONCURRENCE ACCEPTATION avec N=5 chauffeurs (au-delà des 2 de
// acceptDeliveryConcurrency.test.ts) — vérifie que la garantie "un seul
// gagnant" tient toujours avec un nombre de concurrents réaliste pour un
// pilote (plusieurs chauffeurs à proximité d'une même zone de dispatch).
// -----------------------------------------------------------------------------
describe("BLOC T-1 — acceptDelivery avec N=5 chauffeurs concurrents (volume pilote)", () => {
  const MISSION_ID = "load_t1_mission_001";
  const CUSTOMER_ID = "load_t1_customer_001";
  const DRIVER_IDS = Array.from({ length: 5 }, (_, i) => `load_t1_driver_${i}`);

  beforeAll(() => setPaymentProviderForTesting(new FakePaymentProvider()));
  afterAll(() => setPaymentProviderForTesting(null));

  async function seedDriver(driverId: string): Promise<void> {
    await db.collection("driver_profiles").doc(driverId).set({
      uid: driverId,
      full_name: `Chauffeur Load ${driverId}`,
      city: "Montréal",
      status: "approved",
      service_radius_km: 25,
      accepted_vehicle_categories: ["cargoVan"],
      accepted_item_category_keys: ["furniture"],
      rating: 4.8,
      completed_missions: 10,
      created_at: admin.firestore.Timestamp.now(),
      approved_at: admin.firestore.Timestamp.now(),
      approved_by_user_id: "admin_seed",
      identity_verified: true,
      vehicle_verified: true,
      online_status: "online",
      documents_all_valid: true,
    });
  }

  beforeEach(async () => {
    await Promise.all([
      ...DRIVER_IDS.map(seedDriver),
      db.collection("delivery_requests").doc(MISSION_ID).set({
        customer_id: CUSTOMER_ID,
        customer_display_name: "Client Load Test",
        driver_id: null,
        driver_display_name: null,
        status: "searching_driver",
        item_category_key: "furniture",
        description: "Test de charge — 5 chauffeurs concurrents.",
        required_vehicle_category: "cargoVan",
        pickup_address: { line1: "1 rue Load", city: "Montréal" },
        dropoff_address: { line1: "2 rue Load", city: "Laval" },
        distance_km: 8,
        estimated_duration_minutes: 15,
        pricing_version: PRICING_VERSION,
        driver_offer_amount: 0,
        customer_total: 0,
        customer_discount_amount: 0,
        payment_status: "pending",
        active_quote_id: null,
        active_financial_snapshot_id: null,
        created_at: admin.firestore.Timestamp.now(),
        dispatch_zone_geohash: "f25dvk",
      }),
      db.collection("pricing_versions").doc(PRICING_VERSION).set(buildPricingConfig({ pricing_version: PRICING_VERSION })),
      db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
    ]);
  });

  afterEach(async () => {
    await Promise.all([
      ...DRIVER_IDS.map((id) => db.collection("driver_profiles").doc(id).delete()),
      db.collection("delivery_requests").doc(MISSION_ID).delete(),
      db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
    ]);
    const [snapshots, events, payments] = await Promise.all([
      db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get(),
      db.collection("delivery_requests").doc(MISSION_ID).collection("tracking_events").get(),
      db.collection("payments").where("mission_id", "==", MISSION_ID).get(),
    ]);
    await Promise.all([
      ...snapshots.docs.map((d) => d.ref.delete()),
      ...events.docs.map((d) => d.ref.delete()),
      ...payments.docs.map((d) => d.ref.delete()),
    ]);
  });

  it("exactement un gagnant parmi 5 acceptations strictement concurrentes, aucune double assignation, un seul financial_snapshot", async () => {
    const results = await Promise.allSettled(
      DRIVER_IDS.map((driverId) => acceptDelivery.run(driverRequest(driverId, MISSION_ID)))
    );

    const fulfilled = results.filter((r) => r.status === "fulfilled");
    const rejected = results.filter((r) => r.status === "rejected") as PromiseRejectedResult[];

    expect(fulfilled).toHaveLength(1);
    expect(rejected).toHaveLength(4);
    for (const r of rejected) {
      expect(r.reason).toBeInstanceOf(HttpsError);
      expect((r.reason as HttpsError).code).toBe("failed-precondition");
    }

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    const mission = missionSnap.data()!;
    expect(mission.status).toBe("assigned");
    expect(DRIVER_IDS).toContain(mission.driver_id);

    const snapshots = await db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get();
    expect(snapshots.size).toBe(1);

    // Les 4 perdants restent "online" (aucun n'a été marqué on_mission par erreur).
    const loserIds = DRIVER_IDS.filter((id) => id !== mission.driver_id);
    const loserProfiles = await Promise.all(
      loserIds.map((id) => db.collection("driver_profiles").doc(id).get())
    );
    for (const p of loserProfiles) {
      expect(p.data()!.online_status).toBe("online");
    }
  });
});

// -----------------------------------------------------------------------------
// T-2 — BURST DE CRÉATIONS INDÉPENDANTES (5 clients, 5 devis, 5 missions en
// parallèle, chacun son propre missionId auto-généré) — vérifie l'absence
// de collision d'ID et la consommation correcte de chaque devis.
// -----------------------------------------------------------------------------
describe("BLOC T-2 — createDeliveryRequest en burst (5 créations indépendantes concurrentes)", () => {
  const N = 5;
  const customerIds = Array.from({ length: N }, (_, i) => `load_t2_customer_${i}`);
  const quoteIds = Array.from({ length: N }, (_, i) => `load_t2_quote_${i}`);

  const pickupStop: StopInput = {
    type: "pickup",
    address: { line1: "1 rue Burst", city: "Montréal", postal_code: "H2X1Y1", lat: 45.5, lng: -73.6 },
  };
  const dropoffStop: StopInput = {
    type: "dropoff",
    address: { line1: "2 rue Burst", city: "Laval", postal_code: "H7X1Y1", lat: 45.6, lng: -73.7 },
  };
  const baseInput: Omit<CreateDeliveryRequestRequest, "quoteId"> = {
    itemCategoryKey: "furniture",
    description: "Test de charge — burst de créations.",
    requiredVehicleCategory: "cargoVan",
    distanceKm: 8,
    estimatedDurationMinutes: 15,
    stops: [pickupStop, dropoffStop],
    customerDisplayName: "Client Burst",
  };

  let createdMissionIds: string[] = [];

  beforeEach(async () => {
    const now = admin.firestore.Timestamp.now();
    await Promise.all(
      customerIds.map((customerId, i) =>
        Promise.all([
          db.collection("payment_profiles").doc(customerId).set(buildFakePaymentProfile(customerId)),
          db
            .collection("delivery_quotes")
            .doc(quoteIds[i])
            .set({
              id: quoteIds[i],
              mission_id: null,
              customer_id: customerId,
              pricing_version: PRICING_VERSION,
              customer_total: 100,
              quote_breakdown: { customerDiscountAmount: 0 },
              created_at: now,
              expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 15 * 60_000),
              is_consumed: false,
            }),
        ])
      )
    );
  });

  afterEach(async () => {
    await Promise.all([
      ...customerIds.map((id) => db.collection("payment_profiles").doc(id).delete()),
      ...quoteIds.map((id) => db.collection("delivery_quotes").doc(id).delete()),
      ...createdMissionIds.map(async (id) => {
        const stops = await db.collection("delivery_requests").doc(id).collection("stops").get();
        const events = await db.collection("delivery_requests").doc(id).collection("tracking_events").get();
        await Promise.all([
          ...stops.docs.map((d) => d.ref.delete()),
          ...events.docs.map((d) => d.ref.delete()),
          db.collection("delivery_requests").doc(id).delete(),
        ]);
      }),
    ]);
    createdMissionIds = [];
  });

  it("5 créations de mission strictement concurrentes réussissent toutes, aucune collision d'ID, chaque devis consommé une seule fois", async () => {
    const results = await Promise.all(
      customerIds.map((customerId, i) =>
        createDeliveryRequest.run(customerRequest(customerId, { quoteId: quoteIds[i], ...baseInput }))
      )
    );

    const missionIds = results.map((r) => r.missionId);
    createdMissionIds = missionIds;

    // Aucune collision d'ID (Firestore auto-ID garantit déjà l'unicité, mais
    // on vérifie explicitement qu'aucune mission ne s'est écrasée l'une
    // l'autre par erreur applicative).
    expect(new Set(missionIds).size).toBe(N);

    // Chaque mission correspond exactement à son client d'origine, aucun
    // devis "croisé" vers le mauvais client.
    const missionDocs = await Promise.all(
      missionIds.map((id) => db.collection("delivery_requests").doc(id).get())
    );
    missionDocs.forEach((snap, i) => {
      expect(snap.exists).toBe(true);
      expect(snap.data()!.customer_id).toBe(customerIds[i]);
      expect(snap.data()!.active_quote_id).toBe(quoteIds[i]);
    });

    // Chaque devis est marqué consommé et pointe vers LA bonne mission (pas
    // de mission perdue, pas de double consommation croisée).
    const quoteDocs = await Promise.all(
      quoteIds.map((id) => db.collection("delivery_quotes").doc(id).get())
    );
    quoteDocs.forEach((snap, i) => {
      expect(snap.data()!.is_consumed).toBe(true);
      expect(snap.data()!.mission_id).toBe(missionIds[i]);
    });
  });
});

// -----------------------------------------------------------------------------
// T-3 — TRACKING GPS : volume raisonnable de mises à jour successives pour UN
// chauffeur en mission (ex: 20 points, simulation d'une mission de ~10-20
// minutes avec une position toutes les ~30-60s) — vérifie l'absence de
// duplication et un historique de taille EXACTE (pas de croissance
// incontrôlée ni de perte de points).
// -----------------------------------------------------------------------------
describe("BLOC T-3 — recordTrackingPoint volume (20 mises à jour successives pendant une mission active)", () => {
  const DRIVER_ID = "load_t3_driver_001";
  const MISSION_ID = "load_t3_mission_001";
  const N_POINTS = 20;

  beforeEach(async () => {
    await Promise.all([
      db.collection("driver_profiles").doc(DRIVER_ID).set({
        uid: DRIVER_ID,
        full_name: "Chauffeur Load Tracking",
        status: "approved",
        online_status: "on_mission",
      }),
      db.collection("delivery_requests").doc(MISSION_ID).set({
        customer_id: "load_t3_customer_001",
        driver_id: DRIVER_ID,
        status: "in_transit",
        created_at: admin.firestore.Timestamp.now(),
      }),
    ]);
    // active_delivery_id est un champ du document driver_locations (pas un
    // paramètre de la requête onCall) — voir recordTrackingPoint.test.ts,
    // même convention de seed.
    await db.collection("driver_locations").doc(DRIVER_ID).set({ active_delivery_id: MISSION_ID }, { merge: true });
  });

  afterEach(async () => {
    const historySnap = await db.collection("driver_locations").doc(DRIVER_ID).collection("history").get();
    await Promise.all(historySnap.docs.map((d) => d.ref.delete()));
    await Promise.all([
      db.collection("driver_locations").doc(DRIVER_ID).delete(),
      db.collection("driver_profiles").doc(DRIVER_ID).delete(),
      db.collection("delivery_requests").doc(MISSION_ID).delete(),
    ]);
  });

  it("20 points GPS successifs produisent EXACTEMENT 20 documents d'historique, la position courante reflète le DERNIER point, aucune duplication", async () => {
    for (let i = 0; i < N_POINTS; i++) {
      await recordTrackingPoint.run(
        trackingRequest(DRIVER_ID, {
          latitude: 45.5 + i * 0.001,
          longitude: -73.6 - i * 0.001,
        })
      );
    }

    const historySnap = await db.collection("driver_locations").doc(DRIVER_ID).collection("history").get();
    expect(historySnap.size).toBe(N_POINTS);

    const currentSnap = await db.collection("driver_locations").doc(DRIVER_ID).get();
    const current = currentSnap.data()!;
    expect(current.latitude).toBeCloseTo(45.5 + (N_POINTS - 1) * 0.001, 6);
    expect(current.longitude).toBeCloseTo(-73.6 - (N_POINTS - 1) * 0.001, 6);

    // Le document courant est TOUJOURS unique (merge, pas de doublon de
    // document racine) — un seul document driver_locations pour ce chauffeur.
    const rootSnap = await db.collection("driver_locations").where(admin.firestore.FieldPath.documentId(), "==", DRIVER_ID).get();
    expect(rootSnap.size).toBe(1);
  });
});

// -----------------------------------------------------------------------------
// T-5 — FINANCE SUR PLUSIEURS MISSIONS INDÉPENDANTES EN PARALLÈLE : vérifie
// qu'une capture de paiement sur la mission A n'affecte JAMAIS l'état
// financier de la mission B (pas de fuite cross-mission), même lorsque les
// deux captures sont déclenchées de façon strictement concurrente. Ne
// duplique PAS financialConcurrency.test.ts (même paymentId en double) —
// teste ici des paymentId DIFFÉRENTS sur des missions DIFFÉRENTES en
// parallèle, scénario "plusieurs missions traitées en même temps" du Bloc T.
// -----------------------------------------------------------------------------
describe("BLOC T-5 — captureMissionPayment sur N missions indépendantes en parallèle (pas de collision cross-mission)", () => {
  const N = 4;
  const missionIds = Array.from({ length: N }, (_, i) => `load_t5_mission_${i}`);
  const paymentIds = Array.from({ length: N }, (_, i) => `load_t5_payment_${i}`);
  const amounts = [5000, 7500, 3000, 9000];

  beforeEach(() => setPaymentProviderForTesting(new FakePaymentProvider()));
  afterEach(() => setPaymentProviderForTesting(null));

  beforeEach(async () => {
    const now = admin.firestore.Timestamp.now();
    await Promise.all(
      missionIds.map((missionId, i) =>
        Promise.all([
          db
            .collection("payments")
            .doc(paymentIds[i])
            .set({
              payment_id: paymentIds[i],
              mission_id: missionId,
              customer_id: `load_t5_customer_${i}`,
              driver_id: `load_t5_driver_${i}`,
              status: "authorized",
              currency: "CAD",
              amount_authorized_minor: amounts[i],
              amount_captured_minor: 0,
              amount_refunded_minor: 0,
              application_fee_minor: Math.round(amounts[i] * 0.15),
              provider: "stripe",
              provider_customer_id: `fake_cus_load_t5_${i}`,
              provider_payment_method_id: `fake_pm_load_t5_${i}`,
              provider_payment_intent_id: `fake_pi_${paymentIds[i]}`,
              provider_charge_id: null,
              connected_account_id: null,
              idempotency_key: `createPayment:${paymentIds[i]}`,
              authorized_at: now,
              created_at: now,
              updated_at: now,
            }),
          db.collection("delivery_requests").doc(missionId).set({
            customer_id: `load_t5_customer_${i}`,
            driver_id: `load_t5_driver_${i}`,
            status: "in_progress",
            payment_status: "authorized",
            created_at: now,
          }),
        ])
      )
    );
  });

  afterEach(async () => {
    await Promise.all(
      missionIds.map((missionId, i) =>
        Promise.all([
          db.collection("payments").doc(paymentIds[i]).delete(),
          db.collection("delivery_requests").doc(missionId).delete(),
          db.collection("mission_financial_balance").doc(missionId).delete(),
        ])
      )
    );
  });

  it("4 captures concurrentes sur 4 missions distinctes : chaque montant capturé correspond EXACTEMENT à sa propre mission, aucune fuite cross-mission", async () => {
    // Import dynamique pour ne charger captureMissionPayment qu'ici (déjà
    // importé plus haut dans financialConcurrency.test.ts — pas de conflit,
    // simple réutilisation de la même fonction d'orchestration réelle).
    const { captureMissionPayment } = await import("../../src/payment/paymentOrchestration");

    const results = await Promise.all(
      missionIds.map((missionId, i) => captureMissionPayment(missionId, paymentIds[i]))
    );
    expect(results.every((r) => r.success)).toBe(true);

    const paymentDocs = await Promise.all(paymentIds.map((id) => db.collection("payments").doc(id).get()));
    paymentDocs.forEach((snap, i) => {
      expect(snap.data()!.status).toBe("captured");
      expect(snap.data()!.amount_captured_minor).toBe(amounts[i]);
    });

    const missionDocs = await Promise.all(missionIds.map((id) => db.collection("delivery_requests").doc(id).get()));
    missionDocs.forEach((snap) => {
      expect(snap.data()!.payment_status).toBe("captured");
    });
  });
});
