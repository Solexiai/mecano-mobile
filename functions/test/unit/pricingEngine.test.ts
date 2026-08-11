// ---------------------------------------------------------------------------
// Tests unitaires — pricingEngine.ts (port serveur des moteurs financiers)
//
// Vérifie la "rigoureuse équivalence" revendiquée dans les commentaires du
// fichier avec les moteurs Dart équivalents, en testant EXACTEMENT les mêmes
// scénarios que test/finance/*.dart côté Flutter :
//   - commission 10% / 12% / 15%
//   - commission minimum ($ plancher)
//   - maximum effectif (% plafond)
//   - Founding Driver (période promo + taux préférentiel)
//   - promotion chauffeur expirée
//   - pourboire 100%
//   - bonus (ajustement manuel)
//   - promotion client (remise)
// ---------------------------------------------------------------------------

import {
  calculateCustomerQuote,
  calculateDriverCompensation,
  capEffectiveRate,
  resolveCommission,
} from "../../src/lib/pricingEngine";
import { buildCommissionConfig, buildPricingConfig } from "./fixtures";

describe("calculateCustomerQuote — calcul de base", () => {
  it("calcule correctement missionBaseValue, subtotal et customerTotal (sans remise)", () => {
    const config = buildPricingConfig();
    const result = calculateCustomerQuote(config, {
      vehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
    });

    // base = 20 + 1.5*10 + 0.3*20 = 41 (> minimumCharge 25)
    expect(result.missionBaseValue).toBeCloseTo(41.0, 9);
    expect(result.customerDiscountAmount).toBe(0);
    expect(result.subtotal).toBeCloseTo(41.0, 9);
    expect(result.customerTotal).toBeCloseTo(41.0, 9);
  });

  it("applique le minimumCharge quand le tarif brut est trop bas", () => {
    const config = buildPricingConfig();
    const result = calculateCustomerQuote(config, {
      vehicleCategory: "cargoVan",
      distanceKm: 1,
      estimatedDurationMinutes: 1,
    });

    // base brute = 20 + 1.5 + 0.3 = 21.8 < 25 => plancher appliqué
    expect(result.missionBaseValue).toBeCloseTo(25.0, 9);
  });

  it("lève une erreur explicite si aucune règle de tarification ne correspond à la catégorie", () => {
    const config = buildPricingConfig();
    expect(() =>
      calculateCustomerQuote(config, {
        vehicleCategory: "unknown_category",
        distanceKm: 10,
        estimatedDurationMinutes: 10,
      })
    ).toThrow(/Aucune règle de tarification/);
  });
});

describe("calculateCustomerQuote — promotion client (customerDiscountAmount)", () => {
  it("une remise valide réduit le subtotal, et les frais de service + taxes sont recalculés APRÈS remise", () => {
    const config = buildPricingConfig({
      customer_service_fee: { service_fee_rate: 0.05, minimum_service_fee: 0 },
      tax_rate: 0.1,
    });

    const noDiscount = calculateCustomerQuote(config, {
      vehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
    });
    expect(noDiscount.subtotal).toBeCloseTo(41.0, 9);

    const withDiscount = calculateCustomerQuote(config, {
      vehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
      customerDiscountAmount: 10,
    });

    expect(withDiscount.customerDiscountAmount).toBeCloseTo(10.0, 9);
    // subtotal après remise = 41 - 10 = 31
    expect(withDiscount.subtotal).toBeCloseTo(31.0, 9);
    // customerServiceFee = 5% * 31 (post-remise), PAS 5% * 41
    expect(withDiscount.customerServiceFee).toBeCloseTo(31.0 * 0.05, 9);
    const expectedTax = (31.0 + 31.0 * 0.05) * 0.1;
    expect(withDiscount.taxAmount).toBeCloseTo(expectedTax, 9);
    expect(withDiscount.customerTotal).toBeLessThan(noDiscount.customerTotal);
  });

  it("une remise supérieure au subtotal brut est plafonnée exactement au subtotal (jamais négatif)", () => {
    const config = buildPricingConfig();
    const result = calculateCustomerQuote(config, {
      vehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
      customerDiscountAmount: 999999,
    });

    expect(result.customerDiscountAmount).toBeCloseTo(41.0, 9);
    expect(result.subtotal).toBeCloseTo(0.0, 9);
    expect(result.customerTotal).toBeGreaterThanOrEqual(0);
  });

  it("une remise négative ou nulle est ignorée (aucun effet, pas de crash)", () => {
    const config = buildPricingConfig();
    const result = calculateCustomerQuote(config, {
      vehicleCategory: "cargoVan",
      distanceKm: 10,
      estimatedDurationMinutes: 20,
      customerDiscountAmount: -50,
    });

    expect(result.customerDiscountAmount).toBe(0);
    expect(result.subtotal).toBeCloseTo(41.0, 9);
  });
});

describe("resolveCommission — taux standard par palier (10% / 12% / 15%)", () => {
  for (const rate of [0.1, 0.12, 0.15]) {
    it(`applique le taux standard configuré (${rate})`, () => {
      const result = resolveCommission({
        nowMillis: Date.now(),
        standardRate: rate,
      });

      expect(result.rate).toBe(rate);
      expect(result.program).toBe("standard");
      expect(result.reason).toBe("standard_rate");
    });
  }
});

describe("capEffectiveRate — plancher (minimum) et plafond (maximum effectif)", () => {
  it("la commission minimum en $ est appliquée quand le taux brut ne suffit pas", () => {
    const effectiveRate = capEffectiveRate({
      resolvedRate: 0.1,
      missionBaseValue: 10,
      minimumPlatformCommission: 5,
      maximumEffectiveCommissionRate: 1.0,
    });

    // 5$/10$ = 50% de taux effectif réel
    expect(effectiveRate).toBeCloseTo(0.5, 9);
  });

  it("le taux effectif ne dépasse jamais le maximum effectif configuré", () => {
    const effectiveRate = capEffectiveRate({
      resolvedRate: 0.1,
      missionBaseValue: 10,
      minimumPlatformCommission: 5,
      maximumEffectiveCommissionRate: 0.3,
    });

    expect(effectiveRate).toBeCloseTo(0.3, 9);
  });

  it("quand le taux brut dépasse déjà le plancher, le taux nominal est conservé", () => {
    const effectiveRate = capEffectiveRate({
      resolvedRate: 0.15,
      missionBaseValue: 100,
      minimumPlatformCommission: 5,
      maximumEffectiveCommissionRate: 0.3,
    });

    expect(effectiveRate).toBeCloseTo(0.15, 9);
  });

  it("missionBaseValue <= 0 retourne le taux résolu sans division par zéro", () => {
    const effectiveRate = capEffectiveRate({
      resolvedRate: 0.12,
      missionBaseValue: 0,
      minimumPlatformCommission: 5,
      maximumEffectiveCommissionRate: 0.3,
    });

    expect(effectiveRate).toBe(0.12);
  });
});

describe("resolveCommission — Founding Driver", () => {
  const foundingProgram = {
    promotionalCommissionRate: 0.05,
    preferredCommissionRate: 0.08,
  };
  const now = new Date(2025, 5, 15, 12, 0, 0).getTime();

  it("applique le taux PROMOTIONNEL quand la qualification est dans la période promo", () => {
    const result = resolveCommission({
      nowMillis: now,
      standardRate: 0.15,
      foundingQualification: {
        status: "qualified",
        promotionalPeriodEndsAtMillis: now + 20 * 24 * 3600 * 1000,
      },
      foundingProgram,
    });

    expect(result.rate).toBe(foundingProgram.promotionalCommissionRate);
    expect(result.program).toBe("founding_preferred");
    expect(result.reason).toBe("founding_driver_promotional_period");
  });

  it("applique le taux PRÉFÉRENTIEL une fois la période promo terminée", () => {
    const result = resolveCommission({
      nowMillis: now,
      standardRate: 0.15,
      foundingQualification: {
        status: "qualified",
        promotionalPeriodEndsAtMillis: now - 10 * 24 * 3600 * 1000,
      },
      foundingProgram,
    });

    expect(result.rate).toBe(foundingProgram.preferredCommissionRate);
    expect(result.program).toBe("founding_preferred");
    expect(result.reason).toBe("founding_driver_preferred_rate");
  });

  it("un Founding Driver non 'qualified' (ex: revoked) retombe sur le taux standard", () => {
    const result = resolveCommission({
      nowMillis: now,
      standardRate: 0.15,
      foundingQualification: {
        status: "revoked",
        promotionalPeriodEndsAtMillis: now + 20 * 24 * 3600 * 1000,
      },
      foundingProgram,
    });

    expect(result.rate).toBe(0.15);
    expect(result.program).toBe("standard");
  });
});

describe("resolveCommission — promotion chauffeur expirée", () => {
  const now = new Date(2025, 5, 15, 12, 0, 0).getTime();

  it("une driver_promotion EXPIRÉE (endsAt dans le passé) ne doit JAMAIS être appliquée", () => {
    const result = resolveCommission({
      nowMillis: now,
      standardRate: 0.15,
      activePromotion: {
        promotionalCommissionRate: 0.05,
        startsAtMillis: now - 60 * 24 * 3600 * 1000,
        endsAtMillis: now - 24 * 3600 * 1000, // expirée hier
        isActive: true,
      },
    });

    expect(result.rate).toBe(0.15);
    expect(result.program).toBe("standard");
    expect(result.reason).toBe("standard_rate");
  });

  it("une driver_promotion isActive=false ne doit JAMAIS être appliquée, même dans sa fenêtre temporelle", () => {
    const result = resolveCommission({
      nowMillis: now,
      standardRate: 0.15,
      activePromotion: {
        promotionalCommissionRate: 0.05,
        startsAtMillis: now - 5 * 24 * 3600 * 1000,
        endsAtMillis: now + 5 * 24 * 3600 * 1000,
        isActive: false,
      },
    });

    expect(result.rate).toBe(0.15);
    expect(result.program).toBe("standard");
  });

  it("une driver_promotion VALIDE (active et dans sa fenêtre) est bien appliquée", () => {
    const result = resolveCommission({
      nowMillis: now,
      standardRate: 0.15,
      activePromotion: {
        promotionalCommissionRate: 0.05,
        startsAtMillis: now - 5 * 24 * 3600 * 1000,
        endsAtMillis: now + 5 * 24 * 3600 * 1000,
        isActive: true,
      },
    });

    expect(result.rate).toBe(0.05);
    expect(result.program).toBe("promotional");
    expect(result.reason).toBe("active_driver_promotion");
  });
});

describe("calculateDriverCompensation — pourboire 100% et bonus manuel", () => {
  const pricingResult = calculateCustomerQuote(buildPricingConfig(), {
    vehicleCategory: "cargoVan",
    distanceKm: 53.333333333333336, // choisi pour obtenir subtotal = 100 exactement
    estimatedDurationMinutes: 0,
  });
  // Vérifie que la fixture donne bien subtotal = 100 (sanity check du test).
  it("sanity check: le subtotal de la fixture est bien 100", () => {
    expect(pricingResult.subtotal).toBeCloseTo(100.0, 6);
  });

  const resolvedStandard = { rate: 0.15, program: "standard" as const, reason: "standard_rate" };
  const commissionConfig = buildCommissionConfig();

  it("driverGrossEarnings = subtotal - commission plateforme (15%)", () => {
    const result = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedStandard,
      commissionConfig,
    });

    // 100 * 15% = 15 => driverOfferAmount = 85
    expect(result.driverOfferAmount).toBeCloseTo(85.0, 6);
    expect(result.tipAmount).toBe(0);
    expect(result.driverNetMissionEarnings).toBeCloseTo(85.0, 6);
  });

  it("un pourboire de 20$ est intégralement redirigé au chauffeur (100%, aucune commission dessus)", () => {
    const result = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedStandard,
      commissionConfig,
      tipAmount: 20,
    });

    expect(result.driverOfferAmount).toBeCloseTo(85.0, 6);
    expect(result.tipAmount).toBeCloseTo(20.0, 9);
    expect(result.driverNetMissionEarnings).toBeCloseTo(105.0, 6);
  });

  it("un bonus manuel positif est ajouté intégralement au gain net du chauffeur", () => {
    const result = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedStandard,
      commissionConfig,
      manualAdjustments: [{ amount: 15, reason: "Bonus ponctualité" }],
    });

    expect(result.manualAdjustmentsTotal).toBeCloseTo(15.0, 9);
    expect(result.driverNetMissionEarnings).toBeCloseTo(100.0, 6);
  });

  it("une pénalité manuelle (montant négatif) réduit le gain net du chauffeur", () => {
    const result = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedStandard,
      commissionConfig,
      manualAdjustments: [{ amount: -10, reason: "Retard signalé" }],
    });

    expect(result.manualAdjustmentsTotal).toBeCloseTo(-10.0, 9);
    expect(result.driverNetMissionEarnings).toBeCloseTo(75.0, 6);
  });

  it("pourboire + bonus se cumulent correctement", () => {
    const result = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedStandard,
      commissionConfig,
      tipAmount: 30,
      manualAdjustments: [{ amount: 25, reason: "Bonus événement spécial" }],
    });

    // net = offer(85) + tip(30) + bonus(25) = 140
    expect(result.driverNetMissionEarnings).toBeCloseTo(140.0, 6);
  });

  it("un taux de commission Founding Driver (5%) augmente le gain net vs. taux standard", () => {
    const resolvedFounding = {
      rate: 0.05,
      program: "founding_preferred" as const,
      reason: "founding_driver_promotional_period",
    };

    const standardResult = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedStandard,
      commissionConfig,
    });
    const foundingResult = calculateDriverCompensation({
      pricingResult,
      resolvedCommission: resolvedFounding,
      commissionConfig,
    });

    expect(foundingResult.driverNetMissionEarnings).toBeGreaterThan(
      standardResult.driverNetMissionEarnings
    );
    expect(foundingResult.driverOfferAmount).toBeCloseTo(95.0, 6);
  });
});
