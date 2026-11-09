// Pourboire au chauffeur (décision Daniel, 2026-11-09) — calculs purs.
import { DRIVER_TIP_POLICY, parseTipChoice, tipAmountMinor, tipBaseMinor, tipPaymentId } from "../../src/lib/driverTip";

describe("driverTip", () => {
  it("base = prix payé moins les taxes du devis verrouillé", () => {
    expect(tipBaseMinor({ customer_total_minor: 7243, quote_breakdown: { taxAmount: 9.43 } })).toBe(6300);
    expect(tipBaseMinor({ customer_total_minor: 5000 })).toBe(5000);
    expect(tipBaseMinor({ customer_total: 50.5 })).toBe(5050);
    expect(tipBaseMinor({})).toBe(0);
  });

  it("10, 15, 20 % arrondis au cent, jamais sous 1 $ ni au-dessus de 100 $", () => {
    expect(tipAmountMinor({ kind: "percent", percent: 10 }, 6300)).toBe(630);
    expect(tipAmountMinor({ kind: "percent", percent: 15 }, 6300)).toBe(945);
    expect(tipAmountMinor({ kind: "percent", percent: 20 }, 6333)).toBe(1267);
    expect(tipAmountMinor({ kind: "percent", percent: 10 }, 500)).toBe(DRIVER_TIP_POLICY.min_minor);
    expect(tipAmountMinor({ kind: "percent", percent: 20 }, 900000)).toBe(DRIVER_TIP_POLICY.max_minor);
    expect(tipAmountMinor({ kind: "amount", amountMinor: 1200 }, 6300)).toBe(1200);
  });

  it("refuse tout autre choix (pourcentage libre, montant hors bornes, les deux, aucun)", () => {
    expect(parseTipChoice({ percent: 15 })).toEqual({ kind: "percent", percent: 15 });
    expect(parseTipChoice({ amountMinor: 500 })).toEqual({ kind: "amount", amountMinor: 500 });
    expect(parseTipChoice({ percent: 50 })).toBeNull();
    expect(parseTipChoice({ percent: "15" })).toBeNull();
    expect(parseTipChoice({ amountMinor: 99 })).toBeNull();
    expect(parseTipChoice({ amountMinor: 10001 })).toBeNull();
    expect(parseTipChoice({ amountMinor: 12.5 })).toBeNull();
    expect(parseTipChoice({ percent: 10, amountMinor: 500 })).toBeNull();
    expect(parseTipChoice({})).toBeNull();
  });

  it("un identifiant de paiement par livraison, puis par essai après un refus", () => {
    expect(tipPaymentId("m1")).toBe("tip_m1");
    expect(tipPaymentId("m1", 2)).toBe("tip_m1_2");
  });
});
