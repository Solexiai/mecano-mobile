// Option A (2026-10-27) — part du chauffeur virée par Stripe Connect à la
// capture d'une destination charge, et lecture du mode de versement.
import { connectTransferShare, parsePayoutMode } from "../../src/lib/payoutMode";
import { PaymentStatuses } from "../../src/lib/types";

describe("parsePayoutMode", () => {
  it("absent, inconnu ou stripe_direct -> stripe_direct ; movik_batch -> movik_batch", () => {
    expect(parsePayoutMode(undefined)).toBe("stripe_direct");
    expect(parsePayoutMode("n'importe quoi")).toBe("stripe_direct");
    expect(parsePayoutMode("stripe_direct")).toBe("stripe_direct");
    expect(parsePayoutMode("movik_batch")).toBe("movik_batch");
  });
});

describe("connectTransferShare", () => {
  const base = {
    status: PaymentStatuses.CAPTURED,
    connected_account_id: "acct_123",
    amount_captured_minor: 10000,
    application_fee_minor: 1500,
    amount_refunded_minor: 0,
  };

  it("destination charge capturée : capturé moins application_fee", () => {
    expect(connectTransferShare(base)).toEqual({ amountMinor: 8500, reversedMinor: 0, netMinor: 8500 });
  });

  it("sans compte connecté, non capturé ou montant nul : null", () => {
    expect(connectTransferShare({ ...base, connected_account_id: null })).toBeNull();
    expect(connectTransferShare({ ...base, status: PaymentStatuses.AUTHORIZED })).toBeNull();
    expect(connectTransferShare({ ...base, status: PaymentStatuses.CAPTURE_PENDING })).toBeNull();
    expect(connectTransferShare({ ...base, amount_captured_minor: 0 })).toBeNull();
    expect(connectTransferShare({ ...base, application_fee_minor: 20000 })).toBeNull();
  });

  it("remboursement partiel : renversement au prorata (Stripe fait foi)", () => {
    // 25 % remboursé -> 25 % de la part virée renversée.
    expect(connectTransferShare({ ...base, status: PaymentStatuses.PARTIALLY_REFUNDED, amount_refunded_minor: 2500 }))
      .toEqual({ amountMinor: 8500, reversedMinor: 2125, netMinor: 6375 });
  });

  it("remboursement total : tout est renversé, jamais au-delà de la part virée", () => {
    expect(connectTransferShare({ ...base, status: PaymentStatuses.REFUNDED, amount_refunded_minor: 10000 }))
      .toEqual({ amountMinor: 8500, reversedMinor: 8500, netMinor: 0 });
    expect(connectTransferShare({ ...base, status: PaymentStatuses.REFUNDED, amount_refunded_minor: 99999 }))
      .toEqual({ amountMinor: 8500, reversedMinor: 8500, netMinor: 0 });
  });

  it("litige / rétrofacturation : la part reste décrite (le ledger porte les frais de litige)", () => {
    expect(connectTransferShare({ ...base, status: PaymentStatuses.CHARGEBACK })?.amountMinor).toBe(8500);
  });
});
