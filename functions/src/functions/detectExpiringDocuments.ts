// -----------------------------------------------------------------------------
// detectExpiringDocuments — Cloud Function PLANIFIÉE (cron quotidien).
//
// Rôle : détecter les `driver_documents` `approved` dont `expires_at` arrive
// à échéance dans les WARNING_WINDOW_DAYS prochains jours (ex: permis de
// conduire, assurance) et :
//   1. créer une `users/{uid}/notifications/{id}` pour le chauffeur concerné
//      (rappel de renouvellement) — idempotent via un flag
//      `expiry_warning_sent` sur le document, pour ne pas notifier chaque jour.
//
// 🔒 CHEMIN CANONIQUE DES NOTIFICATIONS (Phase 5, partie 3) :
// `users/{uid}/notifications/{notificationId}` est la SEULE collection de
// notifications de l'app — sous-collection de `users`, conformément à
// `docs/FIRESTORE_ARCHITECTURE.md` #19.
//
// 🐛 DEUX BUGS PRÉ-EXISTANTS CORRIGÉS ICI :
//  1. Cette fonction écrivait auparavant dans une collection RACINE
//     `notifications/{uid}/items`, complètement différente du chemin déclaré
//     dans firestore.rules — donc les notifications créées n'avaient AUCUNE
//     règle de sécurité correspondante et étaient illisibles par quiconque
//     (deny-by-default).
//  2. La règle `firestore.rules` elle-même était mal formée :
//     `users/{userId}/notifications/items/{notificationId}` contient 5
//     segments de chemin (users, {userId}, notifications, items,
//     {notificationId}) — un nombre IMPAIR, qui ne peut jamais correspondre
//     à un document Firestore réel (l'alternance collection/document exige
//     un nombre PAIR de segments). Cette règle n'a donc jamais pu matcher un
//     quelconque document. Corrigé en supprimant le segment `items` en trop :
//     chemin final = `users/{uid}/notifications/{notificationId}` (4
//     segments, valide).
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
          .collection("users")
          .doc(doc.driver_id as string)
          .collection("notifications")
          .doc();
        batch.set(notifRef, {
          id: notifRef.id,
          type: "document_expiring_soon",
          title_key: "notif_document_expiring_soon_title",
          body_key: "notif_document_expiring_soon_body",
          is_read: false,
          created_at: now,
          related_mission_id: null,
          metadata: { documentType: doc.type, documentId: docSnap.id, expiresAtMillis },
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
