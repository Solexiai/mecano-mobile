// Source des prospects et réglages des relances (décision Daniel, 2026-11-17).
import { getAcquisitionReport, recordAcquisitionSource } from "../../src/functions/acquisitionSources";
import { adminEmailSettings } from "../../src/functions/leadFollowUps";
import { admin, db } from "../../src/lib/admin";
import { EMAIL_SETTINGS_DOC } from "../../src/lib/emailPreferences";

const call = (data: unknown, uid: string, roles = ["customer"]) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const A = "acq_client_a";
const B = "acq_client_b";
const OLD = "acq_client_old";

afterEach(async () => {
  for (const uid of [A, B, OLD]) {
    await db.collection("user_acquisition").doc(uid).delete();
    await db.collection("driver_profiles").doc(uid).delete();
    await db.collection("delivery_quotes").doc(`acq_q_${uid}`).delete();
    await db.collection("delivery_requests").doc(`acq_m_${uid}`).delete();
  }
  await db.doc(EMAIL_SETTINGS_DOC).delete();
});

describe("source d'un prospect", () => {
  it("compte connecté seulement ; la première source gagne", async () => {
    await expect(recordAcquisitionSource.run({ data: {}, rawRequest: {}, acceptsStreaming: false } as any))
      .rejects.toMatchObject({ code: "unauthenticated" });
    const first = await recordAcquisitionSource.run(call(
      { source: "facebook", medium: "cpc", campaign: "chauffeurs_nov", clickId: "fbclid", landingPath: "/fr/devenir-chauffeur", platform: "web", firstSeenAtMs: 1 }, A));
    expect(first).toEqual({ recorded: true });
    const again = await recordAcquisitionSource.run(call({ referrer: "https://www.google.com/" }, A));
    expect(again).toEqual({ recorded: false });
    const stored = (await db.collection("user_acquisition").doc(A).get()).data()!;
    expect(stored).toMatchObject({
      user_id: A, channel: "paid_social", source: "facebook", medium: "cpc", campaign: "chauffeurs_nov",
      landing_path: "/fr/devenir-chauffeur", click_id: "fbclid",
    });
  });

  it("tableau : réservé au personnel ; comptes, prix, réservations et chauffeurs par source", async () => {
    await expect(getAcquisitionReport.run(call({}, A))).rejects.toMatchObject({ code: "permission-denied" });
    await recordAcquisitionSource.run(call({ source: "facebook", medium: "cpc", campaign: "acq_test" }, A));
    await recordAcquisitionSource.run(call({ source: "facebook", medium: "cpc", campaign: "acq_test" }, B));
    const now = admin.firestore.Timestamp.now();
    await db.collection("driver_profiles").doc(B).set({ uid: B, status: "registration_incomplete" });
    await db.collection("delivery_quotes").doc(`acq_q_${A}`).set({ customer_id: A, created_at: now });
    await db.collection("delivery_requests").doc(`acq_m_${A}`).set({ customer_id: A, created_at: now });
    const report = (await getAcquisitionReport.run(call({ days: 7 }, "acq_staff", ["analyst"]))) as any;
    expect(report.days).toBe(7);
    const row = report.rows.find((r: any) => r.label === "facebook / cpc / acq_test");
    expect(row).toEqual({ channel: "paid_social", label: "facebook / cpc / acq_test", accounts: 2, priced: 1, booked: 1, drivers: 1 });
  });
});

describe("réglages des relances (admin)", () => {
  it("admin seulement ; l'adresse postale met les relances en route ; journalisé", async () => {
    await expect(adminEmailSettings.run(call({ action: "get" }, "x", ["analyst"]))).rejects.toMatchObject({ code: "permission-denied" });
    expect(await adminEmailSettings.run(call({ action: "get" }, "boss", ["admin"])))
      .toEqual({ postalAddress: "", followUpsEnabled: true, ready: false });
    const saved = await adminEmailSettings.run(call(
      { action: "save", postalAddress: "  123 rue Principale,   Granby (Québec) J2G 0A0 " }, "boss", ["admin"]));
    expect(saved).toEqual({ postalAddress: "123 rue Principale, Granby (Québec) J2G 0A0", followUpsEnabled: true, ready: true });
    const off = await adminEmailSettings.run(call({ action: "save", followUpsEnabled: false }, "boss", ["admin"]));
    expect(off).toMatchObject({ followUpsEnabled: false, ready: false, postalAddress: "123 rue Principale, Granby (Québec) J2G 0A0" });
    await expect(adminEmailSettings.run(call({ action: "save", postalAddress: "x".repeat(300) }, "boss", ["admin"])))
      .rejects.toMatchObject({ code: "invalid-argument" });
    await expect(adminEmailSettings.run(call({ action: "save" }, "boss", ["admin"]))).rejects.toMatchObject({ code: "invalid-argument" });
    const audits = await db.collection("audit_logs").where("source_function", "==", "adminEmailSettings").get();
    expect(audits.size).toBeGreaterThanOrEqual(2);
  });
});
