// ---------------------------------------------------------------------------
// MIS-C-09 (Phase 7, Bloc B) — déconnexion réseau / retry pendant la création
// de mission : preuve qu'un même `quoteId` ne peut jamais produire deux
// missions métier, même en cas de retry séquentiel OU d'appels
// STRICTEMENT concurrents (simulant deux requêtes réseau en vol simultané
// après une perte de connexion côté client).
//
// Architecture pertinente (voir createDeliveryRequest.ts) : la lecture du
// devis, la création de la mission ET le marquage `is_consumed: true` du
// devis se font dans UNE SEULE transaction Firestore
// (`db.runTransaction()`). Firestore garantit qu'entre deux transactions
// concurrentes qui lisent/écrivent le même document (`delivery_quotes/{id}`),
// au plus une seule peut committer — l'autre échoue en contention et est
// automatiquement retentée par le SDK Admin ; au second essai, elle relit
// `is_consumed: true` (déjà positionné par le gagnant) et lève
// `failed-precondition` de façon déterministe. Aucun appel à un
// PaymentProvider n'intervient à cette étape (l'autorisation de paiement
// n'a lieu qu'à `acceptDelivery()`), donc le risque MIS-C-09 à ce niveau
// est spécifiquement : double mission métier + double consommation de
// quote — pas un double paiement (qui est couvert séparément par les
// gardes de `acceptDelivery`/`createAndAuthorizeMissionPayment`, hors
// scope de ce test).
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

const CUSTOMER_ID = "misc09_customer_001";

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
  address: { line1: "1 rue Retry", city: "Montréal", postal_code: "H2X1Y1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "2 rue Cible", city: "Laval", postal_code: "H7X1Y1", lat: 45.6, lng: -73.7 },
};

const baseInput: Omit<CreateDeliveryRequestRequest, "quoteId"> = {
  itemCategoryKey: "furniture",
  description: "Canapé retry test",
  requiredVehicleCategory: "cargoVan",
  distanceKm: 12,
  estimatedDurationMinutes: 25,
  stops: [pickupStop, dropoffStop],
  customerDisplayName: "Client Retry Test",
};

async function seedQuote(quoteId: string): Promise<void> {
  const now = admin.firestore.Timestamp.now();
  await db.collection("delivery_quotes").doc(quoteId).set({
    id: quoteId,
    mission_id: null,
    customer_id: CUSTOMER_ID,
    pricing_version: "TEST-PRICING-MISC09",
    customer_total: 100,
    quote_breakdown: { customerDiscountAmount: 0 },
    created_at: now,
    expires_at: admin.firestore.Timestamp.fromMillis(now.toMillis() + 15 * 60_000),
    is_consumed: false,
  });
}

async function cleanupMission(missionId: string): Promise<void> {
  const stops = await db.collection("delivery_requests").doc(missionId).collection("stops").get();
  const events = await db.collection("delivery_requests").doc(missionId).collection("tracking_events").get();
  await Promise.all([
    ...stops.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    db.collection("delivery_requests").doc(missionId).delete(),
  ]);
}

describe("MIS-C-09 — createDeliveryRequest : idempotence sur retry / concurrence", () => {
  beforeEach(() => seedPaymentProfile());
  afterEach(async () => {
    await cleanupPaymentProfile();
  });

  async function seedPaymentProfile(): Promise<void> {
    await db.collection("payment_profiles").doc(CUSTOMER_ID).set(buildFakePaymentProfile(CUSTOMER_ID));
  }
  async function cleanupPaymentProfile(): Promise<void> {
    await db.collection("payment_profiles").doc(CUSTOMER_ID).delete();
  }

  it("Cas B — retry SÉQUENTIEL après succès réseau perdu côté client : la 2e tentative avec le même quoteId échoue proprement, une seule mission existe", async () => {
    const quoteId = "misc09_quote_seq_001";
    await seedQuote(quoteId);

    // 1er appel : réussit réellement côté serveur (le client ne l'a
    // simplement jamais VU réussir — timeout réseau simulé).
    const first = await createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId, ...baseInput }));
    expect(first.missionId).toBeTruthy();

    try {
      // 2e appel : le client, croyant que rien n'a été créé, retente avec
      // EXACTEMENT le même quoteId.
      await expect(
        createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId, ...baseInput }))
      ).rejects.toMatchObject({ code: "failed-precondition" });

      // Une seule mission a été créée pour ce quote.
      const missions = await db
        .collection("delivery_requests")
        .where("active_quote_id", "==", quoteId)
        .get();
      expect(missions.size).toBe(1);
      expect(missions.docs[0].id).toBe(first.missionId);

      // Le quote reste marqué consommé une seule fois, toujours pointé
      // vers la même mission (le gagnant).
      const quoteSnap = await db.collection("delivery_quotes").doc(quoteId).get();
      expect(quoteSnap.data()!.is_consumed).toBe(true);
      expect(quoteSnap.data()!.mission_id).toBe(first.missionId);
    } finally {
      await cleanupMission(first.missionId);
      await db.collection("delivery_quotes").doc(quoteId).delete();
    }
  });

  it("Cas C — deux requêtes STRICTEMENT CONCURRENTES avec le même quoteId : une seule mission créée, une seule consommation de quote, aucune donnée orpheline", async () => {
    const quoteId = "misc09_quote_concurrent_001";
    await seedQuote(quoteId);

    // Deux appels lancés en parallèle (Promise.allSettled), simulant deux
    // requêtes réseau en vol simultané (ex: le client retry avant que la
    // 1re réponse HTTP ne soit revenue).
    const [resultA, resultB] = await Promise.allSettled([
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId, ...baseInput })),
      createDeliveryRequest.run(buildRequest(CUSTOMER_ID, { quoteId, ...baseInput })),
    ]);

    const outcomes = [resultA, resultB];
    const fulfilled = outcomes.filter((o) => o.status === "fulfilled") as PromiseFulfilledResult<{
      missionId: string;
    }>[];
    const rejected = outcomes.filter((o) => o.status === "rejected") as PromiseRejectedResult[];

    try {
      // Exactement UN appel a réussi, l'autre a été rejeté par la
      // contrainte de transaction Firestore (contention sur le même
      // document quote -> failed-precondition au retry interne du SDK, ou
      // toute autre erreur métier — jamais deux succès).
      expect(fulfilled.length).toBe(1);
      expect(rejected.length).toBe(1);

      const winnerMissionId = fulfilled[0].value.missionId;
      expect(winnerMissionId).toBeTruthy();

      // Aucune mission fantôme créée par le perdant : exactement 1 mission
      // référence ce quoteId dans toute la collection.
      const missions = await db
        .collection("delivery_requests")
        .where("active_quote_id", "==", quoteId)
        .get();
      expect(missions.size).toBe(1);
      expect(missions.docs[0].id).toBe(winnerMissionId);

      // Le quote n'a été consommé qu'une seule fois, par le gagnant.
      const quoteSnap = await db.collection("delivery_quotes").doc(quoteId).get();
      expect(quoteSnap.data()!.is_consumed).toBe(true);
      expect(quoteSnap.data()!.mission_id).toBe(winnerMissionId);

      // Aucune donnée orpheline : les stops/tracking_events du gagnant
      // existent (intégrité), et aucune AUTRE mission (donc aucun autre
      // ensemble de stops/events) n'a été créée pour ce quote.
      const stopsSnap = await db
        .collection("delivery_requests")
        .doc(winnerMissionId)
        .collection("stops")
        .get();
      expect(stopsSnap.size).toBe(2);
    } finally {
      if (fulfilled.length > 0) {
        await cleanupMission(fulfilled[0].value.missionId);
      }
      await db.collection("delivery_quotes").doc(quoteId).delete();
    }
  });
});
