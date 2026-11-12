// -----------------------------------------------------------------------------
// adminAddDriverDocument — un agent Movi-K ajoute au dossier d'un chauffeur un
// document reçu par courriel à infos@movi-k.com (Daniel, 2026-11-12).
//
// Analyste et plus. Le fichier (image ou PDF, 8 Mo max) est écrit par le
// serveur sous driver_documents/{chauffeur}/{place}_{horodatage}.{ext}, comme
// un envoi du chauffeur, puis le document est créé « uploaded » : il se
// vérifie et s'approuve ensuite comme les autres (validateDriverDocument).
// Marqué source « staff » avec l'agent, et journalisé dans audit_logs.
// Les règles Storage et Firestore ne changent pas : seul le serveur écrit ici.
// -----------------------------------------------------------------------------

import { randomUUID } from "crypto";
import { onCall } from "firebase-functions/v2/https";
import { admin, db } from "../lib/admin";
import { writeAuditLog } from "../lib/audit";
import { requireAnalystOrAbove, requireSignedIn } from "../lib/auth";
import { DRIVER_DOCUMENT_SLOTS } from "../lib/driverDocuments";
import { invalidArgument, notFound } from "../lib/errors";
import { DriverDocumentStatuses } from "../lib/types";

export const MAX_STAFF_DOCUMENT_BYTES = 8 * 1024 * 1024;

const EXTENSIONS: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
  "image/heic": "heic",
  "application/pdf": "pdf",
};

export interface AdminAddDriverDocumentRequest {
  driverId: string;
  slot: string;
  fileName?: string;
  mimeType: string;
  dataBase64: string;
}

export const adminAddDriverDocument = onCall<AdminAddDriverDocumentRequest>(
  { memory: "512MiB" },
  async (request) => {
    const ctx = requireSignedIn(request);
    requireAnalystOrAbove(ctx);
    const { driverId, slot, mimeType, dataBase64 } = request.data ?? ({} as AdminAddDriverDocumentRequest);
    if (typeof driverId !== "string" || !driverId || driverId.includes("/")) {
      throw invalidArgument("Chauffeur invalide.");
    }
    const place = typeof slot === "string" ? DRIVER_DOCUMENT_SLOTS[slot] : undefined;
    if (!place) throw invalidArgument("Type de document inconnu.");
    const extension = EXTENSIONS[mimeType];
    if (!extension) throw invalidArgument("Format accepté : photo (JPG, PNG, WEBP, HEIC) ou PDF.");
    if (typeof dataBase64 !== "string" || !dataBase64) throw invalidArgument("Fichier vide.");
    const bytes = Buffer.from(dataBase64, "base64");
    if (!bytes.length) throw invalidArgument("Fichier vide.");
    if (bytes.length > MAX_STAFF_DOCUMENT_BYTES) {
      throw invalidArgument("Fichier trop lourd : 8 Mo au maximum.");
    }
    const original = typeof request.data.fileName === "string"
      ? request.data.fileName.slice(0, 200)
      : null;

    const profile = await db.collection("driver_profiles").doc(driverId).get();
    if (!profile.exists) throw notFound("Dossier chauffeur introuvable.");

    const storedName = `${slot}_${Date.now()}.${extension}`;
    const path = `driver_documents/${driverId}/${storedName}`;
    await admin.storage().bucket().file(path).save(bytes, {
      resumable: false,
      contentType: mimeType,
      metadata: { metadata: { added_by_user_id: ctx.uid, source: "staff" } },
    });

    const id = randomUUID();
    await db.collection("driver_documents").doc(id).set({
      id,
      driver_id: driverId,
      type: place.type,
      status: DriverDocumentStatuses.UPLOADED,
      storage_bucket_path: path,
      uploaded_at: admin.firestore.Timestamp.now(),
      reviewed_at: null,
      reviewed_by_user_id: null,
      rejection_reason: null,
      expires_at: null,
      file_name: original,
      mime_type: mimeType,
      source: "staff",
      added_by_user_id: ctx.uid,
    });

    await writeAuditLog({
      actorUserId: ctx.uid,
      actorRole: ctx.role ?? ctx.roles[0] ?? "staff",
      action: "driver_document_added_by_staff",
      sourceFunction: "adminAddDriverDocument",
      targetId: id,
      metadata: { driverId, slot, mimeType, bytes: bytes.length },
    });

    return { documentId: id, storagePath: path };
  }
);
