// PAY-03 (2026-10-27) — capture_failed est un état de REPRISE, jamais terminal.
import {
  assertValidPaymentTransition,
  isTerminalPaymentStatus,
  isValidPaymentTransition,
} from "../../src/lib/paymentStateMachine";
import { PaymentStatuses } from "../../src/lib/types";

describe("paymentStateMachine — reprise de capture (PAY-03)", () => {
  it("capture_pending -> capture_failed -> capture_pending -> captured", () => {
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_PENDING, PaymentStatuses.CAPTURE_FAILED)).toBe(true);
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_FAILED, PaymentStatuses.CAPTURE_PENDING)).toBe(true);
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_PENDING, PaymentStatuses.CAPTURED)).toBe(true);
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_FAILED, PaymentStatuses.CAPTURED)).toBe(true);
  });
  it("capture_failed -> failed (abandon après relances) ; failed reste terminal", () => {
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_FAILED, PaymentStatuses.FAILED)).toBe(true);
    expect(isTerminalPaymentStatus(PaymentStatuses.FAILED)).toBe(true);
    expect(isTerminalPaymentStatus(PaymentStatuses.CAPTURE_FAILED)).toBe(false);
    expect(() => assertValidPaymentTransition(PaymentStatuses.FAILED, PaymentStatuses.CAPTURE_PENDING)).toThrow();
  });
  it("capture_failed ne mène jamais à un remboursement ni à une annulation", () => {
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_FAILED, PaymentStatuses.REFUNDED)).toBe(false);
    expect(isValidPaymentTransition(PaymentStatuses.CAPTURE_FAILED, PaymentStatuses.CANCELLED)).toBe(false);
    expect(isValidPaymentTransition(PaymentStatuses.AUTHORIZED, PaymentStatuses.CAPTURE_FAILED)).toBe(false);
  });
});
