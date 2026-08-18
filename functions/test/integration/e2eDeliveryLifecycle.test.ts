// ---------------------------------------------------------------------------
// Test d'intégration E2E — cycle de vie COMPLET d'une livraison (Phase 4,
// points 7 et 8 du cahier des charges).
//
// Contrairement aux tests unitaires-par-fonction des autres fichiers de ce
// dossier (qui testent chaque Cloud Function isolément avec un état
// Firestore ré-injecté à chaque `it`), CE fichier exécute la VRAIE chaîne
// continue, dans l'ordre, sur la MÊME mission, exactement comme le ferait
// un client + un chauffeur réels :
//
//   calculateDeliveryQuote (client)
//   -> createDeliveryRequest (client)              => searching_driver
//   -> acceptDelivery (chauffeur)                  => assigned
//   -> updateMissionTrackingStatus(driver_to_pickup)
//   -> updateMissionTrackingStatus(arrived_at_pickup)
//   -> completePickup                              => picked_up
//   -> updateMissionTrackingStatus(in_transit)
//   -> updateMissionTrackingStatus(arrived_at_dropoff)
//   -> completeDelivery                            => completed
//
// Chaque étape est vérifiée AVANT de passer à la suivante (état Firestore
// relu à chaque palier), et l'état final vérifie à la fois :
//   - "le client voit completed" (mission.status === 'completed')
//   - "le chauffeur voit le revenu associé" (ledger DRIVER_EARNING +
//     driver_profiles.completed_missions incrémenté)
//
// Un second describe() vérifie explicitement qu'aucune étape de cette
// chaîne ne peut être sautée (ré-utilise les mêmes seeds/constructeurs de
// requêtes pour rester cohérent avec le scénario nominal ci-dessus).
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
import { admin, db } from "../../src/lib/admin";
import { LedgerEntryTypes, MissionStatuses } from "../../src/lib/types";
import { buildPricingConfig } from "../unit/fixtures";

const CUSTOMER_ID = "e2e_customer_001";
const DRIVER_ID = "e2e_driver_001";
const PRICING_VERSION = "E2E-PRICING-001";

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
    full_name: "Chauffeur E2E",
    city: "Montréal",
    status: "approved",
    service_radius_km: 25,
    accepted_vehicle_categories: ["cargoVan"],
    accepted_item_category_keys: ["furniture"],
    rating: 4.9,
    completed_missions: 3,
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
  address: { line1: "100 rue Départ", city: "Montréal", postal_code: "H1A1A1", lat: 45.5, lng: -73.6 },
};
const dropoffStop: StopInput = {
  type: "dropoff",
  address: { line1: "200 rue Arrivée", city: "Laval", postal_code: "H7A1A1", lat: 45.6, lng: -73.7 },
};

/** Rejoue les 4 premières étapes du scénario nominal et retourne le missionId. */
async function runHappyPathUntilAssigned(): Promise<string> {
  await Promise.all([seedPricing(), seedApprovedDriver()]);

  const quote = await calculateDeliveryQuote.run(
    authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
      vehicleCategory: "cargoVan",
      distanceKm: 15,
      estimatedDurationMinutes: 30,
    })
  );

  const created = await createDeliveryRequest.run(
    authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
      quoteId: quote.quoteId,
      itemCategoryKey: "furniture",
      description: "Déménagement E2E — canapé + table.",
      requiredVehicleCategory: "cargoVan",
      distanceKm: 15,
      estimatedDurationMinutes: 30,
      stops: [pickupStop, dropoffStop],
      customerDisplayName: "Client E2E",
    })
  );
  const missionId = created.missionId;

  await acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId }));

  return missionId;
}

async function cleanupAll(missionId: string | null): Promise<void> {
  if (!missionId) return;
  const missionRef = db.collection("delivery_requests").doc(missionId);
  const [stops, events, ledger, snapshots] = await Promise.all([
    missionRef.collection("stops").get(),
    missionRef.collection("tracking_events").get(),
    db.collection("transaction_ledger").where("mission_id", "==", missionId).get(),
    db.collection("financial_snapshots").where("mission_id", "==", missionId).get(),
  ]);
  await Promise.all([
    ...stops.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    ...ledger.docs.map((d) => d.ref.delete()),
    ...snapshots.docs.map((d) => d.ref.delete()),
    missionRef.delete(),
    db.collection("pricing_configs").doc("active").delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
    db.collection("audit_logs").where("target_id", "==", missionId).get().then((s) =>
      Promise.all(s.docs.map((d) => d.ref.delete()))
    ),
  ]);
  const quotes = await db.collection("delivery_quotes").where("customer_id", "==", CUSTOMER_ID).get();
  await Promise.all(quotes.docs.map((d) => d.ref.delete()));
}

describe("E2E — cycle de vie complet d'une livraison (client -> chauffeur -> completed)", () => {
  let missionId: string | null = null;

  afterEach(async () => {
    await cleanupAll(missionId);
    missionId = null;
  });

  it(
    "parcourt la chaîne réelle complète calculateDeliveryQuote -> createDeliveryRequest -> " +
      "acceptDelivery -> (4x updateMissionTrackingStatus) -> completePickup -> completeDelivery, " +
      "et vérifie l'état final côté client (completed) ET côté chauffeur (revenu au ledger)",
    async () => {
      // ---- 1. Client demande un devis ----
      await Promise.all([seedPricing(), seedApprovedDriver()]);
      const quote = await calculateDeliveryQuote.run(
        authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
          vehicleCategory: "cargoVan",
          distanceKm: 15,
          estimatedDurationMinutes: 30,
        })
      );
      expect(quote.quoteId).toBeTruthy();
      expect(quote.customerTotal).toBeGreaterThan(0);

      // ---- 2. Client confirme la mission à partir du devis ----
      const created = await createDeliveryRequest.run(
        authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
          quoteId: quote.quoteId,
          itemCategoryKey: "furniture",
          description: "Déménagement E2E — canapé + table.",
          requiredVehicleCategory: "cargoVan",
          distanceKm: 15,
          estimatedDurationMinutes: 30,
          stops: [pickupStop, dropoffStop],
          customerDisplayName: "Client E2E",
        })
      );
      missionId = created.missionId;
      // Alias local non-nullable — évite les erreurs TS2345/TS2322
      // ("string | null" non assignable) causées par le fait que TypeScript
      // ne peut pas restreindre une variable `let` de portée `describe`
      // capturée par la closure `it()` (elle est aussi réassignée dans
      // `afterEach`, donc jamais totalement narrowed à `string`).
      const id: string = created.missionId;

      let missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.SEARCHING_DRIVER);
      expect(missionSnap.data()!.driver_id).toBeNull();

      // ---- 3. Chauffeur approuvé voit la mission ouverte, l'accepte ----
      const accepted = await acceptDelivery.run(
        authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: id })
      );
      expect(accepted.success).toBe(true);
      expect(accepted.driverOfferAmount).toBeGreaterThan(0);

      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
      expect(missionSnap.data()!.driver_id).toBe(DRIVER_ID);
      const snapshotId = missionSnap.data()!.active_financial_snapshot_id as string;
      expect(snapshotId).toBeTruthy();

      // ---- 4. Chauffeur voit "Mission Active" et démarre son trajet ----
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, {
          missionId: id,
          targetStatus: MissionStatuses.DRIVER_TO_PICKUP,
        })
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.DRIVER_TO_PICKUP);

      // ---- 5. Arrivée au point de ramassage ----
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, {
          missionId: id,
          targetStatus: MissionStatuses.ARRIVED_AT_PICKUP,
        })
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ARRIVED_AT_PICKUP);

      // ---- 6. Confirmation du ramassage (fonction dédiée, pas updateMissionTrackingStatus) ----
      await completePickup.run(authedRequest<CompletePickupRequest>(DRIVER_ID, { missionId: id }));
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.PICKED_UP);

      const pickupStopSnap = await db
        .collection("delivery_requests")
        .doc(id)
        .collection("stops")
        .where("sequence", "==", 0)
        .limit(1)
        .get();
      expect(pickupStopSnap.docs[0].data().completed_at).not.toBeNull();

      // ---- 7. Départ en transport ----
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, {
          missionId: id,
          targetStatus: MissionStatuses.IN_TRANSIT,
        })
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.IN_TRANSIT);

      // ---- 8. Arrivée à destination ----
      await updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, {
          missionId: id,
          targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF,
        })
      );
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.ARRIVED_AT_DROPOFF);

      // ---- 9. Confirmation finale de la livraison ----
      const completed = await completeDelivery.run(
        authedRequest<CompleteDeliveryRequest>(DRIVER_ID, { missionId: id })
      );
      expect(completed.success).toBe(true);

      // ==== ÉTAT FINAL — "le client voit completed" ====
      missionSnap = await db.collection("delivery_requests").doc(id).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.COMPLETED);
      expect(missionSnap.data()!.completed_at).not.toBeNull();

      // ==== ÉTAT FINAL — le financial_snapshot est confirmé (immuable) ====
      const snapshotSnap = await db.collection("financial_snapshots").doc(snapshotId).get();
      expect(snapshotSnap.data()!.status).toBe("confirmed");

      // ==== ÉTAT FINAL — "le chauffeur voit le revenu associé" ====
      const ledgerEntries = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", id)
        .get();
      expect(ledgerEntries.size).toBe(5);
      const driverEarning = ledgerEntries.docs.find(
        (d) => d.data().type === LedgerEntryTypes.DRIVER_EARNING
      )!;
      expect(driverEarning.data().party).toBe("driver");
      expect(driverEarning.data().amount).toBe(snapshotSnap.data()!.driver_offer_amount);
      expect(driverEarning.data().status).toBe("confirmed");

      const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.completed_missions).toBe(4); // 3 (seed) + 1
      expect(driverSnap.data()!.online_status).toBe("online");

      // ==== Traçabilité complète : un tracking_event par étape franchie ====
      const events = await db
        .collection("delivery_requests")
        .doc(id)
        .collection("tracking_events")
        .get();
      const eventTypes = events.docs.map((d) => d.data().event_type).sort();
      expect(eventTypes).toEqual(
        [
          "mission_created",
          "driver_assigned",
          "driver_to_pickup",
          "arrived_at_pickup",
          "picked_up",
          "in_transit",
          "arrived_at_dropoff",
          "delivered",
        ].sort()
      );
    }
  );
});

describe("E2E — aucune étape de la chaîne ne peut être sautée (une fois assigned)", () => {
  let missionId: string | null = null;

  afterEach(async () => {
    await cleanupAll(missionId);
    missionId = null;
  });

  it("depuis 'assigned', tenter directement completeDelivery() (sans ramassage) échoue avec failed-precondition", async () => {
    missionId = await runHappyPathUntilAssigned();

    await expect(
      completeDelivery.run(authedRequest<CompleteDeliveryRequest>(DRIVER_ID, { missionId: missionId! }))
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const missionSnap = await db.collection("delivery_requests").doc(missionId).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.ASSIGNED);
  });

  it("depuis 'assigned', tenter directement completePickup() PUIS sauter en_transit->arrived_at_dropoff sans passer par in_transit échoue", async () => {
    missionId = await runHappyPathUntilAssigned();

    await completePickup.run(authedRequest<CompletePickupRequest>(DRIVER_ID, { missionId: missionId! }));

    // Tentative de saut : picked_up -> arrived_at_dropoff directement (sans in_transit).
    await expect(
      updateMissionTrackingStatus.run(
        authedRequest<UpdateMissionTrackingStatusRequest>(DRIVER_ID, {
          missionId: missionId!,
          targetStatus: MissionStatuses.ARRIVED_AT_DROPOFF,
        })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });

    const missionSnap = await db.collection("delivery_requests").doc(missionId).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.PICKED_UP);
  });

  it("depuis 'assigned', appeler acceptDelivery() une seconde fois (par le même ou un autre chauffeur) échoue", async () => {
    missionId = await runHappyPathUntilAssigned();

    await expect(
      acceptDelivery.run(authedRequest<AcceptDeliveryRequest>(DRIVER_ID, { missionId: missionId! }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("un devis déjà consommé par cette mission ne peut pas servir à créer une seconde mission (createDeliveryRequest rejoué)", async () => {
    await Promise.all([seedPricing(), seedApprovedDriver()]);
    const quote = await calculateDeliveryQuote.run(
      authedRequest<CalculateDeliveryQuoteRequest>(CUSTOMER_ID, {
        vehicleCategory: "cargoVan",
        distanceKm: 15,
        estimatedDurationMinutes: 30,
      })
    );
    const created = await createDeliveryRequest.run(
      authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
        quoteId: quote.quoteId,
        itemCategoryKey: "furniture",
        description: "Déménagement E2E — rejeu.",
        requiredVehicleCategory: "cargoVan",
        distanceKm: 15,
        estimatedDurationMinutes: 30,
        stops: [pickupStop, dropoffStop],
        customerDisplayName: "Client E2E",
      })
    );
    missionId = created.missionId;

    await expect(
      createDeliveryRequest.run(
        authedRequest<CreateDeliveryRequestRequest>(CUSTOMER_ID, {
          quoteId: quote.quoteId,
          itemCategoryKey: "furniture",
          description: "Deuxième tentative avec le même devis.",
          requiredVehicleCategory: "cargoVan",
          distanceKm: 15,
          estimatedDurationMinutes: 30,
          stops: [pickupStop, dropoffStop],
          customerDisplayName: "Client E2E",
        })
      )
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });
});
