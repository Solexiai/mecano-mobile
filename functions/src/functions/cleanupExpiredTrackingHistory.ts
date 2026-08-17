// -----------------------------------------------------------------------------
// cleanupExpiredTrackingHistory — Cloud Function PLANIFIÉE (cron quotidien).
//
// Rôle : purge automatique des points GPS historiques
// (`driver_locations/{driverId}/history/{eventId}`) dont `recorded_at` est
// antérieur à RETENTION_DAYS jours — voir docs/FIRESTORE_ARCHITECTURE.md
// section 5bis : « Rétention configurable, valeur par défaut = 30 jours ».
//
// Requête utilisée — collection group sur `history` (nécessite l'index
// dédié `history(recorded_at)` en scope COLLECTION_GROUP, voir
// firestore.indexes.json et docs/FIRESTORE_INDEXES.md, index ajouté à
// l'étape 11 car requis par CE job précisément) :
//   where recorded_at < now - RETENTION_DAYS
//
// ⚠️ Si un litige nécessite de conserver un historique au-delà de la
// rétention, un export archivé (Cloud Storage/BigQuery) doit être effectué
// AVANT l'exécution de ce job — hors scope de ce squelette (mentionné
// comme TODO explicite pour une passe future d'archivage).
// -----------------------------------------------------------------------------

import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";

const RETENTION_DAYS = 30;
const BATCH_LIMIT = 400; // limite Firestore batch = 500 writes, garde une marge

export const cleanupExpiredTrackingHistory = onSchedule(
  { schedule: "every day 02:00", timeZone: "America/Toronto" },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - RETENTION_DAYS * 24 * 60 * 60 * 1000
    );

    let totalDeleted = 0;
    // Boucle par lots jusqu'à épuisement (une exécution peut avoir plus de
    // BATCH_LIMIT documents à purger si le cron a été interrompu longtemps).
    for (let i = 0; i < 20; i++) {
      const snap = await db
        .collectionGroup("history")
        .where("recorded_at", "<", cutoff)
        .limit(BATCH_LIMIT)
        .get();

      if (snap.empty) break;

      const batch = db.batch();
      for (const docSnap of snap.docs) {
        batch.delete(docSnap.ref);
      }
      await batch.commit();
      totalDeleted += snap.size;

      if (snap.size < BATCH_LIMIT) break; // dernier lot
    }

    if (totalDeleted > 0) {
      await writeAuditLog({
        actorUserId: "system",
        actorRole: "system",
        action: "cleanupExpiredTrackingHistory",
        sourceFunction: "cleanupExpiredTrackingHistory",
        metadata: { totalDeleted, retentionDays: RETENTION_DAYS },
      });
    }
  }
);
