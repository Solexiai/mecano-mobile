// -----------------------------------------------------------------------------
// Effacer un client (super-admin) et liste « Accepte les offres »
// (Daniel, 2026-11-10).
// -----------------------------------------------------------------------------
import { deleteCustomerAccount, getMarketingOptIns } from "../../src/functions/adminCustomerDeletion";
import { admin, db } from "../../src/lib/admin";

const call = (data: unknown, uid = "del_boss", roles = ["super_admin"]) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const MISSION = "del_mission_001";
const LATER = "del_mission_002";
let customer = "";
const cleanup: string[] = [];

async function newCustomer(email: string): Promise<string> {
  const uid = (await admin.auth().createUser({ email, password: "synthetic-password" })).uid;
  cleanup.push(uid);
  return uid;
}

beforeEach(async () => {
  customer = await newCustomer(`del.client.${Date.now()}@example.test`);
  const now = admin.firestore.Timestamp.now();
  await db.doc(`users/${customer}`).set({
    uid: customer, email: "del.client@example.test", full_name: "Julie Gagnon", roles: ["customer"],
    created_at: "2026-11-01T15:00:00.000Z", booking_contacts: { pickup_phone: "450 555-9876" },
    saved_addresses: { home: { line1: "8 rue Dufferin", city: "Granby" } },
  });
  await db.doc(`users/${customer}/notifications/n1`).set({ title: "Livraison confirmée", created_at: now });
  await db.doc(`customer_notes/del_note_1`).set({ user_id: customer, text: "Préfère les appels", created_at: now });
  await db.doc(`push_tokens/del_token_1`).set({ user_id: customer, token: "tok" });
  await db.doc(`booking_drafts/${customer}`).set({ owner_uid: customer, draft_id: "d1" });
  await db.doc(`delivery_quotes/del_quote_open`).set({ customer_id: customer, is_consumed: false });
  await db.doc(`delivery_quotes/del_quote_used`).set({ customer_id: customer, is_consumed: true });
  await db.doc(`delivery_requests/${MISSION}`).set({
    customer_id: customer, customer_display_name: "Julie Gagnon", status: "completed", created_at: now,
  });
  await db.doc(`payments/del_pay_1`).set({ customer_id: customer, mission_id: MISSION, status: "captured", amount_captured_minor: 7243 });
});

afterEach(async () => {
  for (const uid of cleanup.splice(0)) {
    await admin.auth().deleteUser(uid).catch(() => undefined);
    await db.recursiveDelete(db.doc(`users/${uid}`));
    await db.doc(`booking_drafts/${uid}`).delete();
    await db.doc(`payment_profiles/${uid}`).delete();
  }
  for (const id of [MISSION, LATER]) await db.recursiveDelete(db.doc(`delivery_requests/${id}`));
  for (const path of [
    "payments/del_pay_1", "payments/del_pay_2", "customer_notes/del_note_1", "push_tokens/del_token_1",
    "delivery_quotes/del_quote_open", "delivery_quotes/del_quote_used", "driver_profiles/del_driver",
  ]) await db.doc(path).delete();
});

it("aperçu : rien n'est touché, mode et nombres affichés", async () => {
  const preview = await deleteCustomerAccount.run(call({ userId: customer, dryRun: true }));
  expect(preview).toEqual({ mode: "anonymize", blockers: [], deliveries: 1, payments: 1 });
  expect((await db.doc(`users/${customer}`).get()).data()?.email).toBe("del.client@example.test");
  await expect(admin.auth().getUser(customer)).resolves.toBeTruthy();
});

it("client avec historique : anonymisé, livraisons et paiements gardés", async () => {
  const result = await deleteCustomerAccount.run(call({ userId: customer, reason: "Demande du client par courriel" }));
  expect(result).toMatchObject({ mode: "anonymize", deleted: true });

  const user = (await db.doc(`users/${customer}`).get()).data()!;
  expect(user).toMatchObject({ full_name: "Client supprimé", deleted: true, deleted_by: "del_boss", created_at: "2026-11-01T15:00:00.000Z" });
  expect(user.email).toBeUndefined();
  expect(user.booking_contacts).toBeUndefined();
  expect(user.saved_addresses).toBeUndefined();
  await expect(admin.auth().getUser(customer)).rejects.toMatchObject({ code: "auth/user-not-found" });

  // Données personnelles parties.
  expect((await db.collection(`users/${customer}/notifications`).get()).size).toBe(0);
  for (const path of ["customer_notes/del_note_1", "push_tokens/del_token_1", `booking_drafts/${customer}`, "delivery_quotes/del_quote_open"]) {
    expect((await db.doc(path).get()).exists).toBe(false);
  }
  // Preuves comptables gardées.
  for (const path of [`delivery_requests/${MISSION}`, "payments/del_pay_1", "delivery_quotes/del_quote_used"]) {
    expect((await db.doc(path).get()).exists).toBe(true);
  }

  const audit = await db.collection("audit_logs").where("target_id", "==", customer)
    .where("action", "==", "customer_account_deleted").get();
  expect(audit.docs[0].data().metadata).toMatchObject({ mode: "anonymize", reason: "Demande du client par courriel", deliveriesKept: 1 });

  await expect(deleteCustomerAccount.run(call({ userId: customer, reason: "deuxième fois" })))
    .rejects.toMatchObject({ code: "failed-precondition" });
});

it("client sans livraison ni paiement : tout est effacé", async () => {
  const fresh = await newCustomer(`del.fresh.${Date.now()}@example.test`);
  await db.doc(`users/${fresh}`).set({ uid: fresh, email: "fresh@example.test", full_name: "Nouveau", roles: ["customer"] });
  await db.doc(`payment_profiles/${fresh}`).set({ stripe_customer_id: "cus_fake" });
  const result = await deleteCustomerAccount.run(call({ userId: fresh, reason: "Compte créé par erreur" }));
  expect(result).toMatchObject({ mode: "erase", deliveries: 0, payments: 0, deleted: true });
  expect((await db.doc(`users/${fresh}`).get()).exists).toBe(false);
  expect((await db.doc(`payment_profiles/${fresh}`).get()).exists).toBe(false);
  await expect(admin.auth().getUser(fresh)).rejects.toMatchObject({ code: "auth/user-not-found" });
});

it("bloqué : livraison en cours, chauffeur, raison manquante ; admin refusé", async () => {
  await db.doc(`delivery_requests/${LATER}`).set({ customer_id: customer, status: "in_transit" });
  const preview = await deleteCustomerAccount.run(call({ userId: customer, dryRun: true }));
  expect(preview.blockers).toEqual(["1 livraison(s) en cours : terminez-les ou annulez-les d'abord."]);
  await expect(deleteCustomerAccount.run(call({ userId: customer, reason: "Demande du client" })))
    .rejects.toMatchObject({ code: "failed-precondition" });
  expect((await db.doc(`users/${customer}`).get()).data()?.email).toBe("del.client@example.test");
  await db.doc(`delivery_requests/${LATER}`).delete();

  await expect(deleteCustomerAccount.run(call({ userId: customer, reason: "abc" })))
    .rejects.toMatchObject({ code: "invalid-argument" });
  await expect(deleteCustomerAccount.run(call({ userId: customer, reason: "Demande du client" }, "del_admin", ["admin"])))
    .rejects.toMatchObject({ code: "permission-denied" });
  await expect(deleteCustomerAccount.run(call({ userId: customer, dryRun: true }, customer)))
    .resolves.toMatchObject({ blockers: ["Vous ne pouvez pas effacer votre propre compte."] });
});

it("offres : la dernière réservation de chaque client décide", async () => {
  const other = await newCustomer(`del.other.${Date.now()}@example.test`);
  const old = admin.firestore.Timestamp.fromMillis(Date.parse("2026-11-01T10:00:00Z"));
  const recent = admin.firestore.Timestamp.fromMillis(Date.parse("2026-11-05T10:00:00Z"));
  await db.doc(`delivery_requests/${MISSION}`).set({ customer_id: customer, status: "completed", created_at: old });
  await db.doc(`delivery_requests/${MISSION}/private/booking`).set({ marketing_preference: { opt_in: false } });
  await db.doc(`delivery_requests/${LATER}`).set({ customer_id: customer, status: "completed", created_at: recent });
  await db.doc(`delivery_requests/${LATER}/private/booking`).set({ marketing_preference: { opt_in: true } });

  const result = await getMarketingOptIns.run(call({}, "del_analyst", ["analyst"]));
  expect(result.userIds).toContain(customer);
  expect(result.userIds).not.toContain(other);

  await db.doc(`delivery_requests/${LATER}/private/booking`).set({ marketing_preference: { opt_in: false } });
  expect((await getMarketingOptIns.run(call({}, "del_analyst", ["analyst"]))).userIds).not.toContain(customer);
  await expect(getMarketingOptIns.run(call({}, customer, ["customer"]))).rejects.toMatchObject({ code: "permission-denied" });
});
