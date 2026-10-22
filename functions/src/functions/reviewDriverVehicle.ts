import { randomUUID } from 'crypto';
import { onCall } from 'firebase-functions/v2/https';
import { admin, db } from '../lib/admin';
import { requireAnalystOrAbove, requireSignedIn } from '../lib/auth';
import { Capacity, validCapacity } from '../lib/booking';
import { failedPrecondition, invalidArgument, notFound } from '../lib/errors';
import { normalizeVehicleCategory } from '../lib/vehicleCategory';

const CATEGORIES = ['pickup_truck', 'cargo_van', 'cube_truck'];
const DIMENSIONS = ['length_cm', 'width_cm', 'height_cm', 'opening_width_cm', 'opening_height_cm', 'payload_kg'] as const;
export interface ReviewDriverVehicleRequest {
  driverId: string;
  vehicleId: string;
  action: 'approve' | 'revoke';
  capacity?: Record<string, unknown>;
  validUntil?: string;
  verificationNote: string;
  expectedIdentity: Record<string, unknown>;
}
export function vehicleIdentity(v: FirebaseFirestore.DocumentData): Record<string, unknown> {
  return Object.fromEntries(['driver_id','category','make_model','year','plate','max_payload_kg'].map(k => [k,v[k] ?? null]));
}
function capacityInput(raw: unknown, category: string, version: string): Capacity {
  if (!raw || typeof raw !== 'object' || Array.isArray(raw)) throw invalidArgument('Capacités vérifiées requises.');
  const v = raw as Record<string, unknown>;
  const list = (key: string, allowed: string[]) => {
    const a = v[key];
    if (!Array.isArray(a) || a.some(x => typeof x !== 'string' || !allowed.includes(x))) throw invalidArgument('Services ou équipements invalides.');
    return [...new Set(a)] as string[];
  };
  for (const k of DIMENSIONS) if (typeof v[k] !== 'number' || !Number.isFinite(v[k]) || Number(v[k]) <= 0) throw invalidArgument('Chaque capacité doit être un nombre positif vérifié.');
  const capacity: Capacity = {
    category, rank: CATEGORIES.indexOf(category), version, verified: true,
    length_cm: v.length_cm as number, width_cm: v.width_cm as number, height_cm: v.height_cm as number,
    opening_width_cm: v.opening_width_cm as number, opening_height_cm: v.opening_height_cm as number,
    payload_kg: v.payload_kg as number, handlers: v.handlers as number,
    equipment: list('equipment',['dolly','straps','liftgate']),
    services: list('services',['handling','stairs']),
  };
  if (!validCapacity(capacity) || ![1,2].includes(capacity.handlers) ||
      capacity.opening_width_cm > capacity.width_cm || capacity.opening_height_cm > capacity.height_cm) {
    throw invalidArgument('Capacités incohérentes : vérifiez les dimensions, les ouvertures et les aides.');
  }
  return capacity;
}

/** Explicit administrative measurement review; never derives capacity from a photo,
 * a generic category, or a driver's self-declared payload. No financial writes. */
export const reviewDriverVehicle = onCall<ReviewDriverVehicleRequest>(async request => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);
  const input = request.data;
  if (!input || ![input.driverId,input.vehicleId].every(x => typeof x === 'string' && /^[^/]{1,128}$/.test(x)) ||
      !['approve','revoke'].includes(input.action) || typeof input.verificationNote !== 'string' ||
      !input.verificationNote.trim() || input.verificationNote.length > 1200 ||
      !input.expectedIdentity || typeof input.expectedIdentity !== 'object') throw invalidArgument('Dossier, décision et justification requis.');
  if (ctx.uid === input.driverId && !ctx.roles.includes('super_admin')) throw failedPrecondition('Vous ne pouvez pas vérifier votre propre véhicule.');
  const vref=db.doc('driver_vehicles/'+input.vehicleId), pref=db.doc('driver_profiles/'+input.driverId);
  const auditRef=db.collection('audit_logs').doc(),version=randomUUID();
  const expiry=input.action==='approve' ? Date.parse(input.validUntil ?? '') : null;
  if(input.action==='approve' && (!Number.isFinite(expiry) || expiry!<=Date.now())) throw invalidArgument('Date de validité future requise.');
  await db.runTransaction(async tx => {
    const [vehicle,profile]=await Promise.all([tx.get(vref),tx.get(pref)]);
    if(!vehicle.exists || !profile.exists) throw notFound('Dossier ou véhicule introuvable.');
    const v=vehicle.data()!,p=profile.data()!;
    if(v.driver_id!==input.driverId) throw failedPrecondition('Ce véhicule appartient à un autre dossier.');
    const identity=vehicleIdentity(v);
    if(Object.keys(identity).some(k=>identity[k] !== (input.expectedIdentity[k] ?? null))) throw failedPrecondition('Le véhicule a changé. Rechargez son dossier avant de valider.');
    let patch: Record<string, unknown>;
    if(input.action==='approve'){
      if(p.status!=='approved' || p.documents_all_valid!==true) throw failedPrecondition('Approuvez les documents du chauffeur avant de vérifier son véhicule.');
      const category=normalizeVehicleCategory(v.category);
      if(!CATEGORIES.includes(category)) throw failedPrecondition('Le pilote accepte un pick-up, un fourgon cargo ou un camion cube.');
      const documents=await tx.get(db.collection('driver_documents').where('driver_id','==',input.driverId));
      for(const type of ['drivers_licence','vehicle_registration','insurance','identity']){
        const valid=documents.docs.some(d=>{
          const data=d.data(),end=data.expires_at;
          return data.type===type && data.status==='approved' &&
            (end==null || (typeof end.toMillis==='function' && end.toMillis()>=expiry!));
        });
        if(!valid)throw failedPrecondition('La validité du véhicule ne peut dépasser celle des documents approuvés.');
      }
      const capacity=capacityInput(input.capacity,category,version);
      patch={is_verified:true,verified_capacity:capacity,capacity_valid_until:admin.firestore.Timestamp.fromMillis(expiry!),verified_identity:identity};
    }else{
      patch={is_verified:false,verified_capacity:admin.firestore.FieldValue.delete(),capacity_valid_until:admin.firestore.FieldValue.delete(),verified_identity:admin.firestore.FieldValue.delete()};
    }
    const now=admin.firestore.Timestamp.now();
    tx.update(vref,{...patch,capacity_reviewed_at:now,capacity_reviewed_by:ctx.uid,capacity_review_note:input.verificationNote.trim()});
    tx.create(auditRef,{actor_user_id:ctx.uid,actor_role:ctx.role??ctx.roles[0],action:input.action==='approve'?'driver_vehicle_verified':'driver_vehicle_verification_revoked',
      source_function:'reviewDriverVehicle',target_id:input.vehicleId,created_at:now,
      metadata:{driver_id:input.driverId,capacity_version:input.action==='approve'?version:null,note:input.verificationNote.trim()}});
  });
  return {success:true,vehicleId:input.vehicleId,verified:input.action==='approve'};
});
