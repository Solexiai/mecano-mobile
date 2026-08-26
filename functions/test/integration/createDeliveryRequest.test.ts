// ---------------------------------------------------------------------------
// Test d'intégration — createDeliveryRequest (Phase 4, point 6).
//
// Couvre : création réussie à partir d'un devis valide (mission + stops +
// quote marqué consommé + tracking_event mission_created), et les cas
// négatifs — devis introuvable, devis appartenant à un autre client, devis
// déjà consommé (ré-utilisation interdite), devis expiré, stops invalides
// (moins de 2, ou stops[0] pas de type pickup).
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import {
  createDeliveryRequest,
  CreateDeliveryRequestRequest,
  StopInput,
} from "../../src/functions/createDeliveryRequest";
import { admin, db } from "../../src/lib/admin";
import { buildFakePaymentProfile } from "../testUtils/fakePaymentProvider";

const CUSTOMER_ID = "create_customer_001";
const OTHER_CUSTOMER_ID = "create_customer_002";
const QUOTE_ID = "create_quote_001";

// PHASE 6, point 1/4 — createDeliveryRequest() exige désormais un moyen de
// paiement par défaut enregistré (payment_profiles/{uid}.default_payment_method_id)
// AVANT de créer une mission. Les tests ci-dessous (qui ne testent PAS cette
// précondition elle-même) doivent donc seeder un profil de paiement valide
// pour ne pas régresser sur le comportement Phase 4 déjà validé.
async function seedPaymentProfile(customerId: string): Promise<void> {
  await db.collection("payment_profiles").doc(customerId).set(buildFakePaymentProfile(customerId));
}

async function cleanupPaymentProfile(customerId: string): Promise<void> {
  await db.collection("payment_profiles").doc(customerId).delete();
}

function buildRequest(
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

const pickupStop: StopInput = {
  type: "pickup",
  address: { line1: "123 rue Test", city: "Montréal", postal_code: "H2X1Y1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "456 rue Cible", city: "Laval", postal_code: "H7X1Y1", lat: 45.6, lng: -73.7 },
};

const baseInput: Omit<CreateDeliveryRequestRequest, "quoteId"> = {
  itemCategoryKey: "furniture",
  description: "Canapé 3 places",
  requiredVehicleCategory: "cargoVan",
  distanceKm: 12,
  estimatedDurationMinutes: 25,
  stops: [pickupStop, dropoffStop],
  customerDisplayName: "Client Test",
};

async function seedQuote(overrides: Record<string, unknown> = {}): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("delivery_quotes").doc(QUOTE_ID).set({
    id: QUOTE_ID,
    mission_id: null,
    customer_id: CUSTOMER_ID,
    pricing_version: "TEST-PRICING-001",
    customer_total: 100,
    quote_breakdown: { customerDiscountAmount: 0 },
    created_at: now,
    expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 15 * 60_000),
    is_consumed: false,
    ...overrides,
  });
}

let createdMissionIds: string[] = [];

async function cleanup(): Promise<void> {
  await db.collection("delivery_quotes").doc(QUOTE_ID).delete();
  await Promise.all(
    createdMissionIds.map(async (id) => {
      const stops = await db.collection("delivery_requests").doc(id).collection("stops").get();
      const events = await db.collection("delivery_requests").doc(id).collection("tracking_events").get();
      await Promise.all([
        ...stops.docs.map((d) => d.ref.delete()),
        ...events.docs.map((d) => d.ref.delete()),
        db.collection("delivery_requests").doc(id).delete(),
      ]);
    })
  );
  createdMissionIds = [];
}

describe("createDeliveryRequest — cas nominal", () => {
  beforeEach(() => seedPaymentProfile(CUSTOMER_ID));
  afterEach(async () => {
    await cleanup();
    await cleanupPaymentProfile(CUSTOMER_ID);
  });

  it("crée la mission à partir d'un devis valide, marque le devis consommé, crée les stops et un tracking_event", async () => {
    await seedQuote();

    const result = await createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput }));
    expect(result.missionId).toBeTruthy();
    createdMissionIds.push(result.missionId);

    const missionSnap = await db.collection("delivery_requests").doc(result.missionId).get();
    expect(missionSnap.exists).toBe(true);
    const mission = missionSnap.data()!;
    expect(mission.customer_id).toBe(CUSTOMER_ID);
    expect(mission.status).toBe("searching_driver");
    expect(mission.driver_id).toBeNull();
    expect(mission.customer_total).toBe(100);
    expect(mission.active_quote_id).toBe(QUOTE_ID);
    expect(mission.pickup_address.city).toBe("Montréal");
    expect(mission.dropoff_address.city).toBe("Laval");

    const quoteSnap = await db.collection("delivery_quotes").doc(QUOTE_ID).get();
    expect(quoteSnap.data()!.is_consumed).toBe(true);
    expect(quoteSnap.data()!.mission_id).toBe(result.missionId);

    const stopsSnap = await db.collection("delivery_requests").doc(result.missionId).collection("stops").get();
    expect(stopsSnap.size).toBe(2);

    const events = await db
      .collection("delivery_requests")
      .doc(result.missionId)
      .collection("tracking_events")
      .where("event_type", "==", "mission_created")
      .get();
    expect(events.size).toBe(1);
  });
});

describe("createDeliveryRequest — cas négatifs", () => {
  // Ces tests négatifs couvrent des rejets AUTRES que l'absence de moyen de
  // paiement (devis introuvable/expiré/consommé, stops invalides) — on
  // seed donc un profil de paiement valide pour CUSTOMER_ID et
  // OTHER_CUSTOMER_ID afin d'isoler la précondition testée par chaque `it()`
  // (voir describe dédié plus bas pour le test de la précondition
  // "moyen de paiement manquant" elle-même, Phase 6 point 1/4).
  beforeEach(() => Promise.all([seedPaymentProfile(CUSTOMER_ID), seedPaymentProfile(OTHER_CUSTOMER_ID)]));
  afterEach(async () => {
    await cleanup();
    await Promise.all([cleanupPaymentProfile(CUSTOMER_ID), cleanupPaymentProfile(OTHER_CUSTOMER_ID)]);
  });

  it("devis introuvable échoue avec not-found", async () => {
    await expect(
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId: "devis_inexistant", ...baseInput }))
    ).rejects.toMatchObject({ code: "not-found" });
  });

  it("devis appartenant à un AUTRE client échoue avec permission-denied", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(buildRequest(OTHER_CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput }))
    ).rejects.toMatchObject({ code: "permission-denied" });
  });

  it("devis DÉJÀ consommé (ré-utilisation) échoue avec failed-precondition", async () => {
    await seedQuote({ is_consumed: true, mission_id: "some_other_mission" });
    await expect(
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("devis EXPIRÉ échoue avec failed-precondition", async () => {
    const now = admin.firestore.Timestamp.now();
    await seedQuote({ expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() - 60_000) });
    await expect(
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("moins de 2 stops échoue avec invalid-argument", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(
        buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput, stops: [pickupStop] })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("stops[0] qui n'est pas de type 'pickup' échoue avec invalid-argument", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(
        buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput, stops: [dropoffStop, pickupStop] })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("quoteId manquant échoue avec invalid-argument", async () => {
    await expect(
      // @ts-expect-error payload volontairement invalide
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { ...baseInput }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  // 🔒 BLOC O — GAP COMBLÉ : distanceKm/estimatedDurationMinutes négatifs ou
  // non-numériques n'étaient validés que côté calculateDeliveryQuote()
  // (devis), jamais ici (voir createDeliveryRequest.ts). Un devis n'est
  // qu'un chiffre indicatif consommé au moment de la mission — cette
  // fonction est le SEUL point d'écriture réel de `delivery_requests`, donc
  // le seul endroit où cette donnée devient persistante et rejouée plus
  // tard par acceptDelivery() pour le recalcul serveur du prix.
  it("distanceKm négatif échoue avec invalid-argument (aucune mission créée)", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(
        buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput, distanceKm: -5 })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });

    const quoteSnap = await db.collection("delivery_quotes").doc(QUOTE_ID).get();
    expect(quoteSnap.data()!.is_consumed).toBe(false);
  });

  it("estimatedDurationMinutes négatif échoue avec invalid-argument (aucune mission créée)", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(
        buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput, estimatedDurationMinutes: -1 })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });

  it("distanceKm non-numérique (NaN) échoue avec invalid-argument", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(
        buildRequest(CUSTOMER_ID, {
          quoteId: QUOTE_ID,
          ...baseInput,
          // @ts-expect-error payload volontairement invalide
          distanceKm: "douze",
        })
      )
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});

// ---------------------------------------------------------------------------
// PHASE 6, point 1/4 — précondition « moyen de paiement sécurisé AVANT la
// création de la mission ». Décrit dans un describe() séparé (SANS
// seedPaymentProfile en beforeEach) pour isoler explicitement ce cas.
// ---------------------------------------------------------------------------
describe("createDeliveryRequest — Phase 6 : précondition moyen de paiement", () => {
  afterEach(async () => {
    await cleanup();
    await Promise.all([cleanupPaymentProfile(CUSTOMER_ID), cleanupPaymentProfile(OTHER_CUSTOMER_ID)]);
  });

  it("un client SANS aucun payment_profiles enregistré ne peut PAS créer de mission (failed-precondition)", async () => {
    await seedQuote();
    await expect(
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("un client avec un payment_profiles existant mais SANS default_payment_method_id ne peut PAS créer de mission", async () => {
    await seedQuote();
    await db.collection("payment_profiles").doc(CUSTOMER_ID).set({
      customer_id: CUSTOMER_ID,
      provider: "stripe",
      provider_customer_id: `fake_cus_${CUSTOMER_ID}`,
      default_payment_method_id: null,
      created_at: admin.firestore.Timestamp.now(),
      updated_at: admin.firestore.Timestamp.now(),
    });
    await expect(
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("un client AVEC un moyen de paiement par défaut enregistré peut créer une mission normalement", async () => {
    await seedQuote();
    await seedPaymentProfile(CUSTOMER_ID);
    const result = await createDeliveryRequest.run(
      buildRequest(CUSTOMER_ID, { quoteId: QUOTE_ID, ...baseInput })
    );
    expect(result.missionId).toBeTruthy();
    createdMissionIds.push(result.missionId);
  });
});
