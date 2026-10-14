// SEC-GAP-S04: the emergency/ordinary suspension level is controlled only
// by Cloud Functions Admin SDK. Firestore clients cannot insert or edit it.
import { assertFails, assertSucceeds, RulesTestEnvironment } from "@firebase/rules-unit-testing";
import { deleteField, doc, getDoc, setDoc, updateDoc } from "firebase/firestore";
import { createTestEnv } from "./setup";

let env: RulesTestEnvironment;
const DRIVER = "suspension_mode_security_driver";
const PROFILE = "driver_profiles/" + DRIVER;

async function seed(data: Record<string, unknown>): Promise<void> {
  await env.withSecurityRulesDisabled(async (context) => {
    await setDoc(doc(context.firestore(), PROFILE), {
      uid: DRIVER,
      status: "suspended",
      online_status: "offline",
      city: "Granby",
      ...data,
    });
  });
}

function driver() {
  return env.authenticatedContext(DRIVER, {
    role: "driver", roles: ["driver"],
  });
}

beforeAll(async () => { env = await createTestEnv(); });
afterEach(async () => { await env.clearFirestore(); });
afterAll(async () => { await env.cleanup(); });

describe("SEC-GAP-S04 — client cannot modify suspension_mode", () => {
  it("denies urgent -> ordinary privilege downgrade with a partial update", async () => {
    await seed({ suspension_mode: "urgent" });
    await assertFails(updateDoc(doc(driver().firestore(), PROFILE), {
      suspension_mode: "ordinary",
    }));
    const original = await assertSucceeds(getDoc(doc(driver().firestore(), PROFILE)));
    expect(original.data()?.suspension_mode).toBe("urgent");
  });

  it("denies removal of urgent mode, including deleteField()", async () => {
    await seed({ suspension_mode: "urgent" });
    await assertFails(updateDoc(doc(driver().firestore(), PROFILE), {
      suspension_mode: deleteField(),
    }));
    expect((await getDoc(doc(driver().firestore(), PROFILE))).data()?.suspension_mode)
      .toBe("urgent");
  });

  it("denies insertion of ordinary suspension_mode into legacy suspended profile", async () => {
    await seed({});
    await assertFails(updateDoc(doc(driver().firestore(), PROFILE), {
      suspension_mode: "ordinary",
    }));
    expect((await getDoc(doc(driver().firestore(), PROFILE))).data())
      .not.toHaveProperty("suspension_mode");
  });

  it("denies editing ordinary -> urgent directly; administrator callable owns escalation", async () => {
    await seed({ suspension_mode: "ordinary" });
    await assertFails(updateDoc(doc(driver().firestore(), PROFILE), {
      suspension_mode: "urgent",
    }));
    expect((await getDoc(doc(driver().firestore(), PROFILE))).data()?.suspension_mode)
      .toBe("ordinary");
  });

  it("retains legitimate declarative profile editing and a legacy document without optional fields", async () => {
    await seed({ suspension_mode: "ordinary" });
    await assertSucceeds(updateDoc(doc(driver().firestore(), PROFILE), {
      city: "Sherbrooke",
    }));
    const data = (await getDoc(doc(driver().firestore(), PROFILE))).data()!;
    expect(data.city).toBe("Sherbrooke");
    expect(data.suspension_mode).toBe("ordinary");
    await seed({});
    await assertSucceeds(updateDoc(doc(driver().firestore(), PROFILE), {
      city: "Waterloo",
    }));
    const legacy = (await getDoc(doc(driver().firestore(), PROFILE))).data()!;
    expect(legacy.city).toBe("Waterloo");
    expect(legacy).not.toHaveProperty("suspension_mode");
  });

  it("approved driver may change online_status without any suspension_mode field", async () => {
    await seed({ status: "approved" });
    await assertSucceeds(updateDoc(doc(driver().firestore(), PROFILE), {
      online_status: "online",
    }));
    const data = (await getDoc(doc(driver().firestore(), PROFILE))).data()!;
    expect(data.online_status).toBe("online");
    expect(data).not.toHaveProperty("suspension_mode");
  });

  it("direct writes from analyst/admin cannot alter the protected field", async () => {
    await seed({ suspension_mode: "urgent" });
    for (const role of ["analyst", "admin", "super_admin"]) {
      const staff = env.authenticatedContext("suspension_mode_" + role, {
        role, roles: [role],
      });
      await assertFails(updateDoc(doc(staff.firestore(), PROFILE), {
        suspension_mode: "ordinary",
      }));
    }
  });

  it("allows service-side administrative policy transitions via rules-disabled context", async () => {
    await seed({ suspension_mode: "ordinary" });
    await env.withSecurityRulesDisabled(async (ctx) => {
      await assertSucceeds(updateDoc(doc(ctx.firestore(), PROFILE), {
        suspension_mode: "urgent",
        status: "suspended",
      }));
    });
    const data = (await getDoc(doc(driver().firestore(), PROFILE))).data()!;
    expect(data.suspension_mode).toBe("urgent");
  });
});
