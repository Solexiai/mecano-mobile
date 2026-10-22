import { createHash } from 'crypto';
import { failedPrecondition } from './errors';

export const BOOKING_PAYMENT_CYCLE = 'setup_then_authorize_on_acceptance_capture_on_completion';
export type LocalizedText = Record<string, string>;
export interface ContractDocument { version: string; url: string; content: LocalizedText }
export interface BookingPolicy {
  approved: true; schema_version: 2; version: string; approval_reference: string;
  terms_url: string; privacy_url: string; booking_terms_url: string;
  cancellation_text: LocalizedText; payment_text: LocalizedText;
  payment_cycle: typeof BOOKING_PAYMENT_CYCLE; setup_enabled: boolean;
  documents: { booking: ContractDocument; terms: ContractDocument; privacy: ContractDocument };
  contract_hash: string;
}
const text = (v: unknown): v is string => typeof v === 'string' && v.trim().length > 0;
function localized(v: unknown): LocalizedText | null {
  if (!v || typeof v !== 'object') return null;
  const result: LocalizedText = {};
  for (const lang of ['fr', 'en', 'es']) {
    const s = (v as Record<string, unknown>)[lang];
    if (s !== undefined && !text(s)) return null;
    if (text(s)) result[lang] = s;
  }
  return result.fr ? result : null;
}
function document(v: unknown): ContractDocument | null {
  if (!v || typeof v !== 'object') return null;
  const d = v as ContractDocument;
  if (!text(d.version) || !text(d.url)) return null;
  try { const u = new URL(d.url); if (u.protocol !== 'https:' || u.username || u.password) return null; }
  catch { return null; }
  const content = localized(d.content);
  return content ? { version: d.version, url: d.url, content } : null;
}
/** Only approved, complete, versioned text can open contractual confirmation.
 * Full text is copied into each reservation: mutable URLs are never evidence.
 * The hash also invalidates acceptance if content is edited without a version bump.
 */
export function parseBookingPolicy(raw: unknown): BookingPolicy | null {
  if (!raw || typeof raw !== 'object') return null;
  const p = raw as BookingPolicy;
  if (p.approved !== true || p.schema_version !== 2 || !text(p.version) ||
      !text(p.approval_reference) || p.payment_cycle !== BOOKING_PAYMENT_CYCLE) return null;
  const booking = document(p.documents?.booking), terms = document(p.documents?.terms), privacy = document(p.documents?.privacy);
  const cancellation = localized(p.cancellation_text), payment = localized(p.payment_text);
  if (!booking || !terms || !privacy || !cancellation || !payment) return null;
  const normalized: Omit<BookingPolicy, 'contract_hash'> = {
    approved: true as const, schema_version: 2 as const, version: p.version,
    approval_reference: p.approval_reference, payment_cycle: BOOKING_PAYMENT_CYCLE,
    terms_url: terms.url, privacy_url: privacy.url, booking_terms_url: booking.url,
    cancellation_text: cancellation, payment_text: payment, setup_enabled: p.setup_enabled === true,
    documents: { booking, terms, privacy },
  };
  const serialized = JSON.stringify(normalized);
  if (Buffer.byteLength(serialized, 'utf8') > 500000) return null;
  return { ...normalized, contract_hash: createHash('sha256').update(serialized).digest('hex') };
}
export interface BookingConsent {
  accepted: boolean; terms_version: string; contract_hash: string;
  booking_terms_version: string; general_terms_version: string;
  privacy_presented_version: string; locale: string; marketing?: boolean;
}
export function requireBookingConsent(policy: BookingPolicy | null, value: unknown): asserts policy is BookingPolicy {
  const c = value as BookingConsent | undefined;
  if (!policy || c?.accepted !== true || c.terms_version !== policy.version ||
      c.contract_hash !== policy.contract_hash || c.booking_terms_version !== policy.documents.booking.version ||
      c.general_terms_version !== policy.documents.terms.version || c.privacy_presented_version !== policy.documents.privacy.version ||
      !['fr', 'en', 'es'].includes(c.locale)) {
    throw failedPrecondition('Les conditions ont changé ou doivent être acceptées. Consultez leur version actuelle avant de confirmer.');
  }
}
