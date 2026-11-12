// -----------------------------------------------------------------------------
// driverDocuments.ts — documents obligatoires d'un chauffeur (Daniel,
// 2026-11-12).
//
//   - Plus de « pièce d'identité » : le permis de conduire en tient lieu.
//   - Permis de conduire RECTO et VERSO : deux fichiers de type
//     `drivers_licence`, reconnus par le nom du fichier
//     (`drivers_licence_front_…`, `drivers_licence_back_…`). Un permis envoyé
//     avant ce changement, en une seule image, reste valable.
//   - Les agents peuvent ajouter un document reçu par courriel
//     (adminAddDriverDocument) dans l'une des places ci-dessous.
//
// Utilisé par validateDriverDocument (documents_all_valid), approveDriver et
// reviewDriverVehicle : une seule règle pour les trois. Doit rester aligné
// avec lib/models/driver_document_slots.dart.
// -----------------------------------------------------------------------------

type Doc = Record<string, any>;

export const REQUIRED_DRIVER_DOCUMENT_TYPES = [
  "drivers_licence",
  "vehicle_registration",
  "insurance",
] as const;

/** Places de documents d'un dossier chauffeur : nom de fichier → type. */
export const DRIVER_DOCUMENT_SLOTS: Record<string, { type: string }> = {
  drivers_licence_front: { type: "drivers_licence" },
  drivers_licence_back: { type: "drivers_licence" },
  vehicle_registration: { type: "vehicle_registration" },
  insurance: { type: "insurance" },
  vehicle_main_photo: { type: "vehicle_photo" },
  vehicle_rear_photo: { type: "vehicle_photo" },
  vehicle_plate_photo: { type: "vehicle_photo" },
  other: { type: "other" },
};

function fileNameOf(doc: Doc): string {
  const path = typeof doc.storage_bucket_path === "string" ? doc.storage_bucket_path : "";
  return path.split("/").pop() ?? "";
}

/** Côté du permis : recto, verso, ou null (ancien envoi en une seule image). */
export function licenceSide(doc: Doc): "front" | "back" | null {
  const name = fileNameOf(doc);
  if (name.startsWith("drivers_licence_front_")) return "front";
  if (name.startsWith("drivers_licence_back_")) return "back";
  return null;
}

/**
 * Documents obligatoires manquants parmi [docs], selon [isValid] (approuvé,
 * non expiré…). Vide = dossier complet. Le permis est complet avec un recto
 * ET un verso valides, ou avec un ancien permis valide envoyé en une image.
 */
export function missingRequiredDocuments(
  docs: Doc[],
  isValid: (doc: Doc) => boolean
): string[] {
  const valid = docs.filter(isValid);
  const missing: string[] = [];
  const licences = valid.filter((d) => d.type === "drivers_licence");
  const legacy = licences.some((d) => licenceSide(d) === null);
  if (!legacy) {
    if (!licences.some((d) => licenceSide(d) === "front")) missing.push("drivers_licence_front");
    if (!licences.some((d) => licenceSide(d) === "back")) missing.push("drivers_licence_back");
  }
  for (const type of REQUIRED_DRIVER_DOCUMENT_TYPES) {
    if (type === "drivers_licence") continue;
    if (!valid.some((d) => d.type === type)) missing.push(type);
  }
  return missing;
}
