// SEC-S1 / SEC-S2 (2026-10-22) — Firestore rules hardening.
//   S1: a customer can no longer cancel once the item has been picked up.
//   S2: driver_profiles writes are restricted to declarative fields; payout
//       (Stripe) and verification fields are Cloud-Functions-only.
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { collection, doc, getDoc, getDocs, query, setDoc, updateDoc, where } from "firebase/firestore";
import { createTestEnv } from "./setup";

let env: RulesTestEnvironment;
beforeAll(async () => { env = await createTestEnv(); });
afterEach(async () => { await env.clearFirestore(); });
afterAll(async () => { await env.cleanup(); });

const CUSTOMER = "s1_customer";
const DRIVER = "s2_driver";
const customer = () => env.authenticatedContext(CUSTOMER, { role: "customer", roles: ["customer"] });
const driver = () => env.authenticatedContext(DRIVER, { role: "driver", roles: ["driver"] });

async function seedMission(id: string, status: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `delivery_requests/${id}`), {
      customer_id: CUSTOMER,
      driver_id: status === "searching_driver" || status === "offered" ? null : "driver_x",
      status,
      driver_offer_amount: 85,
      customer_total: 100,
      payment_status: "authorized",
      pricing_version: "MOVIK-PRICING-001",
    });
  });
}
const cancel = (id: string) => updateDoc(doc(customer().firestore(), `delivery_requests/${id}`), {
  status: "cancelled",
  cancellation_reason: "test",
});

describe("SEC-S1 — customer cancellation only before pickup", () => {
  it.each(["searching_driver", "offered"])(
    "direct cancel allowed from %s (no driver yet, always free)", async (status) => {
      await seedMission(`m_${status}`, status);
      await assertSucceeds(cancel(`m_${status}`));
    });

  // Fees (2026-10-22): after a driver accepted, only cancelDeliveryRequest
  // may cancel, so the late-cancellation fee is shown and applied.
  it.each(["assigned", "driver_to_pickup", "arrived_at_pickup"])(
    "direct cancel refused from %s (must use cancelDeliveryRequest)", async (status) => {
      await seedMission(`m_${status}`, status);
      await assertFails(cancel(`m_${status}`));
    });

  it.each(["picked_up", "in_transit", "arrived_at_dropoff", "delivered", "completed", "cancelled", "disputed", "refunded"])(
    "cancel refused from %s", async (status) => {
      await seedMission(`m_${status}`, status);
      await assertFails(cancel(`m_${status}`));
    });
});

async function seedProfile(data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), `driver_profiles/${DRIVER}`), {
      uid: DRIVER,
      status: "approved",
      online_status: "offline",
      city: "Granby",
      stripe_connected_account_id: "acct_real",
      stripe_payouts_enabled: true,
      documents_all_valid: true,
      approved_at: "2026-10-01",
      ...data,
    });
  });
}
const profileRef = () => doc(driver().firestore(), `driver_profiles/${DRIVER}`);

describe("SEC-S2 — driver_profiles whitelist", () => {
  it("driver cannot redirect payouts to another Stripe account", async () => {
    await seedProfile({});
    await assertFails(updateDoc(profileRef(), { stripe_connected_account_id: "acct_attacker" }));
    await assertFails(updateDoc(profileRef(), { stripe_payouts_enabled: false }));
    await assertFails(updateDoc(profileRef(), { stripe_onboarding_url: "https://evil.example" }));
  });

  it("driver cannot erase protected fields through a full-profile merge", async () => {
    await seedProfile({});
    await assertFails(setDoc(profileRef(), {
      city: "Bromont",
      approved_at: null,
      stripe_connected_account_id: null,
    }, { merge: true }));
  });

  it("driver can edit declarative fields with a merge (re-submission of onboarding)", async () => {
    await seedProfile({ status: "pending_review" });
    await assertSucceeds(setDoc(profileRef(), {
      full_name: "Chauffeur Test",
      city: "Bromont",
      phone: "+14505550100",
      service_radius_km: 40,
      accepted_vehicle_categories: ["pickup_truck"],
    }, { merge: true }));
    const data = (await getDoc(profileRef())).data()!;
    expect(data.stripe_connected_account_id).toBe("acct_real");
    expect(data.status).toBe("pending_review");
  });

  it("creation cannot self-declare verification or payout fields", async () => {
    for (const extra of [
      { documents_all_valid: true },
      { identity_verified: true },
      { stripe_connected_account_id: "acct_x" },
      { approved_at: "2026-10-22" },
      { online_status: "online" },
    ]) {
      await env.clearFirestore();
      await assertFails(setDoc(profileRef(), {
        uid: DRIVER, status: "registration_incomplete", city: "Granby", ...extra,
      }));
    }
  });

  it("creation with declarative fields only succeeds", async () => {
    await assertSucceeds(setDoc(profileRef(), {
      uid: DRIVER,
      status: "registration_incomplete",
      online_status: "offline",
      created_at: "2026-10-22T10:00:00.000Z",
      full_name: "Chauffeur Test",
      city: "Granby",
      accepted_vehicle_categories: ["cargo_van"],
    }));
  });

  it("online requires approval, offline is always allowed", async () => {
    await seedProfile({ status: "pending_review" });
    await assertFails(updateDoc(profileRef(), { online_status: "online" }));
    await seedProfile({ status: "suspended", online_status: "online" });
    await assertSucceeds(updateDoc(profileRef(), { online_status: "offline" }));
    await seedProfile({ status: "approved" });
    await assertSucceeds(updateDoc(profileRef(), { online_status: "online" }));
    await assertFails(updateDoc(profileRef(), { online_status: "busy" }));
  });
});

describe("SEC-S3 — verified vehicles are locked for the driver", () => {
  async function seedVehicle(isVerified: boolean): Promise<void> {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "driver_vehicles/s3_vehicle"), {
        driver_id: DRIVER, is_verified: isVerified, category: "pickup_truck", max_payload_kg: 500, plate: "ABC123",
      });
    });
  }
  const vehicleRef = () => doc(driver().firestore(), "driver_vehicles/s3_vehicle");

  it("verified vehicle: driver cannot change category or payload", async () => {
    await seedVehicle(true);
    await assertFails(updateDoc(vehicleRef(), { category: "cube_truck" }));
    await assertFails(updateDoc(vehicleRef(), { max_payload_kg: 5000 }));
  });

  it("unverified vehicle: driver can still correct details", async () => {
    await seedVehicle(false);
    await assertSucceeds(updateDoc(vehicleRef(), { plate: "XYZ789", category: "cargo_van" }));
  });
});

describe("SEC-S5 — promo codes cannot be enumerated", () => {
  it("a known code can be read, the full list cannot", async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      await setDoc(doc(ctx.firestore(), "promo_codes/GRANBY10"), { code: "GRANBY10", is_active: true });
    });
    await assertSucceeds(getDoc(doc(customer().firestore(), "promo_codes/GRANBY10")));
    await assertFails(getDocs(collection(customer().firestore(), "promo_codes")));
    const analyst = env.authenticatedContext("s5_analyst", { role: "analyst", roles: ["analyst"] });
    await assertSucceeds(getDocs(collection(analyst.firestore(), "promo_codes")));
  });
});

describe("SEC-S6 — app finance queries are allowed for their owners", () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, "delivery_requests/s6_mission"), { customer_id: CUSTOMER, driver_id: DRIVER, status: "completed" });
      await setDoc(doc(db, "payments/s6_payment"), { customer_id: CUSTOMER, mission_id: "s6_mission" });
      await setDoc(doc(db, "refunds/s6_refund"), { payment_id: "s6_payment", mission_id: "s6_mission", amount: 10 });
      await setDoc(doc(db, "transaction_ledger/s6_driver"), { mission_id: "s6_mission", party: "driver", amount: 85 });
      await setDoc(doc(db, "transaction_ledger/s6_customer"), { mission_id: "s6_mission", party: "customer", amount: 100 });
    });
  });

  it("customer can list refunds of their mission by mission_id; a stranger cannot", async () => {
    await assertSucceeds(getDocs(query(collection(customer().firestore(), "refunds"), where("mission_id", "==", "s6_mission"))));
    const stranger = env.authenticatedContext("s6_stranger", { role: "customer", roles: ["customer"] });
    await assertFails(getDocs(query(collection(stranger.firestore(), "refunds"), where("mission_id", "==", "s6_mission"))));
  });

  it("driver can list their ledger entries with the party filter used by the app", async () => {
    await assertSucceeds(getDocs(query(collection(driver().firestore(), "transaction_ledger"),
      where("mission_id", "==", "s6_mission"), where("party", "==", "driver"))));
    await assertFails(getDocs(query(collection(driver().firestore(), "transaction_ledger"),
      where("mission_id", "==", "s6_mission"), where("party", "==", "customer"))));
  });
});
