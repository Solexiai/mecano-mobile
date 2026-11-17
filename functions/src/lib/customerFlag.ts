// -----------------------------------------------------------------------------
// customerFlag.ts — qui est un CLIENT ? (Daniel, 2026-11-17)
//
// Tout compte naît avec le rôle « customer », et un chauffeur le garde. Pour
// l'admin, ça mélangeait clients et chauffeurs. Règle choisie :
//   - Chauffeur = a un dossier chauffeur (rôle « driver »), quel que soit
//     son statut.
//   - Client = a demandé au moins un prix ou fait une réservation
//     (`users/{uid}.is_customer = true`, posé ici), ou n'est pas chauffeur.
//   - Un chauffeur qui demande un prix devient AUSSI client : il apparaît
//     dans les deux listes, avec la mention « Aussi chauffeur » / « Aussi
//     client ».
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";

/** Marque le compte comme client (première fois datée, les suivantes sans effet). */
export async function markAsCustomer(uid: string, at: FirebaseFirestore.Timestamp): Promise<void> {
  const ref = db.collection("users").doc(uid);
  try {
    await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      const data = snap.data() ?? {};
      if (data.is_customer === true) return;
      tx.set(
        ref,
        { is_customer: true, customer_since: data.customer_since ?? at },
        { merge: true }
      );
    });
  } catch (error) {
    // Jamais bloquant : un prix ou une réservation ne doit pas échouer pour
    // un drapeau d'affichage admin.
    console.warn("mark_as_customer_failed", { uid, error: String(error) });
  }
}

/**
 * Rattrapage des comptes existants : pose `is_customer` à vrai ou faux sur
 * chaque compte d'après ses prix demandés et ses réservations. Renvoie les
 * nombres pour l'écran admin.
 */
export async function backfillCustomerFlags(): Promise<{ customers: number; driversOnly: number; total: number }> {
  const [users, quotes, missions] = await Promise.all([
    db.collection("users").select("roles", "is_customer", "customer_since", "deleted").get(),
    db.collection("delivery_quotes").select("customer_id", "created_at").get(),
    db.collection("delivery_requests").select("customer_id", "created_at").get(),
  ]);
  const since = new Map<string, FirebaseFirestore.Timestamp>();
  const note = (uid: unknown, at: unknown) => {
    if (typeof uid !== "string" || !uid) return;
    const ts = at instanceof admin.firestore.Timestamp ? at : admin.firestore.Timestamp.now();
    const current = since.get(uid);
    if (!current || ts.toMillis() < current.toMillis()) since.set(uid, ts);
  };
  quotes.docs.forEach((d) => note(d.data().customer_id, d.data().created_at));
  missions.docs.forEach((d) => note(d.data().customer_id, d.data().created_at));

  let customers = 0;
  let driversOnly = 0;
  let batch = db.batch();
  let pending = 0;
  for (const doc of users.docs) {
    const data = doc.data();
    if (data.deleted === true) continue;
    const roles: string[] = Array.isArray(data.roles) ? data.roles : [];
    const isDriver = roles.includes("driver");
    const first = since.get(doc.id);
    // Un compte qui n'est pas chauffeur est un client par défaut (il s'est
    // inscrit par le chemin client), même sans prix demandé.
    const isCustomer = first !== undefined || !isDriver;
    if (isCustomer) customers += 1;
    else driversOnly += 1;
    const update: Record<string, unknown> = { is_customer: isCustomer };
    if (first && !data.customer_since) update.customer_since = first;
    if (data.is_customer === isCustomer && (!first || data.customer_since)) continue;
    batch.set(doc.ref, update, { merge: true });
    pending += 1;
    if (pending === 400) {
      await batch.commit();
      batch = db.batch();
      pending = 0;
    }
  }
  if (pending > 0) await batch.commit();
  return { customers, driversOnly, total: users.size };
}
