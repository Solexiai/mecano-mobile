// ---------------------------------------------------------------------------
// Tests unitaires — payoutStateMachine.ts (Phase 6, points 6 + 9).
//
// Vérifie que la machine d'état des versements chauffeur (driver_payouts)
// autorise EXACTEMENT les transitions documentées et rejette toute
// transition non prévue, en particulier les raccourcis dangereux (ex:
// pending -> paid directement, sans passer par processing).
// ---------------------------------------------------------------------------

import {
  assertValidPayoutTransition,
  InvalidPayoutTransitionError,
  isTerminalPayoutStatus,
  isValidPayoutTransition,
} from "../../src/lib/payoutStateMachine";
import { PayoutStatuses } from "../../src/lib/types";

describe("payoutStateMachine — transitions valides", () => {
  it("pending -> held est valide (chauffeur nouveau/à risque)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.PENDING, PayoutStatuses.HELD)).toBe(true);
  });

  it("pending -> eligible est valide (aucune rétention nécessaire)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.PENDING, PayoutStatuses.ELIGIBLE)).toBe(true);
  });

  it("held -> eligible est valide (rétention écoulée)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.HELD, PayoutStatuses.ELIGIBLE)).toBe(true);
  });

  it("eligible -> scheduled -> processing -> paid forment une chaîne valide", () => {
    expect(isValidPayoutTransition(PayoutStatuses.ELIGIBLE, PayoutStatuses.SCHEDULED)).toBe(true);
    expect(isValidPayoutTransition(PayoutStatuses.SCHEDULED, PayoutStatuses.PROCESSING)).toBe(true);
    expect(isValidPayoutTransition(PayoutStatuses.PROCESSING, PayoutStatuses.PAID)).toBe(true);
  });

  it("processing -> failed est valide (refus fournisseur)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.PROCESSING, PayoutStatuses.FAILED)).toBe(true);
  });

  it("failed -> scheduled est valide (nouvelle tentative, même idempotency_key)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.FAILED, PayoutStatuses.SCHEDULED)).toBe(true);
  });

  it("paid -> reversed est valide (remboursement post-versement, point 20)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.PAID, PayoutStatuses.REVERSED)).toBe(true);
  });
});

describe("payoutStateMachine — transitions invalides (raccourcis dangereux)", () => {
  it("pending -> paid est INVALIDE (ne doit jamais sauter processing)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.PENDING, PayoutStatuses.PAID)).toBe(false);
  });

  it("eligible -> paid est INVALIDE (doit passer par scheduled puis processing)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.ELIGIBLE, PayoutStatuses.PAID)).toBe(false);
  });

  it("scheduled -> paid est INVALIDE (doit passer par processing)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.SCHEDULED, PayoutStatuses.PAID)).toBe(false);
  });

  it("reversed -> * est toujours INVALIDE (état terminal)", () => {
    expect(isValidPayoutTransition(PayoutStatuses.REVERSED, PayoutStatuses.PAID)).toBe(false);
    expect(isValidPayoutTransition(PayoutStatuses.REVERSED, PayoutStatuses.PENDING)).toBe(false);
  });

  it("assertValidPayoutTransition lève InvalidPayoutTransitionError sur transition illégale", () => {
    expect(() =>
      assertValidPayoutTransition(PayoutStatuses.PENDING, PayoutStatuses.PAID)
    ).toThrow(InvalidPayoutTransitionError);
  });

  it("assertValidPayoutTransition ne lève rien sur transition légale", () => {
    expect(() =>
      assertValidPayoutTransition(PayoutStatuses.ELIGIBLE, PayoutStatuses.SCHEDULED)
    ).not.toThrow();
  });
});

describe("payoutStateMachine — états terminaux", () => {
  it("REVERSED est terminal", () => {
    expect(isTerminalPayoutStatus(PayoutStatuses.REVERSED)).toBe(true);
  });

  it("PENDING, ELIGIBLE, SCHEDULED, PROCESSING, PAID, HELD, FAILED ne sont PAS terminaux", () => {
    expect(isTerminalPayoutStatus(PayoutStatuses.PENDING)).toBe(false);
    expect(isTerminalPayoutStatus(PayoutStatuses.ELIGIBLE)).toBe(false);
    expect(isTerminalPayoutStatus(PayoutStatuses.SCHEDULED)).toBe(false);
    expect(isTerminalPayoutStatus(PayoutStatuses.PROCESSING)).toBe(false);
    expect(isTerminalPayoutStatus(PayoutStatuses.PAID)).toBe(false); // paid -> reversed reste possible
    expect(isTerminalPayoutStatus(PayoutStatuses.HELD)).toBe(false);
    expect(isTerminalPayoutStatus(PayoutStatuses.FAILED)).toBe(false); // failed -> scheduled reste possible
  });
});
