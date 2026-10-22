import { onCall } from 'firebase-functions/v2/https';
import { admin, db } from '../lib/admin';
import { requireAnyRole, requireSignedIn } from '../lib/auth';
import { failedPrecondition, invalidArgument, permissionDenied } from '../lib/errors';
import { OPEN_FOR_ACCEPTANCE_STATUSES, PlatformRoles } from '../lib/types';

/** Declining an offer affects only this driver, never the mission or its money. */
export const declineDeliveryOffer = onCall(async request => {
  const ctx = requireSignedIn(request);
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const missionId = request.data?.missionId;
  if (typeof missionId !== 'string' || !/^[a-zA-Z0-9_-]{1,100}$/.test(missionId)) {
    throw invalidArgument('Mission invalide.');
  }
  return db.runTransaction(async tx => {
    const [missionSnap, driverSnap, offers] = await Promise.all([
      tx.get(db.doc('delivery_requests/' + missionId)),
      tx.get(db.doc('driver_profiles/' + ctx.uid)),
      tx.get(db.collection('delivery_offers').where('mission_id','==',missionId).where('driver_id','==',ctx.uid)),
    ]);
    const driver = driverSnap.data(), mission = missionSnap.data();
    if (driver?.status !== 'approved' || driver.documents_all_valid !== true || offers.empty) {
      throw permissionDenied('Offre inaccessible.');
    }
    if (offers.docs.every(doc => doc.data().status === 'declined')) return {declined:true};
    if (!mission || mission.driver_id || !OPEN_FOR_ACCEPTANCE_STATUSES.includes(mission.status)) {
      throw failedPrecondition('Cette demande n’est plus disponible.');
    }
    const now = admin.firestore.Timestamp.now();
    const pending = offers.docs.filter(doc => {
      const offer = doc.data();
      return offer.status === 'pending' && typeof offer.expires_at?.toMillis === 'function' &&
        offer.expires_at.toMillis() > now.toMillis();
    });
    if (!pending.length) throw failedPrecondition('Cette offre a expiré.');
    for (const offer of pending) tx.update(offer.ref,{status:'declined',declined_at:now});
    return {declined:true};
  });
});
