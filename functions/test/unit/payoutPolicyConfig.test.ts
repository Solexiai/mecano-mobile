// ---------------------------------------------------------------------------
// Tests unitaires — resolveHoldPeriodHours (updatePayoutPolicyConfiguration.ts)
//
// Vérifie la résolution de la période de rétention applicable à un
// chauffeur selon son profil de risque (Phase 6, point 9) : jamais de
// valeur hardcodée dans la logique de calcul elle-même — uniquement la
// SÉLECTION du bon champ de la configuration lue depuis Firestore.
// ---------------------------------------------------------------------------

import { admin } from "../../src/lib/admin";
import { resolveHoldPeriodHours } from "../../src/functions/updatePayoutPolicyConfiguration";
import { PayoutPolicyConfigDoc } from "../../src/lib/types";

function buildPolicy(overrides: Partial<PayoutPolicyConfigDoc> = {}): PayoutPolicyConfigDoc {
  return {
    default_hold_period_hours: 72,
    new_driver_hold_period_hours: 168,
    risky_driver_hold_period_hours: 336,
    updated_at: admin.firestore.Timestamp.now(),
    updated_by_user_id: "admin_test",
    ...overrides,
  };
}

describe("resolveHoldPeriodHours", () => {
  it("renvoie default_hold_period_hours si aucun profil chauffeur n'est fourni", () => {
    const policy = buildPolicy();
    expect(resolveHoldPeriodHours(policy, undefined)).toBe(72);
  });

  it("renvoie risky_driver_hold_period_hours si le chauffeur est suspendu", () => {
    const policy = buildPolicy();
    expect(
      resolveHoldPeriodHours(policy, { completed_missions: 50, suspended_at: admin.firestore.Timestamp.now() })
    ).toBe(336);
  });

  it("renvoie new_driver_hold_period_hours si le chauffeur a moins de 5 missions complétées", () => {
    const policy = buildPolicy();
    expect(resolveHoldPeriodHours(policy, { completed_missions: 4 })).toBe(168);
    expect(resolveHoldPeriodHours(policy, { completed_missions: 0 })).toBe(168);
  });

  it("renvoie default_hold_period_hours pour un chauffeur établi (>= 5 missions), non suspendu", () => {
    const policy = buildPolicy();
    expect(resolveHoldPeriodHours(policy, { completed_missions: 5 })).toBe(72);
    expect(resolveHoldPeriodHours(policy, { completed_missions: 500 })).toBe(72);
  });

  it("priorise le statut 'à risque' (suspendu) même si le chauffeur a beaucoup de missions complétées", () => {
    const policy = buildPolicy();
    expect(
      resolveHoldPeriodHours(policy, {
        completed_missions: 999,
        suspended_at: admin.firestore.Timestamp.now(),
      })
    ).toBe(336);
  });

  it("utilise les valeurs de la configuration fournie, jamais une constante interne", () => {
    const customPolicy = buildPolicy({
      default_hold_period_hours: 10,
      new_driver_hold_period_hours: 20,
      risky_driver_hold_period_hours: 30,
    });
    expect(resolveHoldPeriodHours(customPolicy, undefined)).toBe(10);
    expect(resolveHoldPeriodHours(customPolicy, { completed_missions: 1 })).toBe(20);
    expect(
      resolveHoldPeriodHours(customPolicy, { completed_missions: 1, suspended_at: admin.firestore.Timestamp.now() })
    ).toBe(30);
  });
});
