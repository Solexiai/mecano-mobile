import { onCall } from 'firebase-functions/v2/https';
import { db } from '../lib/admin';
import { requireSignedIn } from '../lib/auth';
import { invalidArgument, permissionDenied, failedPrecondition } from '../lib/errors';

/** Owner-only historical receipt. Never substitutes today's terms for a past booking. */
export const getBookingReceipt = onCall(async request => {
  const { uid } = requireSignedIn(request);
  const id = request.data?.missionId;
  if (typeof id !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(id)) throw invalidArgument('Référence invalide.');
  return db.runTransaction(async tx => {
    const mission = (await tx.get(db.doc(`delivery_requests/${id}`))).data();
    if (!mission || mission.customer_id !== uid) throw permissionDenied('Réservation inaccessible.');
    const privateData = (await tx.get(db.doc(`delivery_requests/${id}/private/booking`))).data();
    if (!Number.isSafeInteger(mission.customer_total_minor) || mission.customer_total_minor < 0) throw failedPrecondition('Montant officiel indisponible.');
    const consent = privateData?.consent;
    const acceptance = consent ? { ...consent, acceptedAtMillis: consent.accepted_at?.toMillis() ?? null } : null;
    if (acceptance) delete acceptance.accepted_at;
    return { missionId: id, quoteId: mission.active_quote_id, currency: 'CAD',
      customerTotalMinor: mission.customer_total_minor, breakdown: mission.quote_breakdown ?? {},
      booking: mission.booking_snapshot ?? null, pickup: mission.pickup_address, dropoff: mission.dropoff_address,
      status: mission.status, paymentStatus: mission.payment_status,
      driverAssigned: !!mission.driver_id, createdAtMillis: mission.created_at.toMillis(),
      contract: privateData?.contract_snapshot ?? null,
      acceptance,
      // Legacy excerpts are explicitly labelled incomplete, never upgraded into acceptance.
      legacyTerms: !privateData?.contract_snapshot && consent ? {
        payment_text: consent.payment_text ?? null, cancellation_text: consent.cancellation_text ?? null,
        terms_version: consent.terms_version ?? null } : null,
    };
  });
});
