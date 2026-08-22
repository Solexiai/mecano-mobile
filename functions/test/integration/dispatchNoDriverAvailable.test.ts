// ---------------------------------------------------------------------------
// Test d'intégration — Phase 7, Bloc B (E2E Client, scénario MIS-C-02 :
// aucun chauffeur disponible au moment de la création de la mission).
//
// OBJECTIF : prouver que `dispatchMissionToDrivers.ts` (déclenché à la
// création de la mission) ne plante jamais et laisse la mission dans un état
// cohérent (`searching_driver`, aucune `delivery_offers` créée) quand zéro
// chauffeur éligible n'est trouvé dans la zone — comportement documenté dans
// le code (`if (eligible.length === 0) return;`) mais jamais prouvé par un
// test réel (grep exhaustif : aucun fichier de test n'exerçait
// `onMissionCreatedDispatch`/`dispatchMissionToDrivers` avant celui-ci).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { calculateDeliveryQuote, CalculateDeliveryQuoteRequest } from "../../src/functions/calculateDeliveryQuote";
import { createDeliveryRequest, CreateDeliveryRequestRequest, StopInput } from "../../src/functions/createDeliveryRequest";
import { onMissionCreatedDispatch } from "../../src/functions/dispatchMissionToDrivers";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses } from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";
import { buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";

const CUSTOMER_ID = "nodriver_customer_001";
const FAR_AWAY_DRIVER_ID = "nodriver_driver_far_001"; // approuvé mais hors zone
const PRICING_VERSION = "NODRIVER-PRICING-001";

function authedRequest<T>(uid: string | undefined, data: T): CallableRequest<T> {
  return {
    data,
    auth: uid ? { uid, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" } : undefined,
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function fakeCreatedEvent(missionId: string, missionData: Record<string, unknown>) {
  return {
    data: { data: () => missionData } as unknown as QueryDocumentSnapshot,
    params: { missionId },
  } as Parameters<typeof onMissionCreatedDispatch.run>[0];
}

async function seedPricing(): Promise<void> {
  await db.collection("pricing_configs").doc("active").set({ active_pricing_version: PRICING_VERSION });
  await db
    .collection("pricing_versions")
    .doc(PRICING_VERSION)
    .set(buildPricingConfig({ pricing_version: PRICING_VERSION }));
}

/** Chauffeur approuvé mais géographiquement TRÈS éloigné (autre continent)
 * pour garantir qu'aucun préfixe geohash ne coïncide avec la zone de la
 * mission — simule fidèlement "zéro chauffeur éligible dans la zone". */
async function seedFarAwayDriver(): Promise<void> {
  await db.collection("driver_profiles").doc(FAR_AWAY_DRIVER_ID).set({
    uid: FAR_AWAY_DRIVER_ID,
    full_name: "Chauffeur Très Loin",
    city: "Tokyo",
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
    // Geohash de Tokyo — préfixe totalement disjoint de Montréal (le
    // dispatch utilise un préfixe de 3 caractères, ~150km).
    current_geohash: "xn768",
  });
}

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "1 rue Aucun Chauffeur", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "2 rue Fin", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

async function cleanupAll(missionId: string | null): Promise<void> {
  if (!missionId) return;
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const [stops, offers] = await Promise.all([
    missionRef.collection("stops").get(),
    db.collection("delivery_offers").where("mission_id", "==", missionId).get(),
  ]);
  await Promise.all([
    ...stops.docs.map((d) => d.ref.delete()),
    ...offers.docs.map((d) => d.ref.delete()),
    missionRef.delete(),
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("driver_profiles").doc(FAR_AWAY_DRIVER_ID).delete(),
    db.collection("payment_profiles").doc(CUSTOMER_ID).delete(),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
}

describe("Phase 7 — Bloc B (MIS-C-02) : aucun chauffeur disponible à la création", () => {
  let missionId: string | null = null;

  afterEach(async () => {
    await cleanupAll(missionId);
    missionId = null;
  });

  it("laisse la mission en searching_driver, ne crée AUCUNE delivery_offers, ne plante pas", async () => {
    await Promise.all([
      seedPricing(),
      seedFarAwayDriver(),
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
        description: "Test MIS-C-02 aucun chauffeur disponible.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 12,
        estimatedDurationMinutes: 25,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Sans Chauffeur",
      })
    );
    missionId = created.missionId;
    const mid = missionId as string;

    const missionSnap = await db.collection("delivery_requests").doc(mid).get();
    const missionData = missionSnap.data()!;
    expect(missionData.status).toBe(MissionStatuses.SEARCHING_DRIVER);

    // Déclenche manuellement le trigger de dispatch (ne se déclenche pas
    // automatiquement sous `--only firestore,auth,storage`, pattern déjà
    // établi dans les autres tests E2E de ce dossier).
    await expect(
      onMissionCreatedDispatch.run(fakeCreatedEvent(mid, missionData))
    ).resolves.not.toThrow();

    // ---- Mission reste cohérente : toujours searching_driver, message clair ----
    const missionAfterSnap = await db.collection("delivery_requests").doc(mid).get();
    expect(missionAfterSnap.data()!.status).toBe(MissionStatuses.SEARCHING_DRIVER);
    expect(missionAfterSnap.data()!.driver_id ?? null).toBeNull();

    // ---- Aucune offre créée pour cette mission (zéro chauffeur éligible) ----
    const offersSnap = await db.collection("delivery_offers").where("mission_id", "==", mid).get();
    expect(offersSnap.size).toBe(0);
  });

  it("[régression positive] si un chauffeur éligible existe dans la zone, une offre EST créée et status -> offered", async () => {
    const NEARBY_DRIVER_ID = "nodriver_driver_nearby_001";
    await Promise.all([
      seedPricing(),
      db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID)),
      db.collection("driver_profiles").doc(NEARBY_DRIVER_ID).set({
        uid: NEARBY_DRIVER_ID,
        full_name: "Chauffeur Proche",
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
        // Même quartier que le pickup (45.5, -73.6) -> préfixe geohash commun.
        current_geohash: "f25dv",
      }),
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
        description: "Test MIS-C-02 régression positive.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 12,
        estimatedDurationMinutes: 25,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client Avec Chauffeur",
      })
    );
    missionId = created.missionId;
    const mid = missionId as string;
    const missionData = (await db.collection("delivery_requests").doc(mid).get()).data()!;

    // Vérifie que le geohash du pickup et du chauffeur partagent bien un
    // préfixe de 3 caractères (précondition du test, pas un test en soi).
    expect((missionData.dispatch_zone_geohash as string).slice(0, 3)).toBe("f25");

    await onMissionCreatedDispatch.run(fakeCreatedEvent(mid, missionData));

    const missionAfterSnap = await db.collection("delivery_requests").doc(mid).get();
    expect(missionAfterSnap.data()!.status).toBe(MissionStatuses.OFFERED);

    const offersSnap = await db.collection("delivery_offers").where("mission_id", "==", mid).get();
    expect(offersSnap.size).toBe(1);
    expect(offersSnap.docs[0].data().driver_id).toBe(NEARBY_DRIVER_ID);

    await Promise.all([
      ...offersSnap.docs.map((d) => d.ref.delete()),
      db.collection("driver_profiles").doc(NEARBY_DRIVER_ID).delete(),
    ]);
  });
});
