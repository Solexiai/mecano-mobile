import { onCall } from 'firebase-functions/v2/https';
import { admin, db } from '../lib/admin';
import { requireAnyRole, requireSignedIn } from '../lib/auth';
import { failedPrecondition, invalidArgument, permissionDenied } from '../lib/errors';
import { normalizeDriverAgenda } from '../lib/driverAgenda';
import { PlatformRoles } from '../lib/types';

export const getDriverAgenda = onCall(async request => {
  const ctx = requireSignedIn(request);
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const profile = await db.doc('driver_profiles/' + ctx.uid).get();
  if (!profile.exists) throw permissionDenied('Profil chauffeur requis.');
  const doc = await db.doc('driver_agendas/' + ctx.uid).get();
  const data = doc.data();
  return { revision: data?.revision ?? 0, agenda: data ? normalizeDriverAgenda(data) : { windows: [], blocked: [] },
    configured: doc.exists, dispatch_connected: false, external_sync_connected: false };
});

export const saveDriverAgenda = onCall(async request => {
  const ctx = requireSignedIn(request);
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const revision = request.data?.revision;
  if (!Number.isSafeInteger(revision) || revision < 0) throw invalidArgument('Version d’agenda invalide.');
  const agenda = normalizeDriverAgenda(request.data?.agenda);
  const ref = db.doc('driver_agendas/' + ctx.uid);
  await db.runTransaction(async tx => {
    const [profile, current] = await Promise.all([
      tx.get(db.doc('driver_profiles/' + ctx.uid)), tx.get(ref),
    ]);
    if (!profile.exists) throw permissionDenied('Profil chauffeur requis.');
    if ((current.data()?.revision ?? 0) !== revision) {
      throw failedPrecondition('L’agenda a changé sur un autre appareil. Rechargez-le avant de réessayer.');
    }
    tx.set(ref, { ...agenda, revision: revision + 1, driver_id: ctx.uid,
      updated_at: admin.firestore.FieldValue.serverTimestamp() });
  });
  return { revision: revision + 1, agenda, configured: true,
    dispatch_connected: false, external_sync_connected: false };
});
