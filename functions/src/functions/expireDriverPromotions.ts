// -----------------------------------------------------------------------------
// expireDriverPromotions — Cloud Function PLANIFIÉE (cron horaire).
//
// Rôle : faire passer automatiquement `is_active` à `false` pour toute
// `driver_promotions/{id}` dont `ends_at` est dépassé — pour que
// `CommissionResolver` (côté serveur, `resolveCommission()`) ne trouve plus
// cette promotion comme "active" même si un appel de secours oubliait de
// vérifier `endsAtMillis` (défense en profondeur ; `resolveCommission()`
// vérifie déjà les dates, ce job maintient aussi `is_active` cohérent pour
// les lectures d'affichage type `driver_pricing_profiles`).
//
// Requête utilisée (index #10 de firestore.indexes.json :
// driver_promotions(is_active, ends_at)) :
//   where is_active == true
//   where ends_at <= now
// -----------------------------------------------------------------------------

import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";

const BATCH_LIMIT = 300;

export const expireDriverPromotions = onSchedule(
  { schedule: "every 60 minutes" },
  async () => {
    const now = admin.firestore.Timestamp.now();

    const snap = await db
      .collection("driver_promotions")
      .where("is_active", "==", true)
      .where("ends_at", "<=", now)
      .limit(BATCH_LIMIT)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const affectedDriverIds: string[] = [];

    for (const docSnap of snap.docs) {
      batch.update(docSnap.ref, { is_active: false });
      affectedDriverIds.push(docSnap.data().driver_id as string);
    }

    await batch.commit();

    // Rafraîchit le cache d'affichage driver_pricing_profiles pour chaque
    // chauffeur concerné, en retombant sur le taux standard (le calcul réel
    // sera de toute façon rejoué par resolveCommission() à la prochaine
    // mission — ceci n'est qu'un affichage).
    await Promise.all(
      affectedDriverIds.map((driverId) =>
        db.collection("driver_pricing_profiles").doc(driverId).set(
          {
            driver_id: driverId,
            resolved_program: "standard",
            resolved_reason: "promotion_expired",
            last_resolved_at: admin.firestore.FieldValue.serverTimestamp(),
          },
          { merge: true }
        )
      )
    );

    await writeAuditLog({
      actorUserId: "system",
      actorRole: "system",
      action: "expireDriverPromotions",
      sourceFunction: "expireDriverPromotions",
      metadata: { expiredCount: snap.size, driverIds: affectedDriverIds },
    });
  }
);
