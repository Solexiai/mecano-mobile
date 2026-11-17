// -----------------------------------------------------------------------------
// acquisitionSources.ts — d'où vient chaque prospect (décision Daniel,
// 2026-11-17).
//
//   - recordAcquisitionSource (compte connecté) : range la PREMIÈRE visite de
//     la personne (publicité, recherche, direct…) dans
//     `user_acquisition/{uid}`. Écrit une seule fois : la première source
//     gagne. Collection fermée aux clients (refus par défaut des règles).
//   - getAcquisitionReport (analyste et plus) : tableau source → comptes →
//     prix demandés → réservations → chauffeurs, sur 7 à 90 jours.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { AcquisitionSource, buildAcquisitionReport, classifyAcquisition } from "../lib/acquisition";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";

const DAY_MS = 24 * 60 * 60 * 1000;

export const recordAcquisitionSource = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  const source = classifyAcquisition(request.data);
  const ref = db.collection("user_acquisition").doc(ctx.uid);
  const recorded = await db.runTransaction(async (tx) => {
    if ((await tx.get(ref)).exists) return false;
    tx.set(ref, { user_id: ctx.uid, ...source, recorded_at: admin.firestore.Timestamp.now() });
    return true;
  });
  return { recorded };
});

/** Source notée pour ce compte (fiche client), ou null. */
export async function acquisitionOf(uid: string): Promise<AcquisitionSource | null> {
  const data = (await db.collection("user_acquisition").doc(uid).get()).data();
  return data ? (data as AcquisitionSource) : null;
}

function customerIds(docs: FirebaseFirestore.QueryDocumentSnapshot[]): string[] {
  return docs.map((d) => d.data().customer_id).filter((id): id is string => typeof id === "string" && id.length > 0);
}

export const getAcquisitionReport = onCall(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);
  const asked = Number(request.data?.days);
  const days = Number.isFinite(asked) ? Math.min(90, Math.max(7, Math.round(asked))) : 30;
  const since = admin.firestore.Timestamp.fromMillis(Date.now() - days * DAY_MS);

  const [recordsSnap, quotesSnap, missionsSnap] = await Promise.all([
    db.collection("user_acquisition").where("recorded_at", ">=", since).get(),
    db.collection("delivery_quotes").where("created_at", ">=", since).get(),
    db.collection("delivery_requests").where("created_at", ">=", since).get(),
  ]);
  const sources = new Map<string, AcquisitionSource>();
  for (const doc of recordsSnap.docs) sources.set(doc.id, doc.data() as AcquisitionSource);
  const newAccountIds = recordsSnap.docs.map((d) => d.id);
  const pricedCustomerIds = customerIds(quotesSnap.docs);
  const bookedCustomerIds = customerIds(missionsSnap.docs);

  // Source des clients actifs dans la période mais inscrits avant.
  const missing = [...new Set([...pricedCustomerIds, ...bookedCustomerIds])].filter((uid) => !sources.has(uid));
  for (let i = 0; i < missing.length; i += 300) {
    const refs = missing.slice(i, i + 300).map((uid) => db.collection("user_acquisition").doc(uid));
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) sources.set(snap.id, snap.data() as AcquisitionSource);
    }
  }
  // Comptes de la période qui ont commencé un dossier chauffeur.
  const driverIds: string[] = [];
  for (let i = 0; i < newAccountIds.length; i += 300) {
    const refs = newAccountIds.slice(i, i + 300).map((uid) => db.collection("driver_profiles").doc(uid));
    for (const snap of await db.getAll(...refs)) {
      if (snap.exists) driverIds.push(snap.id);
    }
  }
  return {
    days,
    generatedAt: new Date().toISOString(),
    rows: buildAcquisitionReport({ sources, newAccountIds, pricedCustomerIds, bookedCustomerIds, driverIds }),
  };
});
