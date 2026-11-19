// -----------------------------------------------------------------------------
// driverDocumentsHold.ts — dossier chauffeur mis en suspens pour documents
// (Daniel, 2026-11-19).
//
// « Quand je refuse un document, il me faut un courriel pour lui : le compte
// est en suspens, nous avons besoin des pièces demandées. » Avant, refuser un
// document ne changeait rien pour le chauffeur : statut inchangé, aucun
// courriel, rien dans l'app.
//
// Désormais, refuser un document (validateDriverDocument) ou demander des
// documents (requestDriverDocuments) :
//   1. met le dossier en `documents_required` avec le motif (le chauffeur
//      voit la carte « Documents à corriger » et le motif dans l'app) ;
//   2. écrit une notification dans sa cloche ;
//   3. envoie tout de suite le courriel « Votre dossier est en suspens »
//      (puis rappels J+1 et J+3 par les relances).
// -----------------------------------------------------------------------------

import { admin, db } from "./admin";
import { DriverStatuses } from "./types";

type Doc = Record<string, any>;

/** Depuis ces statuts, une demande de documents a un sens. */
export const DOCUMENTS_HOLD_ALLOWED_FROM: string[] = [
  DriverStatuses.PENDING_REVIEW,
  DriverStatuses.DOCUMENTS_REQUIRED,
  DriverStatuses.APPROVED,
];

/** Deux refus à moins d'une heure d'écart : même demande, motifs cumulés. */
const SAME_REQUEST_WINDOW_MS = 60 * 60 * 1000;

const SLOT_LABELS_FR: Record<string, string> = {
  drivers_licence_front: "Permis de conduire (recto)",
  drivers_licence_back: "Permis de conduire (verso)",
  drivers_licence: "Permis de conduire",
  vehicle_registration: "Immatriculation du véhicule",
  insurance: "Preuve d'assurance",
  vehicle_main_photo: "Photo du véhicule",
  vehicle_rear_photo: "Photo arrière du véhicule",
  vehicle_plate_photo: "Photo de la plaque",
  vehicle_photo: "Photo du véhicule",
  other: "Document",
};

/** Nom lisible d'un document, d'après sa place (nom de fichier) ou son type. */
export function driverDocumentLabel(doc: Doc): string {
  const path = typeof doc.storage_bucket_path === "string" ? doc.storage_bucket_path : "";
  const fileName = path.split("/").pop() ?? "";
  for (const slot of Object.keys(SLOT_LABELS_FR)) {
    if (fileName.startsWith(`${slot}_`) || fileName.startsWith(`${slot}.`) || fileName === slot) {
      return SLOT_LABELS_FR[slot];
    }
  }
  const type = typeof doc.type === "string" ? doc.type : "";
  return SLOT_LABELS_FR[type] ?? SLOT_LABELS_FR.other;
}

/** Motif d'un document refusé, tel qu'il sera lu par le chauffeur. */
export function rejectedDocumentReason(doc: Doc, rejectionReason: string | undefined, newStatus: string): string {
  const label = driverDocumentLabel(doc);
  const why = (rejectionReason ?? "").trim();
  if (why) return `${label} : ${why}`;
  if (newStatus === "expired") return `${label} : document expiré, à renouveler`;
  return `${label} : à remplacer`;
}

export interface DocumentsHoldOutcome {
  /** Vrai si le statut vient de passer (ou repasser) en documents_required. */
  applied: boolean;
  /** Vrai si c'est une nouvelle demande (nouveau courriel), faux si cumulée. */
  newRequest: boolean;
  reason: string;
}

/**
 * Dans une transaction : met le dossier en suspens avec le motif. Si le
 * dossier est déjà en suspens depuis moins d'une heure, le motif s'ajoute
 * au précédent (une seule demande, un seul courriel).
 */
export function holdDriverForDocumentsInTransaction(
  tx: FirebaseFirestore.Transaction,
  params: { driverRef: FirebaseFirestore.DocumentReference; profile: Doc; reason: string; actorUid: string; nowMs: number }
): DocumentsHoldOutcome {
  const { profile, reason } = params;
  if (!DOCUMENTS_HOLD_ALLOWED_FROM.includes(profile.status)) {
    return { applied: false, newRequest: false, reason };
  }
  const previousAt =
    profile.documents_required_at && typeof profile.documents_required_at.toMillis === "function"
      ? profile.documents_required_at.toMillis()
      : null;
  const sameRequest =
    profile.status === DriverStatuses.DOCUMENTS_REQUIRED &&
    previousAt !== null &&
    params.nowMs - previousAt < SAME_REQUEST_WINDOW_MS;
  const previousReason = typeof profile.documents_required_reason === "string" ? profile.documents_required_reason.trim() : "";
  const merged = sameRequest && previousReason && !previousReason.includes(reason)
    ? `${previousReason}\n${reason}`
    : reason;

  tx.update(params.driverRef, {
    status: DriverStatuses.DOCUMENTS_REQUIRED,
    documents_required_reason: merged.slice(0, 1000),
    documents_required_by_user_id: params.actorUid,
    ...(sameRequest ? {} : { documents_required_at: admin.firestore.Timestamp.fromMillis(params.nowMs) }),
  });
  return { applied: true, newRequest: !sameRequest, reason: merged };
}

/** Cloche du chauffeur : « Documents à fournir — votre dossier est en suspens ». */
export async function notifyDriverDocumentsRequired(driverId: string, reason: string): Promise<void> {
  const ref = db.collection("users").doc(driverId).collection("notifications").doc();
  await ref.set({
    id: ref.id,
    type: "driver_documents_required",
    title_key: "notif_driver_documents_required_title",
    body_key: "notif_driver_documents_required_body",
    is_read: false,
    created_at: admin.firestore.Timestamp.now(),
    related_mission_id: null,
    metadata: { reason: reason.slice(0, 500) },
  });
}
