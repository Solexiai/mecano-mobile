// -----------------------------------------------------------------------------
// validateDriverDocument — Cloud Function callable (analyst/admin/super_admin).
//
// 🔒 Seul point d'entrée pour changer `driver_documents/{id}.status` vers
// `approved`/`rejected`/`replacement_required` (firestore.rules interdit tout
// `update` direct, voir match /driver_documents/{documentId}). Recalcule
// aussi `driver_profiles.documents_all_valid` (champ dénormalisé utilisé par
// le dispatch pour éviter de lire driver_documents à chaque recherche).
// -----------------------------------------------------------------------------

import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { invalidArgument, notFound } from "../lib/errors";
import { writeAuditLogInTransaction } from "../lib/audit";
import { DriverDocumentStatus, DriverDocumentStatuses } from "../lib/types";

// Liste des types de documents obligatoires — utilisée pour recalculer
// documents_all_valid. Doit rester synchronisée avec DriverDocumentType côté
// Dart (lib/models/enums.dart).
const REQUIRED_DOCUMENT_TYPES = ["drivers_licence", "vehicle_registration", "insurance", "identity"];

export interface ValidateDriverDocumentRequest {
  documentId: string;
  newStatus: DriverDocumentStatus;
  rejectionReason?: string;
}

export const validateDriverDocument = onCall<ValidateDriverDocumentRequest>(async (request) => {
  const ctx = requireSignedIn(request);
  requireAnalystOrAbove(ctx);

  const { documentId, newStatus, rejectionReason } = request.data;
  if (!documentId) throw invalidArgument("documentId est requis.");
  const allowedTargets: DriverDocumentStatus[] = [
    DriverDocumentStatuses.APPROVED,
    DriverDocumentStatuses.REJECTED,
    DriverDocumentStatuses.REPLACEMENT_REQUIRED,
    DriverDocumentStatuses.EXPIRED,
  ];
  if (!allowedTargets.includes(newStatus)) {
    throw invalidArgument(`newStatus invalide. Autorisé: ${allowedTargets.join(", ")}.`);
  }
  if (newStatus === DriverDocumentStatuses.REJECTED && !rejectionReason) {
    throw invalidArgument("rejectionReason est requis pour un rejet.");
  }

  const docRef = db.collection("driver_documents").doc(documentId);

  await db.runTransaction(async (tx) => {
    // ---- Tous les reads d'abord (contrainte des transactions Firestore) ----
    const docSnap = await tx.get(docRef);
    if (!docSnap.exists) throw notFound(`driver_documents/${documentId} introuvable.`);
    const doc = docSnap.data()!;

    // Recalcule documents_all_valid pour ce chauffeur : tous les types
    // requis doivent avoir AU MOINS un document `approved` et non expiré.
    // `tx.get()` accepte directement une Query (SDK Admin >= 9).
    const allDocsQuery = db.collection("driver_documents").where("driver_id", "==", doc.driver_id);
    const allDocsSnap = await tx.get(allDocsQuery);

    // ---- Puis tous les writes ----
    const now = admin.firestore.Timestamp.now();
    tx.update(docRef, {
      status: newStatus,
      reviewed_at: now,
      reviewed_by_user_id: ctx.uid,
      rejection_reason: newStatus === DriverDocumentStatuses.REJECTED ? rejectionReason : null,
    });

    const docs = allDocsSnap.docs.map((d) =>
      d.id === documentId ? { ...d.data(), status: newStatus } : d.data()
    );

    const approvedTypes = new Set(
      docs
        .filter((d) => d.status === DriverDocumentStatuses.APPROVED)
        .map((d) => d.type as string)
    );
    const allValid = REQUIRED_DOCUMENT_TYPES.every((t) => approvedTypes.has(t));

    tx.update(db.collection("driver_profiles").doc(doc.driver_id), {
      documents_all_valid: allValid,
    });

    writeAuditLogInTransaction(tx, {
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? "unknown",
      action: "validateDriverDocument",
      sourceFunction: "validateDriverDocument",
      targetId: documentId,
      metadata: { newStatus, driverId: doc.driver_id, documentsAllValid: allValid },
    });
  });

  return { success: true, documentId, newStatus };
});
