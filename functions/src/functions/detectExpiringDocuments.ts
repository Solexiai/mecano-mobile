// -----------------------------------------------------------------------------
// detectExpiringDocuments — Cloud Function PLANIFIÉE (cron quotidien).
//
// Rôle : détecter les `driver_documents` `approved` dont `expires_at` arrive
// à échéance dans les WARNING_WINDOW_DAYS prochains jours (ex: permis de
// conduire, assurance) et :
//   1. créer une `notifications/{uid}/items/{id}` pour le chauffeur concerné
//      (rappel de renouvellement) — idempotent via un flag
//      `expiry_warning_sent` sur le document, pour ne pas notifier chaque jour.
//   2. faire passer directement à `expired` (+ recalcul de
//      `driver_profiles.documents_all_valid`) tout document dont `expires_at`
//      est déjà DÉPASSÉ.
//
// Requête utilisée (index #3 de firestore.indexes.json :
// driver_documents(status, expires_at)) :
//   where status == 'approved'
//   where expires_at <= now + WARNING_WINDOW_DAYS   (couvre aussi le passé)
// -----------------------------------------------------------------------------

import { onSchedule } from "firebase-functions/v2/scheduler";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { DriverDocumentStatuses } from "../lib/types";

const WARNING_WINDOW_DAYS = 30;
const BATCH_LIMIT = 300; // garde-fou par exécution — le job repasse chaque jour

export const detectExpiringDocuments = onSchedule(
  { schedule: "every day 03:00", timeZone: "America/Toronto" },
  async () => {
    const now = admin.firestore.Timestamp.now();
    const warningThreshold = admin.firestore.Timestamp.fromMillis(
      now.toMillis() + WARNING_WINDOW_DAYS * 24 * 60 * 60 * 1000
    );

    const snap = await db
      .collection("driver_documents")
      .where("status", "==", DriverDocumentStatuses.APPROVED)
      .where("expires_at", "<=", warningThreshold)
      .limit(BATCH_LIMIT)
      .get();

    if (snap.empty) return;

    const batch = db.batch();
    const affectedDriverIds = new Set<string>();
    let expiredCount = 0;
    let warnedCount = 0;

    for (const docSnap of snap.docs) {
      const doc = docSnap.data();
      const expiresAtMillis = (doc.expires_at as FirebaseFirestore.Timestamp).toMillis();
      const alreadyExpired = expiresAtMillis <= now.toMillis();

      if (alreadyExpired) {
        batch.update(docSnap.ref, {
          status: DriverDocumentStatuses.EXPIRED,
          reviewed_at: now,
          rejection_reason: "Document expiré (détecté automatiquement).",
        });
        affectedDriverIds.add(doc.driver_id as string);
        expiredCount++;
      } else if (!doc.expiry_warning_sent) {
        // Notification de rappel — pas encore expiré, juste un avertissement.
        const notifRef = db
          .collection("notifications")
          .doc(doc.driver_id as string)
          .collection("items")
          .doc();
        batch.set(notifRef, {
          id: notifRef.id,
          type: "document_expiring_soon",
          title: "Document à renouveler",
          body: `Votre document (${doc.type}) expire bientôt. Veuillez le renouveler.`,
          created_at: now,
          read: false,
          metadata: { documentId: docSnap.id, expiresAtMillis },
        });
        batch.update(docSnap.ref, { expiry_warning_sent: true });
        warnedCount++;
      }
    }

    // Recalcule documents_all_valid pour chaque chauffeur ayant un document
    // passé à `expired` dans ce batch (un document expiré invalide le statut).
    for (const driverId of affectedDriverIds) {
      batch.update(db.collection("driver_profiles").doc(driverId), {
        documents_all_valid: false,
      });
    }

    await batch.commit();

    await writeAuditLog({
      actorUserId: "system",
      actorRole: "system",
      action: "detectExpiringDocuments",
      sourceFunction: "detectExpiringDocuments",
      metadata: { expiredCount, warnedCount, scannedCount: snap.size },
    });
  }
);
