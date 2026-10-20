import { onCall } from 'firebase-functions/v2/https';
import { db, admin } from '../lib/admin';
import { requireSignedIn, requireAdminOrAbove } from '../lib/auth';
import { invalidArgument, notFound } from '../lib/errors';
import { writeAuditLogInTransaction } from '../lib/audit';
/** Explicit administrative verification; never inferred from GPS or a manufacturer catalogue. */
export const verifyDriverServiceBase = onCall(async (request) => {
    const ctx = requireSignedIn(request);
    requireAdminOrAbove(ctx);
    const { driverId, evidenceReference, confirmed } = request.data ?? {};
    if (typeof driverId !== 'string' || !driverId || driverId.includes('/') || confirmed !== true ||
        typeof evidenceReference !== 'string' || evidenceReference.trim().length < 10 || evidenceReference.length > 500)
        throw invalidArgument('Confirmez la vérification réelle et sa référence de preuve.');
    await db.runTransaction(async (tx) => {
        const ref = db.doc('driver_profiles/' + driverId), d = (await tx.get(ref)).data();
        if (!d)
            throw notFound();
        if (!Number.isFinite(d.base_lat) || !Number.isFinite(d.base_lng) || Math.abs(d.base_lat) > 90 || Math.abs(d.base_lng) > 180)
            throw invalidArgument('Coordonnées de base invalides.');
        tx.update(ref, { base_location_verified: true, verified_base_lat: d.base_lat, verified_base_lng: d.base_lng,
            base_location_reviewed_at: admin.firestore.Timestamp.now(), base_location_reviewed_by: ctx.uid });
        tx.set(ref.collection('service_base_reviews').doc(), { reviewed_by: ctx.uid, reviewed_at: admin.firestore.Timestamp.now(), evidence_reference: evidenceReference.trim(), latitude: d.base_lat, longitude: d.base_lng });
        writeAuditLogInTransaction(tx, { actorUserId: ctx.uid, actorRole: ctx.role ?? 'admin', action: 'service_base_verified', sourceFunction: 'verifyDriverServiceBase', targetId: driverId, metadata: { verified: true } });
    });
    return { success: true };
});
