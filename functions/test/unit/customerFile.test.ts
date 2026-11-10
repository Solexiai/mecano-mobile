// Fiche client du service client (Daniel, 2026-11-10) — calculs purs.
import {
  addressText,
  customerBadges,
  maskPhone,
  missionRow,
  paymentKind,
  paymentRow,
  summarizeCustomer,
} from "../../src/lib/customerFile";

const DAY = 24 * 3600_000;

describe("customerFile", () => {
  it("type de paiement : dépôt, livraison, pourboire, frais", () => {
    expect(paymentKind({ purpose: "deposit" })).toBe("deposit");
    expect(paymentKind({ purpose: "tip" })).toBe("tip");
    expect(paymentKind({ capture_purpose: "mission_fee", fee_kind: "late_cancellation" })).toBe("late_cancellation");
    expect(paymentKind({ capture_purpose: "mission_fee", fee_kind: "customer_failed_delivery" })).toBe("failed_delivery");
    expect(paymentKind({})).toBe("delivery");
  });

  it("chiffres clés : net payé, pourboires, remboursements ; les tests internes ne comptent pas", () => {
    const stats = summarizeCustomer({
      missions: [
        { status: "completed" }, { status: "completed" }, { status: "cancelled" },
        { status: "assigned" }, { status: "completed", assignment_mode: "internal_test" },
      ],
      payments: [
        { purpose: "deposit", status: "captured", amount_captured_minor: 2500 },
        { status: "partially_refunded", amount_captured_minor: 4743, amount_refunded_minor: 1000 },
        { purpose: "tip", status: "captured", amount_captured_minor: 945 },
        { status: "authorized", amount_authorized_minor: 5000 },
        { capture_purpose: "mission_fee", fee_kind: "late_cancellation", status: "captured", amount_captured_minor: 3000 },
        { status: "capture_failed" },
      ],
      ratings: [{ stars: 5 }, { stars: 4 }, { stars: 9 }],
      quotesNotBooked: 2,
    });
    expect(stats).toEqual({
      deliveries: 4, completed: 2, cancelled: 1, active: 1,
      spentMinor: 2500 + 3743 + 945 + 3000, tipsMinor: 945, refundedMinor: 1000,
      lateCancellations: 1, problemPayments: 1, ratingsGiven: 2, averageRatingGiven: 4.5, quotesNotBooked: 2,
    });
  });

  it("pastilles : Nouveau, Fidèle, À surveiller", () => {
    const base = summarizeCustomer({ missions: [], payments: [], ratings: [], quotesNotBooked: 0 });
    const now = Date.now();
    expect(customerBadges(base, now - 5 * DAY, now)).toEqual(["new"]);
    expect(customerBadges(base, now - 90 * DAY, now)).toEqual([]);
    expect(customerBadges({ ...base, completed: 3 }, now - 90 * DAY, now)).toEqual(["loyal"]);
    expect(customerBadges({ ...base, problemPayments: 1 }, null, now)).toEqual(["watch"]);
    expect(customerBadges({ ...base, lateCancellations: 2 }, null, now)).toEqual(["watch"]);
  });

  it("un analyste voit la ville seulement et les 4 derniers chiffres du téléphone", () => {
    expect(addressText({ line1: "12 rue Principale", city: "Granby" }, false)).toBe("12 rue Principale, Granby");
    expect(addressText({ line1: "12 rue Principale", city: "Granby" }, true)).toBe("Granby");
    expect(maskPhone("(450) 555-1234")).toBe("••• ••• 1234");
    expect(maskPhone("")).toBeNull();
    const row = missionRow("m1", {
      status: "completed", customer_total_minor: 7243, pickup_address: { line1: "12 rue", city: "Granby" },
      tip: { status: "paid", amount_minor: 945 }, deposit: { status: "captured" },
      booking_snapshot: { load: { items: [{ quantity: 2, label: "Chaise" }] } },
    }, true);
    expect(row).toMatchObject({ pickup: "Granby", totalMinor: 7243, tipMinor: 945, depositStatus: "captured", items: "2 × Chaise" });
  });

  it("paiement : lien Stripe (test ou réel) et reçu seulement si encaissé", () => {
    expect(paymentRow("p1", { status: "captured", provider_charge_id: "ch_1", provider_payment_intent_id: "pi_1", stripe_environment: "live" }))
      .toMatchObject({ hasReceipt: true, stripeUrl: "https://dashboard.stripe.com/payments/pi_1" });
    expect(paymentRow("p2", { status: "authorized", provider_payment_intent_id: "pi_2", stripe_environment: "test" }))
      .toMatchObject({ hasReceipt: false, stripeUrl: "https://dashboard.stripe.com/test/payments/pi_2" });
  });
});
