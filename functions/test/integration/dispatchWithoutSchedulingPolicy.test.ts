// ---------------------------------------------------------------------------
// DISP-01 / DISP-02 / SEC-07 (Bloc C, PR 4 — 2026-10-28).
//
// État de prod du rapport pré-lancement : `system_config/driver_scheduling`
// ABSENT. Avant ce correctif, une mission qu'aucun chauffeur n'acceptait en
// 45 s restait `offered` pour toujours (le balayage sortait sans politique),
// le client n'était jamais informé et « Relancer la recherche » était refusé.
//
// Ces tests exercent le dispatch « immédiat » SANS politique de planification :
//   1. ronde 1 : offres créées, ronde/état/échéance posés sur la mission ;
//   2. balayage : offres échues -> `expired`, mission -> `searching_driver`,
//      puis le trigger de réouverture lance la ronde 2 ;
//   3. après MAX_DISPATCH_ROUNDS rondes : `no_driver_available`, plus d'offre ;
//   4. le client reçoit la notification « aucun chauffeur » (DISP-02) ;
//   5. « Relancer la recherche » repart à la ronde 1 ;
//   6. un chauffeur qui a refusé n'est pas re-sollicité ;
//   7. un chauffeur qui passe en ligne relance une mission épuisée (force),
//      une seule fois par minute (SEC-07, anti-rafale) ;
//   8. plafond de demandes ouvertes par client (SEC-07).
// Émulateur Firestore uniquement ; triggers invoqués via `.run(event)`.
// ---------------------------------------------------------------------------

import type { CallableRequest, Request } from "firebase-functions/v2/https";
import type { DecodedIdToken } from "firebase-admin/auth";
import type { Change, FirestoreEvent, QueryDocumentSnapshot } from "firebase-functions/v2/firestore";
import { admin, db } from "../../src/lib/admin";
import { MissionStatuses } from "../../src/lib/types";
import {
  DRIVER_RESCAN_DEBOUNCE_MS,
  MAX_DISPATCH_ROUNDS,
  NO_DRIVER_AVAILABLE,
  onDriverBecameAvailableDispatch,
  onMissionCreatedDispatch,
  onMissionReopenedDispatch,
} from "../../src/functions/dispatchMissionToDrivers";
import { retryDriverSearch, sweepDriverOffers } from "../../src/functions/driverScheduleLifecycle";
import { onMissionStatusChangeNotifyCustomer } from "../../src/functions/onMissionStatusChangeNotifyCustomer";
import {
  countOpenMissions,
  createDeliveryRequest,
  MAX_OPEN_MISSIONS_PER_CUSTOMER,
} from "../../src/functions/createDeliveryRequest";
import { seedDefaultRuntimeFlagsEnabled } from "../testUtils/runtimeFlagsFixture";

const CUSTOMER_ID = "disp01_customer";
const DRIVER_A = "disp01_driver_a";
const DRIVER_B = "disp01_driver_b";
const PREFIX = "disp01_";

function snap(data: Record<string, unknown> | undefined): QueryDocumentSnapshot {
  return { data: () => data } as unknown as QueryDocumentSnapshot;
}
function createdEvent(missionId: string, data: Record<string, unknown>) {
  return { data: snap(data), params: { missionId } } as unknown as Parameters<typeof onMissionCreatedDispatch.run>[0];
}
function updatedEvent<P extends Record<string, string>>(
  before: Record<string, unknown>, after: Record<string, unknown>, params: P, ref?: FirebaseFirestore.DocumentReference
) {
  return {
    data: { before: snap(before), after: { ...snap(after), ref } } as unknown as Change<QueryDocumentSnapshot>,
    params,
  } as unknown as FirestoreEvent<Change<QueryDocumentSnapshot> | undefined, P>;
}
function call<T>(uid: string, data: T, roles: string[] = ["customer"]): CallableRequest<T> {
  return {
    data,
    auth: { uid, token: { roles, role: roles[0] } as unknown as DecodedIdToken, rawToken: "emulator" },
    rawRequest: {} as Request,
    acceptsStreaming: false,
  };
}

function driver(id: string, overrides: Record<string, unknown> = {}) {
  return {
    uid: id, full_name: id, city: "Granby", status: "approved", service_radius_km: 40,
    accepted_vehicle_categories: ["cargoVan"], online_status: "online", documents_all_valid: true,
    identity_verified: true, vehicle_verified: true, created_at: admin.firestore.Timestamp.now(),
    current_geohash: "f25dv", // Granby
    ...overrides,
  };
}

function mission(id: string, overrides: Record<string, unknown> = {}) {
  return {
    customer_id: CUSTOMER_ID, status: MissionStatuses.SEARCHING_DRIVER, required_vehicle_category: "cargoVan",
    dispatch_zone_geohash: "f25dvk", item_category_key: "furniture", created_at: admin.firestore.Timestamp.now(),
    ...overrides,
  };
}

async function missionDoc(id: string) {
  return (await db.doc("delivery_requests/" + id).get()).data()!;
}
async function offersOf(id: string) {
  return (await db.collection("delivery_offers").where("mission_id", "==", id).get()).docs.map((d) => ({ id: d.id, ...d.data() })) as Array<Record<string, unknown> & { id: string }>;
}
async function expireAllOffers(id: string) {
  const past = admin.firestore.Timestamp.fromMillis(Date.now() - 1000);
  for (const o of await offersOf(id)) await db.doc("delivery_offers/" + o.id).update({ expires_at: past });
  await db.doc("delivery_requests/" + id).update({ dispatch_next_attempt_at: past });
}
/** Balayage puis trigger de réouverture, comme en prod (le trigger ne tourne pas sous l'émulateur). */
async function sweepAndReopen(id: string) {
  const before = await missionDoc(id);
  await sweepDriverOffers();
  const after = await missionDoc(id);
  if (before.status !== after.status) {
    await onMissionReopenedDispatch.run(updatedEvent(before, after, { missionId: id }));
  }
  return missionDoc(id);
}

async function cleanup() {
  for (const c of ["delivery_requests", "delivery_offers", "driver_profiles", "calendar_worker_state"]) {
    const docs = await db.collection(c).get();
    await Promise.all(docs.docs.filter((d) => d.id.startsWith(PREFIX) || (d.data().mission_id ?? "").startsWith(PREFIX) || c === "calendar_worker_state").map((d) => d.ref.delete()));
  }
  for (const uid of [CUSTOMER_ID, DRIVER_A, DRIVER_B]) {
    const n = await db.collection("users").doc(uid).collection("notifications").get();
    await Promise.all(n.docs.map((d) => d.ref.delete()));
  }
  await db.doc("system_config/driver_scheduling").delete();
}

beforeEach(async () => {
  await cleanup();
  await seedDefaultRuntimeFlagsEnabled();
  await db.doc("driver_profiles/" + DRIVER_A).set(driver(DRIVER_A));
});
afterAll(cleanup);

describe("DISP-01 — dispatch immédiat sans system_config/driver_scheduling", () => {
  it("ronde 1 : offre créée, mission offered avec ronde, état et échéance", async () => {
    const id = PREFIX + "round1";
    await db.doc("delivery_requests/" + id).set(mission(id));
    await onMissionCreatedDispatch.run(createdEvent(id, await missionDoc(id)));
    const m = await missionDoc(id);
    expect(m.status).toBe(MissionStatuses.OFFERED);
    expect(m).toMatchObject({ dispatch_round: 1, dispatch_state: "offered", offered_driver_ids: [DRIVER_A] });
    expect(m.dispatch_next_attempt_at).toBeInstanceOf(admin.firestore.Timestamp);
    expect(await offersOf(id)).toHaveLength(1);
  });

  it("offres échues : le balayage les expire, rouvre la mission, et la ronde 2 part", async () => {
    const id = PREFIX + "round2";
    await db.doc("delivery_requests/" + id).set(mission(id));
    await onMissionCreatedDispatch.run(createdEvent(id, await missionDoc(id)));
    await expireAllOffers(id);

    const m = await sweepAndReopen(id);
    const offers = await offersOf(id);
    expect(offers.filter((o) => o.status === "expired")).toHaveLength(1);
    expect(offers.filter((o) => o.status === "pending")).toHaveLength(1);
    expect(m).toMatchObject({ status: MissionStatuses.OFFERED, dispatch_round: 2, dispatch_state: "offered" });
  });

  it(`après ${MAX_DISPATCH_ROUNDS} rondes : no_driver_available, plus aucune offre, et le client est notifié (DISP-02)`, async () => {
    const id = PREFIX + "exhausted";
    await db.doc("delivery_requests/" + id).set(mission(id));
    await onMissionCreatedDispatch.run(createdEvent(id, await missionDoc(id)));
    for (let round = 2; round <= MAX_DISPATCH_ROUNDS; round++) {
      await expireAllOffers(id);
      expect((await sweepAndReopen(id)).dispatch_round).toBe(round);
    }
    await expireAllOffers(id);
    const before = await missionDoc(id);
    const m = await sweepAndReopen(id);
    expect(m).toMatchObject({ status: MissionStatuses.SEARCHING_DRIVER, dispatch_state: NO_DRIVER_AVAILABLE, dispatch_round: MAX_DISPATCH_ROUNDS });
    expect((await offersOf(id)).filter((o) => o.status === "pending")).toHaveLength(0);

    // Un second balayage ne relance rien et ne change rien.
    await sweepDriverOffers();
    expect((await missionDoc(id)).dispatch_round).toBe(MAX_DISPATCH_ROUNDS);

    // DISP-02 : notification client à l'entrée dans no_driver_available.
    await onMissionStatusChangeNotifyCustomer.run(updatedEvent(before, m, { missionId: id }));
    const notifs = await db.collection("users").doc(CUSTOMER_ID).collection("notifications").get();
    expect(notifs.docs.map((d) => d.data().type)).toEqual(["no_driver_available"]);
    expect(notifs.docs[0].data()).toMatchObject({ title_key: "notif_no_driver_available_title", related_mission_id: id });
    // Pas de doublon si l'état ne change pas.
    await onMissionStatusChangeNotifyCustomer.run(updatedEvent(m, { ...m, offered_until: null }, { missionId: id }));
    expect((await db.collection("users").doc(CUSTOMER_ID).collection("notifications").get()).size).toBe(1);
  });

  it("« Relancer la recherche » repart à la ronde 1 et recrée une offre", async () => {
    const id = PREFIX + "retry";
    await db.doc("delivery_requests/" + id).set(mission(id, { dispatch_round: MAX_DISPATCH_ROUNDS, dispatch_state: NO_DRIVER_AVAILABLE }));
    await expect(retryDriverSearch.run(call("someone_else", { missionId: id }))).rejects.toMatchObject({ code: "permission-denied" });
    await retryDriverSearch.run(call(CUSTOMER_ID, { missionId: id }));
    const m = await missionDoc(id);
    expect(m).toMatchObject({ status: MissionStatuses.OFFERED, dispatch_round: 1, dispatch_state: "offered" });
    expect(await offersOf(id)).toHaveLength(1);
    await expect(retryDriverSearch.run(call(CUSTOMER_ID, { missionId: id }))).rejects.toMatchObject({ code: "failed-precondition" });
  });

  it("un chauffeur qui a refusé n'est pas re-sollicité ; un autre l'est", async () => {
    const id = PREFIX + "declined";
    await db.doc("driver_profiles/" + DRIVER_B).set(driver(DRIVER_B));
    await db.doc("delivery_requests/" + id).set(mission(id));
    await onMissionCreatedDispatch.run(createdEvent(id, await missionDoc(id)));
    expect((await missionDoc(id)).offered_driver_ids).toEqual(expect.arrayContaining([DRIVER_A, DRIVER_B]));
    const a = (await offersOf(id)).find((o) => o.driver_id === DRIVER_A)!;
    await db.doc("delivery_offers/" + a.id).update({ status: "declined" });
    await expireAllOffers(id);
    const m = await sweepAndReopen(id);
    expect(m).toMatchObject({ dispatch_round: 2, offered_driver_ids: [DRIVER_B] });
  });

  it("un chauffeur qui passe en ligne relance une mission épuisée, une fois par minute (SEC-07)", async () => {
    const id = PREFIX + "online";
    await db.doc("delivery_requests/" + id).set(mission(id, { dispatch_round: MAX_DISPATCH_ROUNDS, dispatch_state: NO_DRIVER_AVAILABLE }));
    const ref = db.doc("driver_profiles/" + DRIVER_A);
    const offline = driver(DRIVER_A, { online_status: "offline" });
    const online = driver(DRIVER_A);
    await ref.set(online);
    await onDriverBecameAvailableDispatch.run(updatedEvent(offline, online, { driverId: DRIVER_A }, ref));
    expect(await missionDoc(id)).toMatchObject({ status: MissionStatuses.OFFERED, dispatch_round: MAX_DISPATCH_ROUNDS + 1 });
    const rescan = (await ref.get()).data()!.dispatch_rescan_after as FirebaseFirestore.Timestamp;
    expect(rescan.toMillis()).toBeGreaterThan(Date.now() + DRIVER_RESCAN_DEBOUNCE_MS - 5000);

    // Rafale : hors ligne / en ligne tout de suite -> aucune nouvelle relance.
    const id2 = PREFIX + "online2";
    await db.doc("delivery_requests/" + id2).set(mission(id2));
    const onlineAgain = { ...online, dispatch_rescan_after: rescan };
    await onDriverBecameAvailableDispatch.run(updatedEvent(offline, onlineAgain, { driverId: DRIVER_A }, ref));
    expect((await missionDoc(id2)).status).toBe(MissionStatuses.SEARCHING_DRIVER);
    expect(await offersOf(id2)).toHaveLength(0);
  });
});

describe("SEC-07 — plafond de demandes ouvertes par client", () => {
  it(`refuse la ${MAX_OPEN_MISSIONS_PER_CUSTOMER + 1}e demande ouverte, ignore les livraisons terminées et les tests internes`, async () => {
    const customer = PREFIX + "capped";
    for (let i = 0; i < MAX_OPEN_MISSIONS_PER_CUSTOMER; i++) {
      await db.doc(`delivery_requests/${PREFIX}open_${i}`).set(mission(`${PREFIX}open_${i}`, { customer_id: customer, status: i === 0 ? MissionStatuses.IN_TRANSIT : MissionStatuses.SEARCHING_DRIVER }));
    }
    await db.doc(`delivery_requests/${PREFIX}done`).set(mission(`${PREFIX}done`, { customer_id: customer, status: MissionStatuses.COMPLETED }));
    await db.doc(`delivery_requests/${PREFIX}internal`).set(mission(`${PREFIX}internal`, { customer_id: customer, assignment_mode: "internal_test" }));
    expect(await countOpenMissions(customer)).toBe(MAX_OPEN_MISSIONS_PER_CUSTOMER);
    await expect(createDeliveryRequest.run(call(customer, { quoteId: "q_whatever" } as never)))
      .rejects.toMatchObject({ code: "failed-precondition", message: expect.stringContaining("en cours") });
    // Une livraison de moins : la demande passe le plafond (et échoue plus loin, devis invalide/inexistant).
    await db.doc(`delivery_requests/${PREFIX}open_1`).update({ status: MissionStatuses.CANCELLED });
    const after = await createDeliveryRequest.run(call(customer, { quoteId: "q_whatever" } as never)).catch((e: unknown) => e);
    expect(after).toBeInstanceOf(Error);
    expect(String((after as Error).message)).not.toContain("en cours");
  });
});
