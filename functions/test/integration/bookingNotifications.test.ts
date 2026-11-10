// -----------------------------------------------------------------------------
// Courriel « Réservation confirmée » et rappels 4 h avant le ramassage
// (décision Daniel, 2026-11-10).
// -----------------------------------------------------------------------------
import { runPickupReminders, sendBookingConfirmation } from "../../src/functions/bookingNotifications";
import { admin, db } from "../../src/lib/admin";
import { EmailSender, OutgoingEmail, setEmailSenderForTesting } from "../../src/lib/transactionalEmail";

const MISSION = "bn_mission_001";
const CUSTOMER = "bn_customer";
const DRIVER_EMAIL = "bn.driver@example.test";
let driverUid = "";

class FakeSender implements EmailSender {
  sent: Array<{ email: OutgoingEmail; key: string }> = [];
  async send(email: OutgoingEmail, key: string) {
    this.sent.push({ email, key });
    return { id: `re_fake_${this.sent.length}` };
  }
}

const HOUR = 3600_000;
let sender: FakeSender;

/** Rappels faits pour la livraison de ce test (l'émulateur peut en contenir d'autres). */
async function remindedHere(): Promise<string[]> {
  return (await runPickupReminders()).reminded.filter((k) => k.startsWith(`${MISSION}__`)).sort();
}

async function seedMission(overrides: Record<string, unknown> = {}, pickupInMs = 4 * HOUR - 5 * 60_000): Promise<number> {
  const pickupMs = Date.now() + pickupInMs;
  await db.collection("delivery_requests").doc(MISSION).set({
    customer_id: CUSTOMER, customer_display_name: "Marie Tremblay",
    driver_id: driverUid, driver_display_name: "Marc Caron",
    status: "assigned", assignment_mode: "standard", internal_test_authorized: false,
    customer_total_minor: 7243, deposit: { amount_minor: 2500, status: "captured" },
    pickup_address: { line1: "12 rue Principale", city: "Granby" },
    dropoff_address: { line1: "45 boul. Leclerc", city: "Granby" },
    booking_snapshot: { load: { timing_mode: "scheduled", requested_at: new Date(pickupMs).toISOString(), items: [{ quantity: 1, label: "Divan" }] } },
    created_at: admin.firestore.Timestamp.fromMillis(Date.now() - 48 * HOUR),
    accepted_at: admin.firestore.Timestamp.fromMillis(Date.now() - 24 * HOUR),
    ...overrides,
  });
  await db.collection("delivery_requests").doc(MISSION).collection("private").doc("booking").set({
    customer_email: "marie@example.test", consent: { locale: "fr" },
  });
  return pickupMs;
}

beforeAll(async () => {
  driverUid = (await admin.auth().createUser({ email: DRIVER_EMAIL, password: "synthetic-password" })).uid;
});

afterAll(async () => {
  await admin.auth().deleteUser(driverUid).catch(() => undefined);
});

beforeEach(() => {
  sender = new FakeSender();
  setEmailSenderForTesting(sender);
});

afterEach(async () => {
  setEmailSenderForTesting(null);
  await db.recursiveDelete(db.collection("delivery_requests").doc(MISSION));
  for (const uid of [CUSTOMER, driverUid]) await db.recursiveDelete(db.collection("users").doc(uid));
  for (const name of ["email_log", "pickup_reminders"]) {
    const rows = await db.collection(name).where("mission_id", "==", MISSION).get();
    for (const r of rows.docs) await r.ref.delete();
  }
});

describe("Réservation confirmée", () => {
  it("un courriel au client, une seule fois", async () => {
    await seedMission({ status: "searching_driver", driver_id: null, accepted_at: null });
    expect(await sendBookingConfirmation(MISSION)).toBe("sent");
    expect(await sendBookingConfirmation(MISSION)).toBe("duplicate");
    expect(sender.sent).toHaveLength(1);
    const { email, key } = sender.sent[0];
    expect(key).toBe(`booking_confirmed__${MISSION}`);
    expect(email.to).toBe("marie@example.test");
    expect(email.subject).toContain("Réservation confirmée");
    expect(email.text).toContain("25,00 $");
    const log = (await db.collection("email_log").doc(key).get()).data()!;
    expect(log).toMatchObject({ status: "sent", kind: "booking_confirmed", user_id: CUSTOMER, provider_id: "re_fake_1" });
    // Le journal ne garde jamais l'adresse courriel.
    expect(JSON.stringify(log)).not.toContain("marie@example.test");
  });

  it("jamais pour une livraison de test interne", async () => {
    await seedMission({ assignment_mode: "internal_test", internal_test_authorized: true });
    expect(await sendBookingConfirmation(MISSION)).toBe("skipped");
    expect(sender.sent).toHaveLength(0);
  });

  it("sans clé Resend : rien n'est envoyé, le journal le dit", async () => {
    setEmailSenderForTesting(null);
    await seedMission();
    expect(await sendBookingConfirmation(MISSION)).toBe("not_configured");
  });
});

describe("Rappel 4 h avant le ramassage", () => {
  it("client et chauffeur : cloche + courriel, une seule fois chacun", async () => {
    await seedMission();
    expect(await remindedHere()).toEqual([`${MISSION}__customer`, `${MISSION}__driver`]);
    expect(await remindedHere()).toEqual([]);

    const keys = sender.sent.map((s) => s.key).filter((k) => k.endsWith(`__${MISSION}`)).sort();
    expect(keys).toEqual([`pickup_reminder_customer__${MISSION}`, `pickup_reminder_driver__${MISSION}`]);
    const toDriver = sender.sent.find((s) => s.key.startsWith("pickup_reminder_driver"))!;
    expect(toDriver.email.to).toBe(DRIVER_EMAIL);
    expect(toDriver.email.text).toContain("12 rue Principale, Granby");
    const toCustomer = sender.sent.find((s) => s.key.startsWith("pickup_reminder_customer"))!;
    expect(toCustomer.email.to).toBe("marie@example.test");

    const customerBell = await db.collection("users").doc(CUSTOMER).collection("notifications").get();
    expect(customerBell.docs.map((d) => d.data().title_key)).toEqual(["notif_pickup_reminder_customer_title"]);
    const driverBell = await db.collection("users").doc(driverUid).collection("notifications").get();
    expect(driverBell.docs.map((d) => d.data().title_key)).toEqual(["notif_pickup_reminder_driver_title"]);
  });

  it("pas encore : ramassage dans plus de 4 h", async () => {
    await seedMission({}, 5 * HOUR);
    expect(await remindedHere()).toEqual([]);
  });

  it("réservé et accepté moins de 4 h avant le ramassage : pas de rappel (rendez-vous tout frais)", async () => {
    // Ramassage dans 3 h 55 : réservé et accepté il y a 2 min, donc 3 h 57 avant.
    await seedMission({
      created_at: admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 60_000),
      accepted_at: admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 60_000),
    });
    expect(await remindedHere()).toEqual([]);
  });

  it("ignorés : aucun chauffeur encore, « dès que possible », test interne", async () => {
    await seedMission({ status: "searching_driver" });
    expect(await remindedHere()).toEqual([]);
    await seedMission({ booking_snapshot: { load: { timing_mode: "immediate", requested_at: null, items: [] } } });
    expect(await remindedHere()).toEqual([]);
    await seedMission({ assignment_mode: "internal_test", internal_test_authorized: true });
    expect(await remindedHere()).toEqual([]);
    expect(sender.sent.filter((s) => s.key.endsWith(`__${MISSION}`))).toHaveLength(0);
  });
});
