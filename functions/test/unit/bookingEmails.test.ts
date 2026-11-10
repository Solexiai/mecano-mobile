// Courriel « Réservation confirmée » et rappels 4 h (décision Daniel, 2026-11-10).
import {
  PICKUP_REMINDER_LEAD_MS,
  bookingConfirmedEmail,
  pickupReminderEmail,
  pickupReminderPush,
  reminderDue,
  trackingUrl,
} from "../../src/lib/bookingEmails";
import { escapeHtml, formatEmailDateTime, formatEmailMoney, formatEmailTime } from "../../src/lib/transactionalEmail";

const PICKUP = "2026-11-12T19:00:00.000Z"; // jeudi 12 novembre, 14 h 00 à Montréal
const mission = {
  customer_display_name: "Marie <b>Tremblay</b>",
  driver_display_name: "Marc Caron",
  customer_total_minor: 7243,
  deposit: { amount_minor: 2500, status: "captured" },
  pickup_address: { line1: "12 rue Principale", city: "Granby" },
  dropoff_address: { line1: "45 boul. Leclerc", city: "Granby" },
  booking_snapshot: { load: { requested_at: PICKUP, timing_mode: "scheduled", items: [{ quantity: 1, label: "Divan" }, { quantity: 2, label: "Chaise <b>pliante</b>" }] } },
};

describe("bookingEmails", () => {
  it("formate montants et heures du Québec", () => {
    expect(formatEmailMoney(7243, "fr")).toBe("72,43 $");
    expect(formatEmailMoney(7243, "en")).toBe("$72.43");
    expect(formatEmailTime(Date.parse(PICKUP), "fr")).toBe("14 h 00");
    expect(formatEmailTime(Date.parse(PICKUP), "en")).toBe("14:00");
    expect(formatEmailDateTime(Date.parse(PICKUP), "fr")).toBe("jeudi 12 novembre à 14 h 00");
    expect(escapeHtml("<script>&\"'")).toBe("&lt;script&gt;&amp;&quot;&#39;");
  });

  it("« Réservation confirmée » : dépôt payé, solde, total, adresses, objets, lien de suivi", () => {
    const email = bookingConfirmedEmail("m_123", mission, "fr");
    expect(email.category).toBe("booking_confirmed");
    expect(email.subject).toBe("Réservation confirmée — Movi-K (jeudi 12 novembre à 14 h 00)");
    for (const part of ["25,00 $", "47,43 $", "72,43 $", "12 rue Principale, Granby", "45 boul. Leclerc, Granby",
      "1 × Divan, 2 × Chaise", "m_123", trackingUrl("m_123", "fr"), "Bonjour Marie"]) {
      expect(email.text).toContain(part);
    }
    // Contenu saisi par le client échappé dans le HTML.
    expect(email.html).not.toContain("<b>pliante");
    expect(email.html).toContain("&lt;b&gt;pliante");
    expect(email.html).toContain("https://movi-k.com/fr/livraison/suivi/m_123");
  });

  it("sans dépôt encaissé, seul le total est affiché ; « dès que possible » sans heure", () => {
    const email = bookingConfirmedEmail("m_9", {
      ...mission, deposit: null, booking_snapshot: { load: { timing_mode: "immediate", items: [] } },
    }, "en");
    expect(email.text).toContain("Total, taxes included : $72.43");
    expect(email.text).not.toContain("Paid today (deposit)");
    expect(email.subject).toContain("As soon as possible");
  });

  it("rappels : client et chauffeur, heure et adresse de ramassage", () => {
    const ms = Date.parse(PICKUP);
    const customer = pickupReminderEmail("m_1", mission, "customer", ms, "fr");
    expect(customer.subject).toBe("Rappel : votre livraison à 14 h 00 — Movi-K");
    expect(customer.text).toContain("Marc");
    const driver = pickupReminderEmail("m_1", mission, "driver", ms, "fr");
    expect(driver.subject).toBe("Rappel : ramassage à 14 h 00 — Movi-K");
    expect(driver.text).toContain("12 rue Principale, Granby");
    expect(driver.text).toContain("https://movi-k.com/fr/fournisseur/tableau-de-bord");
    expect(pickupReminderPush(mission, "customer", ms, "fr").body).toBe(
      "Votre chauffeur passe vers 14 h 00 au 12 rue Principale, Granby. Préparez vos objets."
    );
  });

  it("rappel dû entre 4 h et 10 min avant, seulement si réservé avant la fenêtre", () => {
    const pickupMs = Date.parse(PICKUP);
    const longAgo = pickupMs - 2 * 24 * 3600_000;
    expect(reminderDue({ pickupMs, nowMs: pickupMs - PICKUP_REMINDER_LEAD_MS + 60_000, committedAtMs: longAgo })).toBe(true);
    expect(reminderDue({ pickupMs, nowMs: pickupMs - 5 * 3600_000, committedAtMs: longAgo })).toBe(false);
    expect(reminderDue({ pickupMs, nowMs: pickupMs - 5 * 60_000, committedAtMs: longAgo })).toBe(false);
    expect(reminderDue({ pickupMs, nowMs: pickupMs - 3600_000, committedAtMs: pickupMs - 3 * 3600_000 })).toBe(false);
    expect(reminderDue({ pickupMs: null, nowMs: 0, committedAtMs: 0 })).toBe(false);
  });
});
