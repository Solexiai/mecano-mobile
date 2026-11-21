// Comptes de connexion sans fiche `users/{uid}` (Daniel, 2026-11-21) :
// recréés comme client, ou chauffeur s'il y a un prospect/dossier chauffeur.
import { repairOrphanAccounts } from "../../src/functions/repairOrphanAccounts";
import { admin, db } from "../../src/lib/admin";

let clientUid = "";
let driverUid = "";
let intactUid = "";

beforeAll(async () => {
  const stamp = Date.now();
  clientUid = (await admin.auth().createUser({ email: `orphan.client.${stamp}@example.test`, password: "synthetic-password", displayName: "Sylvain Dupont" })).uid;
  driverUid = (await admin.auth().createUser({ email: `orphan.driver.${stamp}@example.test`, password: "synthetic-password" })).uid;
  intactUid = (await admin.auth().createUser({ email: `orphan.intact.${stamp}@example.test`, password: "synthetic-password" })).uid;
  await db.collection("driver_leads").doc(driverUid).set({ user_id: driverUid, started_at: admin.firestore.Timestamp.now() });
  await db.collection("users").doc(intactUid).set({ uid: intactUid, roles: ["customer"], full_name: "Déjà là" });
});

afterAll(async () => {
  for (const uid of [clientUid, driverUid, intactUid]) {
    await admin.auth().deleteUser(uid).catch(() => undefined);
    await db.collection("users").doc(uid).delete();
  }
  await db.collection("driver_leads").doc(driverUid).delete();
});

it("recrée les fiches manquantes : client par défaut, chauffeur si prospect ; ne touche pas aux fiches existantes", async () => {
  const result = await repairOrphanAccounts();
  expect(result.repaired).toEqual(expect.arrayContaining([clientUid, driverUid]));
  expect(result.repaired).not.toContain(intactUid);

  const client = (await db.collection("users").doc(clientUid).get()).data()!;
  expect(client).toMatchObject({ uid: clientUid, full_name: "Sylvain Dupont", roles: ["customer"], is_disabled: false });
  expect(client.profile_repaired_at).toBeDefined();
  expect(client.created_at).toBeInstanceOf(admin.firestore.Timestamp);

  const driver = (await db.collection("users").doc(driverUid).get()).data()!;
  expect(driver).toMatchObject({ roles: ["customer", "driver"], driver_signup: "started" });

  expect((await db.collection("users").doc(intactUid).get()).data()).toMatchObject({ full_name: "Déjà là" });

  // Relancé : plus rien à réparer.
  expect((await repairOrphanAccounts()).repaired).not.toEqual(expect.arrayContaining([clientUid, driverUid]));
});
