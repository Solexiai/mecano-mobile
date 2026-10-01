import { failedPrecondition } from './errors';
export interface CardSetup { id: string; url: string | null; complete: boolean; customerId: string; paymentMethodId: string | null; livemode: boolean; quoteId: string; userId: string }
export function verifyCardSetup(s: CardSetup, expected: { customerId: string; quoteId: string; userId: string; environment: string }): string | null {
  if (s.customerId !== expected.customerId || s.quoteId !== expected.quoteId || s.userId !== expected.userId || s.livemode !== (expected.environment === 'live')) throw failedPrecondition('La session de carte ne correspond pas à cette réservation.');
  return s.complete && s.paymentMethodId ? s.paymentMethodId : null;
}
