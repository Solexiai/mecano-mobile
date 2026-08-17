// -----------------------------------------------------------------------------
// addDriverInternalNote — Cloud Function callable (analyst/admin/super_admin).
//
// Ajoute une note interne sur un dossier chauffeur (`driver_internal_notes`).
// Ces notes ne sont JAMAIS visibles au chauffeur (firestore.rules: lecture
// analyst/admin/super_admin uniquement) et sont immuables une fois créées
// (pas de update/delete exposé — même pattern que `audit_logs`) : impossible
// de les supprimer silencieusement.
//
// 🔒 Écrite exclusivement via Cloud Function (jamais un create Firestore
// direct) pour garantir que `author_user_id`/`author_role` ne peuvent pas
// être falsifiés par le client.
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { writeAuditLog } from "../lib/audit";
import { invalidArgument, notFound } from "../lib/errors";

export interface AddDriverInternalNoteRequest {
  driverId: string;
  text: string;
}

export const addDriverInternalNote = onCall<AddDriverInternalNoteRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const { driverId, text } = request.data;
  if (!driverId || typeof driverId !== "string") {
    throw invalidArgument("driverId est requis.");
  }
  if (!text || typeof text !== "string" || text.trim().length < 1) {
    throw invalidArgument("text est requis (note vide non autorisée).");
  }
  if (text.length > 2000) {
    throw invalidArgument("text ne doit pas dépasser 2000 caractères.");
  }

  const driverSnap = await db.collection("driver_profiles").doc(driverId).get();
  if (!driverSnap.exists) {
    throw notFound(`driver_profiles/${driverId} introuvable.`);
  }

  const ref = db.collection("driver_internal_notes").doc();
  await ref.set({
    id: ref.id,
    driver_id: driverId,
    author_user_id: ctx.uid,
    author_role: ctx.role ?? "unknown",
    text: text.trim(),
    created_at: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Traçabilité : une note interne influence potentiellement une décision
  // (approve/reject/documents_required) — on la journalise comme les autres
  // actions analyste, sans dupliquer le texte complet (déjà stocké de façon
  // immuable dans driver_internal_notes) pour éviter la redondance.
  await writeAuditLog({
    actorUserId: ctx.uid,
    actorRole: ctx.role ?? "unknown",
    action: "driver_internal_note_added",
    sourceFunction: "addDriverInternalNote",
    targetId: driverId,
    metadata: { noteId: ref.id },
  });

  return { success: true, noteId: ref.id };
});
