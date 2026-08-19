// ---------------------------------------------------------------------------
// Tests unitaires — disputeStateMachine.ts (Phase 6, directive 38 points,
// point 8).
// ---------------------------------------------------------------------------

import {
  assertValidDisputeTransition,
  InvalidDisputeTransitionError,
  isTerminalDisputeStatus,
  isValidDisputeTransition,
} from "../../src/lib/disputeStateMachine";
import { DisputeStatuses } from "../../src/lib/types";

describe("disputeStateMachine — transitions valides", () => {
  it("opened -> under_review est valide", () => {
    expect(
      isValidDisputeTransition(DisputeStatuses.OPENED, DisputeStatuses.UNDER_REVIEW)
    ).toBe(true);
  });

  it("opened -> won directement est valide (provider sans étape under_review)", () => {
    expect(isValidDisputeTransition(DisputeStatuses.OPENED, DisputeStatuses.WON)).toBe(true);
  });

  it("opened -> lost directement est valide", () => {
    expect(isValidDisputeTransition(DisputeStatuses.OPENED, DisputeStatuses.LOST)).toBe(true);
  });

  it("under_review -> won et under_review -> lost sont valides", () => {
    expect(isValidDisputeTransition(DisputeStatuses.UNDER_REVIEW, DisputeStatuses.WON)).toBe(
      true
    );
    expect(isValidDisputeTransition(DisputeStatuses.UNDER_REVIEW, DisputeStatuses.LOST)).toBe(
      true
    );
  });

  it("won -> closed est valide", () => {
    expect(isValidDisputeTransition(DisputeStatuses.WON, DisputeStatuses.CLOSED)).toBe(true);
  });

  it("lost -> reversed est valide (late-win comptable)", () => {
    expect(isValidDisputeTransition(DisputeStatuses.LOST, DisputeStatuses.REVERSED)).toBe(true);
  });

  it("lost -> closed est valide (aucun late-win)", () => {
    expect(isValidDisputeTransition(DisputeStatuses.LOST, DisputeStatuses.CLOSED)).toBe(true);
  });

  it("reversed -> closed est valide", () => {
    expect(isValidDisputeTransition(DisputeStatuses.REVERSED, DisputeStatuses.CLOSED)).toBe(
      true
    );
  });
});

describe("disputeStateMachine — transitions invalides", () => {
  it("opened -> closed directement est INVALIDE (doit passer par won/lost)", () => {
    expect(isValidDisputeTransition(DisputeStatuses.OPENED, DisputeStatuses.CLOSED)).toBe(
      false
    );
  });

  it("closed -> * est toujours INVALIDE (état terminal)", () => {
    expect(isValidDisputeTransition(DisputeStatuses.CLOSED, DisputeStatuses.OPENED)).toBe(
      false
    );
  });

  it("won -> lost est INVALIDE", () => {
    expect(isValidDisputeTransition(DisputeStatuses.WON, DisputeStatuses.LOST)).toBe(false);
  });

  it("assertValidDisputeTransition lève InvalidDisputeTransitionError sur transition illégale", () => {
    expect(() =>
      assertValidDisputeTransition(DisputeStatuses.OPENED, DisputeStatuses.CLOSED)
    ).toThrow(InvalidDisputeTransitionError);
  });
});

describe("disputeStateMachine — états terminaux", () => {
  it("CLOSED est terminal", () => {
    expect(isTerminalDisputeStatus(DisputeStatuses.CLOSED)).toBe(true);
  });

  it("OPENED, UNDER_REVIEW, WON, LOST, REVERSED ne sont PAS terminaux", () => {
    expect(isTerminalDisputeStatus(DisputeStatuses.OPENED)).toBe(false);
    expect(isTerminalDisputeStatus(DisputeStatuses.UNDER_REVIEW)).toBe(false);
    expect(isTerminalDisputeStatus(DisputeStatuses.WON)).toBe(false);
    expect(isTerminalDisputeStatus(DisputeStatuses.LOST)).toBe(false);
    expect(isTerminalDisputeStatus(DisputeStatuses.REVERSED)).toBe(false);
  });
});
