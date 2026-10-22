import { BOOKING_PAYMENT_CYCLE, parseBookingPolicy } from '../../src/lib/bookingContract';
/** Synthetic terms for isolated tests only. Never a production approval. */
export function testBookingPolicy(version = 'TEST-ONLY') {
  const content = { fr: 'SIMULATION UNIQUEMENT — aucun engagement commercial.', en: 'SIMULATION ONLY — no commercial commitment.', es: 'SOLO SIMULACIÓN — sin compromiso comercial.' };
  return parseBookingPolicy({ approved: true, schema_version: 2, version,
    approval_reference: 'TEST FIXTURE ONLY', setup_enabled: true, payment_cycle: BOOKING_PAYMENT_CYCLE,
    payment_text: content, cancellation_text: content,
    documents: Object.fromEntries(['booking','terms','privacy'].map(key => [key, { version: `${version}-${key}`, url: `https://example.invalid/${key}`, content }])) })!;
}
export function testBookingConsent(version = 'TEST-ONLY') {
  const p = testBookingPolicy(version);
  return { accepted: true, terms_version: p.version, contract_hash: p.contract_hash,
    booking_terms_version: p.documents.booking.version, general_terms_version: p.documents.terms.version,
    privacy_presented_version: p.documents.privacy.version, locale: 'fr', marketing: false };
}
