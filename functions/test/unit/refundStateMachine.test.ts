// ---------------------------------------------------------------------------
// Tests unitaires — refundStateMachine.ts (Phase 6, directive 38 points,
// point 3).
// ---------------------------------------------------------------------------

import {
  assertValidRefundTransition,
  InvalidRefundTransitionError,
  isTerminalRefundStatus,
  isValidRefundTransition,
} from "../../src/lib/refundStateMachine";
import { RefundStatuses } from "../../src/lib/types";

describe("refundStateMachine — transitions valides", () => {
  it("requested -> processing est valide", () => {
    expect(isValidRefundTransition(RefundStatuses.REQUESTED, RefundStatuses.PROCESSING)).toBe(
      true
    );
  });

  it("processing -> succeeded est valide", () => {
    expect(isValidRefundTransition(RefundStatuses.PROCESSING, RefundStatuses.SUCCEEDED)).toBe(
      true
    );
  });

  it("processing -> failed est valide", () => {
    expect(isValidRefundTransition(RefundStatuses.PROCESSING, RefundStatuses.FAILED)).toBe(true);
  });

  it("failed -> processing est valide (nouvelle tentative explicite)", () => {
    expect(isValidRefundTransition(RefundStatuses.FAILED, RefundStatuses.PROCESSING)).toBe(true);
  });
});

describe("refundStateMachine — transitions invalides", () => {
  it("requested -> succeeded est INVALIDE (doit passer par processing)", () => {
    expect(isValidRefundTransition(RefundStatuses.REQUESTED, RefundStatuses.SUCCEEDED)).toBe(
      false
    );
  });

  it("succeeded -> * est toujours INVALIDE (état terminal)", () => {
    expect(isValidRefundTransition(RefundStatuses.SUCCEEDED, RefundStatuses.FAILED)).toBe(false);
    expect(isValidRefundTransition(RefundStatuses.SUCCEEDED, RefundStatuses.PROCESSING)).toBe(
      false
    );
  });

  it("failed -> succeeded est INVALIDE (doit repasser par processing)", () => {
    expect(isValidRefundTransition(RefundStatuses.FAILED, RefundStatuses.SUCCEEDED)).toBe(false);
  });

  it("assertValidRefundTransition lève InvalidRefundTransitionError sur transition illégale", () => {
    expect(() =>
      assertValidRefundTransition(RefundStatuses.REQUESTED, RefundStatuses.SUCCEEDED)
    ).toThrow(InvalidRefundTransitionError);
  });

  it("assertValidRefundTransition ne lève rien sur transition légale", () => {
    expect(() =>
      assertValidRefundTransition(RefundStatuses.REQUESTED, RefundStatuses.PROCESSING)
    ).not.toThrow();
  });
});

describe("refundStateMachine — états terminaux", () => {
  it("SUCCEEDED est terminal", () => {
    expect(isTerminalRefundStatus(RefundStatuses.SUCCEEDED)).toBe(true);
  });

  it("REQUESTED, PROCESSING, FAILED ne sont PAS terminaux", () => {
    expect(isTerminalRefundStatus(RefundStatuses.REQUESTED)).toBe(false);
    expect(isTerminalRefundStatus(RefundStatuses.PROCESSING)).toBe(false);
    expect(isTerminalRefundStatus(RefundStatuses.FAILED)).toBe(false); // failed -> processing reste possible
  });
});
