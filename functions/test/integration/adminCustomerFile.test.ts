// -----------------------------------------------------------------------------
// Fiche client du service client (Daniel, 2026-11-10, phase 1).
// -----------------------------------------------------------------------------
import {
  addCustomerNote,
  getAdminCustomerFile,
  resendCustomerEmail,
  setCustomerNotePinned,
} from "../../src/functions/adminCustomerFile";
import { admin, db } from "../../src/lib/admin";
import { EmailSender, OutgoingEmail, setEmailSenderForTesting } from "../../src/lib/transactionalEmail";
import { setPaymentProviderForTesting } from "../../src/payment/paymentProviderFactory";
import { FakePaymentProvider } from "../testUtils/fakePaymentProvider";

const call = (data: unknown, uid = "cf_admin", roles = ["admin"]) =>
  ({ data, auth: { uid, token: { roles, role: roles[0] } }, rawRequest: {}, acceptsStreaming: false } as any);

const MISSION = "cf_mission_001";
let customer = "";

class FakeSender implements EmailSender {
  sent: Array<{ email: OutgoingEmail; key: string }> = [];
  async send(email: OutgoingEmail, key: string) {
    this.sent.push({ email, key });
    return { id: `re_fake_${this.sent.length}` };
  }
}
let sender: FakeSender;

beforeAll(async () => {
  customer = (await admin.auth().createUser({ email: "cf.client@example.test", password: "synthetic-password", emailVerified: true })).uid;
});
afterAll(async () => {
  await admin.auth().deleteUser(customer).catch(() => undefined);
});

beforeEach(async () => {
  sender = new FakeSender();
  setEmailSenderForTesting(sender);
  setPaymentProviderForTesting(new FakePaymentProvider());
  const now = admin.firestore.Timestamp.now();
  await db.doc(`users/${customer}`).set({ full_name: "Marie Tremblay", booking_contacts: { pickup_phone: "450 555-1234" } });
  await db.doc(`delivery_requests/${MISSION}`).set({
    customer_id: customer, customer_display_name: "Marie Tremblay", status: "completed", assignment_mode: "standard",
    customer_total_minor: 7243, deposit: { amount_minor: 2500, status: "captured" },
    pickup_address: { line1: "12 rue Principale", city: "Granby" }, dropoff_address: { line1: "45 boul. Leclerc", city: "Granby" },
    booking_snapshot: { load: { timing_mode: "scheduled", requested_at: "2026-11-12T19:00:00.000Z", items: [{ quantity: 1, label: "Divan" }] } },
    driver_display_name: "Marc Caron", created_at: now, completed_at: now,
  });
  await db.doc(`delivery_requests/${MISSION}/private/booking`).set({
    customer_email: "cf.client@example.test",
    consent: { terms_version: "V-2026-10", accepted_at: now, locale: "fr" },
    marketing_preference: { opt_in: true },
  });
  await db.doc("payments/cf_pay_deposit").set({
    customer_id: customer, mission_id: MISSION, purpose: "deposit", status: "captured", amount_captured_minor: 2500,
    amount_refunded_minor: 0, provider_charge_id: "ch_cf_deposit", provider_payment_intent_id: "pi_cf_deposit",
    stripe_environment: "test", created_at: now, captured_at: now,
  });
  await db.doc("payments/cf_pay_balance").set({
    customer_id: customer, mission_id: MISSION, status: "capture_failed", amount_authorized_minor: 4743,
    amount_captured_minor: 0, amount_refunded_minor: 0, stripe_environment: "test", created_at: now,
  });
  await db.doc("delivery_quotes/cf_quote_open").set({
    customer_id: customer, is_consumed: false, customer_total_minor: 9900, created_at: now, expires_at: now,
    stops: [{ address: { line1: "1 rue A", city: "Bromont" } }, { address: { line1: "2 rue B", city: "Granby" } }],
  });
  await db.doc("ratings/cf_rating").set({ mission_id: MISSION, rater_id: customer, rater_role: "customer", stars: 5 });
});

afterEach(async () => {
  setEmailSenderForTesting(null);
  setPaymentProviderForTesting(null);
  await db.recursiveDelete(db.doc(`delivery_requests/${MISSION}`));
  for (const path of ["payments/cf_pay_deposit", "payments/cf_pay_balance", "delivery_quotes/cf_quote_open", "ratings/cf_rating", `users/${customer}`]) {
    await db.doc(path).delete();
  }
  for (const name of ["customer_notes", "email_log"]) {
    const rows = await db.collection(name).where("user_id", "==", customer).get();
    for (const r of rows.docs) await r.ref.delete();
  }
});

it("admin : fiche complète — compte, chiffres, pastilles, livraisons, paiements, conditions", async () => {
  const file = await getAdminCustomerFile.run(call({ userId: customer }));
  expect(file).toMatchObject({ canAct: true, masked: false });
  expect(file.account).toMatchObject({
    fullName: "Marie Tremblay", email: "cf.client@example.test", emailVerified: true,
    phone: "450 555-1234", locale: "fr", cardOnFile: false,
  });
  expect(file.stats).toMatchObject({ deliveries: 1, completed: 1, spentMinor: 2500, problemPayments: 1, quotesNotBooked: 1, averageRatingGiven: 5 });
  expect(file.badges).toEqual(expect.arrayContaining(["new", "watch"]));
  expect(file.missions[0]).toMatchObject({ id: MISSION, pickup: "12 rue Principale, Granby", driverName: "Marc Caron" });
  expect(file.quotes[0]).toMatchObject({ id: "cf_quote_open", totalMinor: 9900, pickup: "1 rue A, Bromont" });
  expect(file.payments.map((p: any) => p.kind).sort()).toEqual(["delivery", "deposit"]);
  expect(file.consents[0]).toMatchObject({ termsVersion: "V-2026-10", marketing: true });

  // Loi 25 : chaque consultation est journalisée.
  const views = await db.collection("audit_logs").where("target_id", "==", customer)
    .where("action", "==", "customer_file_viewed").get();
  expect(views.size).toBeGreaterThanOrEqual(1);
});

it("analyste : ville seulement, téléphone masqué, aucune action", async () => {
  const file = await getAdminCustomerFile.run(call({ userId: customer }, "cf_analyst", ["analyst"]));
  expect(file).toMatchObject({ canAct: false, masked: true });
  expect(file.account.phone).toBe("••• ••• 1234");
  expect(file.missions[0].pickup).toBe("Granby");
  await expect(addCustomerNote.run(call({ userId: customer, text: "x" }, "cf_analyst", ["analyst"])))
    .rejects.toMatchObject({ code: "permission-denied" });
});

it("un client ne peut pas lire une fiche", async () => {
  await expect(getAdminCustomerFile.run(call({ userId: customer }, customer, ["customer"])))
    .rejects.toMatchObject({ code: "permission-denied" });
});

it("notes internes : ajout, épinglage, ordre (épinglées d'abord)", async () => {
  const first = await addCustomerNote.run(call({ userId: customer, text: "Préfère être appelé" }));
  await addCustomerNote.run(call({ userId: customer, text: "Deuxième note" }));
  await setCustomerNotePinned.run(call({ noteId: first.id, pinned: true }));
  const file = await getAdminCustomerFile.run(call({ userId: customer }));
  expect(file.notes.map((n: any) => [n.text, n.pinned])).toEqual([["Préfère être appelé", true], ["Deuxième note", false]]);
  expect(file.staffActions.map((a: any) => a.action)).toEqual(expect.arrayContaining(["customer_note_added", "customer_note_pinned"]));
  await expect(addCustomerNote.run(call({ userId: customer, text: "   " }))).rejects.toMatchObject({ code: "invalid-argument" });
});

it("renvoyer la confirmation et le reçu", async () => {
  const confirmation = await resendCustomerEmail.run(call({ userId: customer, kind: "booking_confirmed", missionId: MISSION }));
  expect(confirmation).toEqual({ outcome: "sent" });
  const receipt = await resendCustomerEmail.run(call({ userId: customer, kind: "payment_receipt", paymentId: "cf_pay_deposit" }));
  expect(receipt).toEqual({ outcome: "sent" });
  expect(sender.sent.map((s) => s.email.category)).toEqual(["booking_confirmed", "payment_receipt"]);
  expect(sender.sent[1].email.text).toContain("https://pay.stripe.test/receipts/ch_cf_deposit");
  expect(sender.sent[1].email.to).toBe("cf.client@example.test");
  // Paiement jamais encaissé : pas de reçu.
  await expect(resendCustomerEmail.run(call({ userId: customer, kind: "payment_receipt", paymentId: "cf_pay_balance" })))
    .rejects.toMatchObject({ code: "failed-precondition" });
  // Paiement d'un autre client : refusé.
  await expect(resendCustomerEmail.run(call({ userId: "someone_else", kind: "payment_receipt", paymentId: "cf_pay_deposit" })))
    .rejects.toMatchObject({ code: "permission-denied" });
});
