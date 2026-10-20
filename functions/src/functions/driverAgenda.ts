import { readSchedulingPolicy, reservationStillActive, overlap } from '../lib/driverScheduling';
import { onCall } from 'firebase-functions/v2/https';
import { admin, db } from '../lib/admin';
import { requireAnyRole, requireSignedIn } from '../lib/auth';
import { failedPrecondition, invalidArgument, permissionDenied } from '../lib/errors';
import { intervalIsAvailable, normalizeDriverAgenda } from '../lib/driverAgenda';
import { PlatformRoles } from '../lib/types';

export const getDriverAgenda = onCall(async request => {
  const ctx = requireSignedIn(request);
  requireAnyRole(ctx, [PlatformRoles.DRIVER]);
  const profile = await db.doc('driver_profiles/' + ctx.uid).get();
  if (!profile.exists) throw permissionDenied('Profil chauffeur requis.');
  const doc = await db.doc('driver_agendas/' + ctx.uid).get();
  const data = doc.data();
  return { revision: data?.revision ?? 0, agenda: data ? normalizeDriverAgenda(data) : { windows: [], blocked: [] },
    configured: doc.exists, dispatch_connected: (await readSchedulingPolicy()) !== null, external_sync_connected: await externalReady(ctx.uid) };
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
    const reservations = await tx.get(ref.collection('reservations').where('active','==',true));
    const occupied:{ref:FirebaseFirestore.DocumentReference;start:string;end:string}[]=[];
    const before=agenda.recurrence?.pause_before_minutes??0,after=agenda.recurrence?.pause_after_minutes??0;
    const old=current.data()?.recurrence;
    const pausesChanged=before!==(old?.pause_before_minutes??0)||after!==(old?.pause_after_minutes??0);
    for(const doc of reservations.docs){
      const reservation=doc.data();
      if(Date.parse(reservation.end)<=Date.now())continue;
      const mission=await tx.get(db.doc('delivery_requests/'+doc.id)),m=mission.data();
      if(!reservationStillActive(m,ctx.uid))continue;
      const start=new Date(Date.parse(m!.scheduling?.start??reservation.mission_start??reservation.start)-before*60000).toISOString();
      const end=new Date(Date.parse(m!.scheduling?.end??reservation.mission_end??reservation.end)+after*60000).toISOString();
      const slot={ref:doc.ref,start,end};
      if(!intervalIsAvailable(agenda,slot)||occupied.some(other=>overlap(other,slot)))throw failedPrecondition('Cette modification créerait un conflit avec une mission déjà réservée.');
      occupied.push(slot);
    }
    if(pausesChanged&&occupied.length){
      const external=(await tx.get(db.doc('driver_calendar_busy/'+ctx.uid))).data();
      if(external?.required===true){
        const checked=external.checked_at?.toMillis?.(),now=Date.now();
        if(external.status!=='ready'||typeof checked!=='number'||checked>now||now-checked>60000||!Array.isArray(external.busy)||
          occupied.some(slot=>!Number.isFinite(Date.parse(external.from))||!Number.isFinite(Date.parse(external.to))||Date.parse(external.from)>Date.parse(slot.start)||Date.parse(external.to)<Date.parse(slot.end)||external.busy.some((busy:any)=>overlap(slot,busy))))
          throw failedPrecondition('Actualisez vos calendriers et vérifiez les pauses autour des missions réservées.');
      }
    }
    for(const slot of occupied)tx.update(slot.ref,{start:slot.start,end:slot.end,updated_at:admin.firestore.FieldValue.serverTimestamp()});
    tx.set(ref, { ...agenda, recurrence:agenda.recurrence??admin.firestore.FieldValue.delete(), revision: revision + 1, driver_id: ctx.uid,
      updated_at: admin.firestore.FieldValue.serverTimestamp() }, {merge:true});
  });
  return { revision: revision + 1, agenda, configured: true,
    dispatch_connected: (await readSchedulingPolicy()) !== null, external_sync_connected: await externalReady(ctx.uid) };
});

async function externalReady(uid:string):Promise<boolean>{const d=(await db.doc('driver_calendar_busy/'+uid).get()).data();const checked=d?.checked_at?.toMillis?.();return d?.required===true&&d.status==='ready'&&typeof checked==='number'&&checked<=Date.now()&&Date.now()-checked<=60000;}
