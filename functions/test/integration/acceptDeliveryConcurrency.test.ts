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
import type { DecodedIdToken } from "firebase-admin/auth";
import { acceptDelivery, AcceptDeliveryRequest } from "../../src/functions/acceptDelivery";
import { admin, db } from "../../src/lib/admin";
import { buildPricingConfig } from "../unit/fixtures";

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
    customer_total: 0,
    customer_discount_amount: 0,
    payment_status: "pending",
    active_quote_id: null,
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

async function cleanupSeed(): Promise<void> {
  await Promise.all([
    db.collection("delivery_requests").doc(MISSION_ID).delete(),
    db.collection("driver_profiles").doc(DRIVER_A_ID).delete(),
    db.collection("driver_profiles").doc(DRIVER_B_ID).delete(),
    db.collection("pricing_versions").doc(PRICING_VERSION).delete(),
  ]);
  // Nettoyage des sous-collections/documents annexes créés par la fonction
  // (financial_snapshots, audit_logs, tracking_events) pour ne rien laisser
  // fuiter vers d'autres fichiers de test partageant le même émulateur.
  const [snapshots, auditLogs, events] = await Promise.all([
    db.collection("financial_snapshots").where("mission_id", "==", MISSION_ID).get(),
    db.collection("audit_logs").where("target_id", "==", MISSION_ID).get(),
    db.collection("delivery_requests").doc(MISSION_ID).collection("tracking_events").get(),
  ]);
  await Promise.all([
    ...snapshots.docs.map((d) => d.ref.delete()),
    ...auditLogs.docs.map((d) => d.ref.delete()),
    ...events.docs.map((d) => d.ref.delete()),
  ]);
}

describe("acceptDelivery — double acceptation simultanée (premier commit gagnant)", () => {
  beforeEach(async () => {
    await Promise.all([
      seedApprovedDriver(DRIVER_A_ID),
      seedApprovedDriver(DRIVER_B_ID),
      seedOpenMission(),
      seedPricingVersion(),
    ]);
  });

  afterEach(async () => {
    await cleanupSeed();
  });

  it(
    "sur deux appels acceptDelivery() concurrents pour la même mission, " +
      "un seul réussit et l'autre échoue avec failed-precondition",
    async () => {
      const [resultA, resultB] = await Promise.allSettled([
        acceptDelivery.run(buildDriverRequest(DRIVER_A_ID)),
        acceptDelivery.run(buildDriverRequest(DRIVER_B_ID)),
      ]);

      const outcomes = [resultA, resultB];
      const fulfilled = outcomes.filter((o) => o.status === "fulfilled");
      const rejected = outcomes.filter((o) => o.status === "rejected");

      // ---- Exactement un gagnant, exactement un perdant ----
      expect(fulfilled).toHaveLength(1);
      expect(rejected).toHaveLength(1);

      // ---- Le perdant reçoit précisément failed-precondition ----
      const rejection = rejected[0] as PromiseRejectedResult;
      expect(rejection.reason).toBeInstanceOf(HttpsError);
      expect((rejection.reason as HttpsError).code).toBe("failed-precondition");

      // ---- Le gagnant reçoit bien le résultat attendu de acceptDelivery ----
      const success = fulfilled[0] as PromiseFulfilledResult<{
        missionId: string;
        driverOfferAmount: number;
        snapshotId: string;
      }>;
      expect(success.value.missionId).toBe(MISSION_ID);
      expect(success.value.snapshotId).toBeTruthy();
      expect(success.value.driverOfferAmount).toBeGreaterThan(0);

      // ---- L'état final de Firestore reflète UN SEUL gagnant cohérent ----
      const missionSnap = await db.collection("delivery_requests").doc(MISSION_ID).get();
      const mission = missionSnap.data()!;
      expect(mission.status).toBe("assigned");
      expect([DRIVER_A_ID, DRIVER_B_ID]).toContain(mission.driver_id);

      // ---- Un seul financial_snapshot créé pour cette mission (pas deux) ----
      const snapshots = await db
        .collection("financial_snapshots")
        .where("mission_id", "==", MISSION_ID)
        .get();
      expect(snapshots.size).toBe(1);
      expect(snapshots.docs[0].data().driver_id).toBe(mission.driver_id);
      expect(snapshots.docs[0].data().status).toBe("pending");

      // ---- Le chauffeur gagnant seul passe en on_mission ----
      const winnerId = mission.driver_id as string;
      const loserId = winnerId === DRIVER_A_ID ? DRIVER_B_ID : DRIVER_A_ID;
      const [winnerProfile, loserProfile] = await Promise.all([
        db.collection("driver_profiles").doc(winnerId).get(),
        db.collection("driver_profiles").doc(loserId).get(),
      ]);
      expect(winnerProfile.data()!.online_status).toBe("on_mission");
      expect(loserProfile.data()!.online_status).toBe("online");

      // ---- Un seul événement driver_assigned tracé (pas de doublon) ----
      const events = await db
        .collection("delivery_requests")
        .doc(MISSION_ID)
        .collection("tracking_events")
        .where("event_type", "==", "driver_assigned")
        .get();
      expect(events.size).toBe(1);
    }
  );

  it(
    "après qu'un premier chauffeur ait déjà accepté, une acceptation " +
      "SÉQUENTIELLE ultérieure d'un second chauffeur échoue aussi " +
      "(non-régression du cas non-concurrent, hors course)",
    async () => {
      const first = await acceptDelivery.run(buildDriverRequest(DRIVER_A_ID));
      expect(first.missionId).toBe(MISSION_ID);

      await expect(acceptDelivery.run(buildDriverRequest(DRIVER_B_ID))).rejects.toMatchObject({
        code: "failed-precondition",
      });

      const snapshots = await db
        .collection("financial_snapshots")
        .where("mission_id", "==", MISSION_ID)
        .get();
      expect(snapshots.size).toBe(1);
    }
  );
});
