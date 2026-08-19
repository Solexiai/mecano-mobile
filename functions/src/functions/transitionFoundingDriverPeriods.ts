// -----------------------------------------------------------------------------
// transitionFoundingDriverPeriods — Cloud Function PLANIFIÉE (cron quotidien).
//
// Rôle : détecter les qualifications Founding Driver (`status == 'qualified'`)
// dont `promotional_period_ends_at` est dépassé — c.-à-d. le chauffeur passe
// du taux PROMOTIONNEL au taux PRÉFÉRENTIEL. Le `status` métier reste
// `qualified` (aucune valeur d'enum séparée pour "en période préférentielle"
// — voir FoundingDriverStatuses dans lib/types.ts) : c'est `resolveCommission()`
// qui recalcule dynamiquement le bon taux à chaque appel en comparant
// `nowMillis` à `promotionalPeriodEndsAtMillis`. Ce job ne fait donc PAS un
// calcul financier — il se contente de :
//   1. rafraîchir le cache d'affichage `driver_pricing_profiles` (taux
//      préférentiel affiché à l'écran chauffeur) ;
//   2. créer une notification d'information pour le chauffeur (chemin
//      canonique `users/{uid}/notifications/{id}` — voir la note détaillée
//      dans detectExpiringDocuments.ts sur les 2 bugs de chemin corrigés en
//      Phase 5, partie 3) ;
//   3. marquer la qualification `preferred_rate_notified = true` pour ne
//      traiter chaque transition qu'une seule fois (idempotence du cron).
//
// Requête utilisée (index #11 de firestore.indexes.json — collection group
// `qualifications`, scope COLLECTION_GROUP) :
//   where status == 'qualified'
//   where promotional_period_ends_at <= now
// -----------------------------------------------------------------------------

import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { FoundingDriverStatuses } from "../lib/types";

const BATCH_LIMIT = 300;

export const transitionFoundingDriverPeriods = onSchedule(
  { schedule: "every day 04:00", timeZone: "America/Toronto" },
  async () => {
    const now = admin.firestore.Timestamp.now();

    // Requête collection-group : toutes les sous-collections
    // `founding_driver_programs/*/qualifications` en une seule requête.
    const snap = await db
      .collectionGroup("qualifications")
      .where("status", "==", FoundingDriverStatuses.QUALIFIED)
      .where("promotional_period_ends_at", "<=", now)
      .limit(BATCH_LIMIT)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const transitioned: string[] = [];

    for (const qualSnap of snap.docs) {
      const qual = qualSnap.data();
      if (qual.preferred_rate_notified) continue; // déjà traité un jour précédent

      const driverId = qual.driver_id as string;
      const programRef = qualSnap.ref.parent.parent; // founding_driver_programs/{programId}
      const programId = programRef?.id ?? "unknown";

      batch.update(qualSnap.ref, { preferred_rate_notified: true });

      // Récupère le taux préférentiel du programme pour rafraîchir le cache
      // d'affichage (lecture hors batch — acceptable ici, pas de contrainte
      // d'atomicité transactionnelle requise pour un simple cache d'UI).
      if (programRef) {
        const programDoc = await programRef.get();
        const preferredRate = programDoc.data()?.preferred_commission_rate;
        if (typeof preferredRate === "number") {
          batch.set(
            db.collection("driver_pricing_profiles").doc(driverId),
            {
              driver_id: driverId,
              resolved_commission_rate: preferredRate,
              resolved_program: "founding_preferred",
              resolved_reason: "founding_driver_preferred_rate",
              last_resolved_at: admin.firestore.FieldValue.serverTimestamp(),
            },
            { merge: true }
          );
        }
      }

      const notifRef = db.collection("users").doc(driverId).collection("notifications").doc();
      batch.set(notifRef, {
        id: notifRef.id,
        type: "founding_driver_preferred_rate_active",
        title_key: "notif_founding_preferred_rate_title",
        body_key: "notif_founding_preferred_rate_body",
        is_read: false,
        created_at: now,
        related_mission_id: null,
        metadata: { programId },
      });

      transitioned.push(driverId);
    }

    await batch.commit();

    await writeAuditLog({
      actorUserId: "system",
      actorRole: "system",
      action: "transitionFoundingDriverPeriods",
      sourceFunction: "transitionFoundingDriverPeriods",
      metadata: { transitionedDriverIds: transitioned },
    });
  }
);
