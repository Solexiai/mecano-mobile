import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteDoc, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv } from "./setup";

let env: RulesTestEnvironment;
const DRIVER = "rka_driver";
const MISSION = "rka_mission";
const CUSTOMER = "rka_customer";
const ACTIVE = ["assigned", "driver_to_pickup", "arrived_at_pickup", "picked_up", "in_transit", "arrived_at_dropoff"];
const TERMINAL = ["completed", "cancelled", "disputed", "refunded", "delivered", "payment_failed"];

beforeAll(async () => { env = await createTestEnv(); });
afterEach(async () => { await env.clearFirestore(); });
afterAll(async () => { await env.cleanup(); });

async function seed(status = "in_transit", profileStatus = "approved", missionDriver = DRIVER) {
  await env.withSecurityRulesDisabled(async ctx => {
    const db = ctx.firestore();
    await setDoc(doc(db, "driver_profiles", DRIVER), { status: profileStatus });
    await setDoc(doc(db, "delivery_requests", MISSION), {
      driver_id: missionDriver, customer_id: CUSTOMER, status,
    });
    await setDoc(doc(db, "driver_locations", DRIVER), {
      driver_id: DRIVER, active_delivery_id: MISSION,
      latitude: 45.5, longitude: -72.5,
    });
  });
}

describe("R-K-03-A — autorité Firestore GPS", () => {
  it("refuse la création directe avec une mission appartenant à un autre chauffeur", async () => {
    await env.withSecurityRulesDisabled(async ctx => {
      await setDoc(doc(ctx.firestore(), "delivery_requests", MISSION), {
        driver_id: "rka_other_driver", customer_id: CUSTOMER, status: "in_transit",
      });
    });
    const driver = env.authenticatedContext(DRIVER, { role: "driver" });
    await assertFails(setDoc(doc(driver.firestore(), "driver_locations", DRIVER), {
      driver_id: DRIVER, active_delivery_id: MISSION, latitude: 45.5, longitude: -72.5,
    }));
  });

  it("refuse la modification directe de active_delivery_id", async () => {
    await seed();
    const driver = env.authenticatedContext(DRIVER, { role: "driver" });
    await assertFails(updateDoc(doc(driver.firestore(), "driver_locations", DRIVER), {
      active_delivery_id: "rka_forged_mission",
    }));
  });

  it("refuse la suppression directe du document et de son lien serveur", async () => {
    await seed();
    const driver = env.authenticatedContext(DRIVER, { role: "driver" });
    await assertFails(deleteDoc(doc(driver.firestore(), "driver_locations", DRIVER)));
  });

  it.each(["approved", "suspended", "rejected", "pending_review", "registration_incomplete"])(
    "refuse le contournement du callable par écriture directe : profil %s", async profile => {
      await seed("in_transit", profile);
      const driver = env.authenticatedContext(DRIVER, { role: "driver" });
      await assertFails(updateDoc(doc(driver.firestore(), "driver_locations", DRIVER), { latitude: 45.6 }));
    });

  it.each(ACTIVE)("conserve la lecture du client propriétaire en statut %s", async status => {
    await seed(status);
    const customer = env.authenticatedContext(CUSTOMER, { role: "customer" });
    const snap = await assertSucceeds(getDoc(doc(customer.firestore(), "driver_locations", DRIVER)));
    expect(snap.data()?.active_delivery_id).toBe(MISSION);
  });

  it.each(TERMINAL)("refuse la lecture courante après %s même si le lien n'est pas nettoyé", async status => {
    await seed(status);
    const customer = env.authenticatedContext(CUSTOMER, { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_locations", DRIVER)));
  });

  it("refuse la lecture courante à un autre client", async () => {
    await seed();
    const other = env.authenticatedContext("rka_other_customer", { role: "customer" });
    await assertFails(getDoc(doc(other.firestore(), "driver_locations", DRIVER)));
  });

  it("refuse la lecture quand la mission désigne un autre chauffeur", async () => {
    await seed("in_transit", "approved", "rka_other_driver");
    const customer = env.authenticatedContext(CUSTOMER, { role: "customer" });
    await assertFails(getDoc(doc(customer.firestore(), "driver_locations", DRIVER)));
  });

  it.each(["analyst", "admin", "super_admin"])(
    "conserve la lecture administrative %s sans permettre une écriture cliente directe", async role => {
      await seed("cancelled");
      const staff = env.authenticatedContext("rka_staff_" + role, { role });
      await assertSucceeds(getDoc(doc(staff.firestore(), "driver_locations", DRIVER)));
      await assertFails(updateDoc(doc(staff.firestore(), "driver_locations", DRIVER), { active_delivery_id: null }));
    });

  it("conserve la lecture chauffeur et les écritures serveur d'assignation/nettoyage", async () => {
    await seed();
    const driver = env.authenticatedContext(DRIVER, { role: "driver" });
    await assertSucceeds(getDoc(doc(driver.firestore(), "driver_locations", DRIVER)));
    await env.withSecurityRulesDisabled(async ctx => {
      await updateDoc(doc(ctx.firestore(), "driver_locations", DRIVER), { active_delivery_id: null });
    });
    const snap = await assertSucceeds(getDoc(doc(driver.firestore(), "driver_locations", DRIVER)));
    expect(snap.data()?.active_delivery_id).toBeNull();
  });
});
