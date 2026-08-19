// ---------------------------------------------------------------------------
// Test d'intégration — completeDelivery (Phase 4, point 6/7/10).
//
// Couvre les 3 prédécesseurs valides (picked_up, in_transit,
// arrived_at_dropoff) -> completed, la confirmation IMMUABLE du
// financial_snapshot (pending -> confirmed), la création des 5 entrées du
// ledger avec les BONS montants/direction/party (jamais recalculés côté
// Flutter — voir point 10 du cahier des charges), l'incrément de
// completed_missions du chauffeur, et les cas négatifs : mauvais chauffeur,
// transition invalide, snapshot déjà confirmé (immutabilité), mission
// introuvable.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import { completeDelivery, CompleteDeliveryRequest } from "../../src/functions/completeDelivery";
import { admin, db } from "../../src/lib/admin";
import { LedgerEntryTypes, MissionStatuses } from "../../src/lib/types";

const MISSION_ID = "delivery_mission_001";
const DRIVER_ID = "delivery_driver_a";
const OTHER_DRIVER_ID = "delivery_driver_b";
const SNAPSHOT_ID = "delivery_snapshot_001";
const PROOF_URL = "https://storage.googleapis.com/movik-test/delivery_proofs/delivery_mission_001/proof.jpg";

function buildRequest(driverId: string, data: CompleteDeliveryRequest): CallableRequest<CompleteDeliveryRequest> {
  return {
    data,
    auth: { uid: driverId, token: {} as DecodedIdToken, rawToken: "fake-raw-token-for-emulator-test" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

async function seedMission(status: string, opts: { snapshotId?: string | null; driverId?: string } = {}): Promise<void> {
  await db.collection("delivery_requests").doc(MISSION_ID).set({
    customer_id: "delivery_customer_001",
    driver_id: opts.driverId ?? DRIVER_ID,
    status,
    item_category_key: "furniture",
    description: "Test completeDelivery.",
    required_vehicle_category: "cargoVan",
    driver_offer_amount: 85,
    customer_total: 100,
    active_financial_snapshot_id: opts.snapshotId === undefined ? SNAPSHOT_ID : opts.snapshotId,
    created_at: admin.firestore.Timestamp.now(),
  });
}

async function seedSnapshot(status: "pending" | "confirmed" = "pending"): Promise<void> {
  await db.collection("financial_snapshots").doc(SNAPSHOT_ID).set({
    snapshot_id: SNAPSHOT_ID,
    mission_id: MISSION_ID,
    customer_id: "delivery_customer_001",
    driver_id: DRIVER_ID,
    pricing_version: "TEST-PRICING-001",
    mission_base_value: 100,
    driver_offer_amount: 85,
    platform_commission_amount: 12,
    customer_service_fee: 3,
    customer_tax: 5,
    customer_total: 100,
    status,
    created_at: admin.firestore.Timestamp.now(),
    confirmed_at: status === "confirmed" ? admin.firestore.Timestamp.now() : null,
  });
}

async function seedDriverProfile(): Promise<void> {
  await db.collection("driver_profiles").doc(DRIVER_ID).set({
    uid: DRIVER_ID,
    status: "approved",
    completed_missions: 5,
    online_status: "on_mission",
  });
}

async function cleanup(): Promise<void> {
  const [ledgerEntries, events] = await Promise.all([
    db.collection("transaction_ledger").where("mission_id", "==", MISSION_ID).get(),
    db.collection("delivery_requests").doc(MISSION_ID).collection("tracking_events").get(),
  ]);
  await Promise.all([
    ...ledgerEntries.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
    db.collection("delivery_requests").doc(MISSION_ID).delete(),
    db.collection("financial_snapshots").doc(SNAPSHOT_ID).delete(),
    db.collection("driver_profiles").doc(DRIVER_ID).delete(),
  ]);
}

describe("completeDelivery — transitions valides depuis les 3 prédécesseurs autorisés", () => {
  afterEach(cleanup);

  it.each([MissionStatuses.PICKED_UP, MissionStatuses.IN_TRANSIT, MissionStatuses.ARRIVED_AT_DROPOFF])(
    "depuis '%s' -> completed réussit, confirme le snapshot et crée les 5 entrées du ledger",
    async (fromStatus) => {
      await Promise.all([seedMission(fromStatus), seedSnapshot("pending"), seedDriverProfile()]);

      const result = await completeDelivery.run(
        buildRequest(DRIVER_ID, { missionId: MISSION_ID, proofOfDeliveryUrl: PROOF_URL })
      );
      expect(result).toMatchObject({ success: true, missionId: MISSION_ID });

      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      expect(missionSnap.data()!.status).toBe(MissionStatuses.COMPLETED);
      expect(missionSnap.data()!.completed_at).not.toBeNull();
      // La preuve de livraison est dénormalisée sur le document mission pour
      // un affichage client trivial (Phase 5, partie 3).
      expect(missionSnap.data()!.proof_of_delivery_url).toBe(PROOF_URL);

      const snapshotSnap = await db.collection("financial_snapshots").doc(SNAPSHOT_ID).get();
      expect(snapshotSnap.data()!.status).toBe("confirmed");
      expect(snapshotSnap.data()!.confirmed_at).not.toBeNull();

      const ledgerEntries = await db
        .collection("transaction_ledger")
        .where("mission_id", "==", MISSION_ID)
        .get();
      expect(ledgerEntries.size).toBe(5);
      const types = ledgerEntries.docs.map((d) => d.data().type).sort();
      expect(types).toEqual(
        [
          LedgerEntryTypes.CUSTOMER_CHARGE,
          LedgerEntryTypes.PLATFORM_COMMISSION,
          LedgerEntryTypes.CUSTOMER_SERVICE_FEE,
          LedgerEntryTypes.DRIVER_EARNING,
          LedgerEntryTypes.TAX,
        ].sort()
      );
      // Toutes les entrées sont immédiatement CONFIRMED (pas de correction
      // client-side possible ensuite — voir point 10 du cahier des charges).
      expect(ledgerEntries.docs.every((d) => d.data().status === "confirmed")).toBe(true);

      // Le montant de driver_earning correspond EXACTEMENT au
      // driver_offer_amount du snapshot serveur, jamais un montant recalculé.
      const driverEarning = ledgerEntries.docs.find((d) => d.data().type === LedgerEntryTypes.DRIVER_EARNING)!;
      expect(driverEarning.data().amount).toBe(85);
      expect(driverEarning.data().party).toBe("driver");
      expect(driverEarning.data().direction).toBe("credit");

      const customerCharge = ledgerEntries.docs.find((d) => d.data().type === LedgerEntryTypes.CUSTOMER_CHARGE)!;
      expect(customerCharge.data().amount).toBe(100);
      expect(customerCharge.data().direction).toBe("debit");
      expect(customerCharge.data().party).toBe("customer");

      const driverSnap = await db.collection("driver_profiles").doc(DRIVER_ID).get();
      expect(driverSnap.data()!.completed_missions).toBe(6);
      expect(driverSnap.data()!.online_status).toBe("online");

      const events = await db
        .collection("delivery_requests")
        .doc(MISSION_ID)
        .collection("tracking_events")
        .where("event_type", "==", "delivered")
        .get();
      expect(events.size).toBe(1);
      expect(events.docs[0].data().metadata.proof_of_delivery_url).toBe(PROOF_URL);
      expect(events.docs[0].data().actor_uid).toBe(DRIVER_ID);
    }
  );
});

describe("completeDelivery — cas négatifs", () => {
  afterEach(cleanup);

  it("un chauffeur qui n'est pas celui assigné ne peut PAS confirmer la livraison", async () => {
    await Promise.all([seedMission(MissionStatuses.IN_TRANSIT), seedSnapshot("pending")]);
    await expect(
      completeDelivery.run(buildRequest(OTHER_DRIVER_ID, { missionId: MISSION_ID, proofOfDeliveryUrl: PROOF_URL }))
    ).rejects.toMatchObject({ code: "permission-denied" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.IN_TRANSIT);
  });

  it("depuis 'assigned' (avant même le ramassage) échoue avec failed-precondition", async () => {
    await Promise.all([seedMission(MissionStatuses.ASSIGNED), seedSnapshot("pending")]);
    await expect(
      completeDelivery.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID, proofOfDeliveryUrl: PROOF_URL }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("un financial_snapshot déjà 'confirmed' (double appel) est REJETÉ — immutabilité garantie", async () => {
    await Promise.all([seedMission(MissionStatuses.IN_TRANSIT), seedSnapshot("confirmed")]);
    await expect(
      completeDelivery.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID, proofOfDeliveryUrl: PROOF_URL }))
    ).rejects.toMatchObject({ code: "failed-precondition" });

    // Aucune nouvelle entrée de ledger n'a été créée par cette tentative.
    const ledgerEntries = await db
      .collection("transaction_ledger")
      .where("mission_id", "==", MISSION_ID)
      .get();
    expect(ledgerEntries.size).toBe(0);
  });

  it("aucun financial_snapshot actif rattaché à la mission échoue avec failed-precondition", async () => {
    await seedMission(MissionStatuses.IN_TRANSIT, { snapshotId: null });
    await expect(
      completeDelivery.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID, proofOfDeliveryUrl: PROOF_URL }))
    ).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("mission introuvable échoue avec not-found", async () => {
    await expect(
      completeDelivery.run(buildRequest(DRIVER_ID, { missionId: "mission_inexistante", proofOfDeliveryUrl: PROOF_URL }))
    ).rejects.toMatchObject({ code: "not-found" });
  });
});

describe("completeDelivery — preuve de livraison obligatoire (Phase 5, partie 3)", () => {
  afterEach(cleanup);

  it("proofOfDeliveryUrl manquant échoue avec invalid-argument — la mission ne devient PAS completed", async () => {
    await Promise.all([seedMission(MissionStatuses.IN_TRANSIT), seedSnapshot("pending")]);
    await expect(
      // @ts-expect-error — test volontaire d'un payload sans le champ requis, comme le ferait un client non à jour.
      completeDelivery.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID }))
    ).rejects.toMatchObject({ code: "invalid-argument" });

    const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
    expect(missionSnap.data()!.status).toBe(MissionStatuses.IN_TRANSIT);
    expect(missionSnap.data()!.proof_of_delivery_url).toBeUndefined();
  });

  it("proofOfDeliveryUrl vide (chaîne blanche) échoue avec invalid-argument", async () => {
    await Promise.all([seedMission(MissionStatuses.IN_TRANSIT), seedSnapshot("pending")]);
    await expect(
      completeDelivery.run(buildRequest(DRIVER_ID, { missionId: MISSION_ID, proofOfDeliveryUrl: "   " }))
    ).rejects.toMatchObject({ code: "invalid-argument" });
  });
});
