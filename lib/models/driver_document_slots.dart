// Places de documents d'un dossier chauffeur (Daniel, 2026-11-12) :
// permis recto ET verso, plus de pièce d'identité (le permis en tient lieu).
// Chaque fichier commence par l'identifiant de sa place
// (`drivers_licence_front_…`) : c'est ainsi que le serveur reconnaît le recto
// et le verso (functions/src/lib/driverDocuments.ts — garder aligné).
// Un permis envoyé avant ce changement, en une seule image, reste valable.

import '../backend/models/driver_document.dart';
import 'enums.dart';

class DriverDocumentSlot {
  const DriverDocumentSlot(
    this.id,
    this.type,
    this.labelKey, {
    this.required = false,
  });

  /// Identifiant de la place, aussi début du nom de fichier.
  final String id;
  final DriverDocumentType type;
  final String labelKey;

  /// Obligatoire pour approuver le dossier.
  final bool required;
}

const licenceFrontSlot = DriverDocumentSlot(
  'drivers_licence_front',
  DriverDocumentType.driversLicence,
  'doc_slot_licence_front',
  required: true,
);
const licenceBackSlot = DriverDocumentSlot(
  'drivers_licence_back',
  DriverDocumentType.driversLicence,
  'doc_slot_licence_back',
  required: true,
);

/// Toutes les places, dans l'ordre d'affichage.
const driverDocumentSlots = <DriverDocumentSlot>[
  licenceFrontSlot,
  licenceBackSlot,
  DriverDocumentSlot(
    'vehicle_registration',
    DriverDocumentType.vehicleRegistration,
    'doc_type_vehicle_registration',
    required: true,
  ),
  DriverDocumentSlot(
    'insurance',
    DriverDocumentType.insurance,
    'doc_type_insurance',
    required: true,
  ),
  DriverDocumentSlot(
    'vehicle_main_photo',
    DriverDocumentType.vehiclePhoto,
    'admin_driver_doc_vehicle_main_photo',
  ),
  DriverDocumentSlot(
    'vehicle_rear_photo',
    DriverDocumentType.vehiclePhoto,
    'admin_driver_doc_vehicle_rear_photo',
  ),
  DriverDocumentSlot(
    'vehicle_plate_photo',
    DriverDocumentType.vehiclePhoto,
    'admin_driver_doc_vehicle_plate_photo',
  ),
];

/// Place pour les documents qui n'entrent dans aucune autre (côté agent).
const otherDocumentSlot = DriverDocumentSlot(
  'other',
  DriverDocumentType.other,
  'doc_type_other',
);

String _fileName(DriverDocument doc) =>
    doc.storageBucketPath.split('/').last.toLowerCase();

/// Place d'un document envoyé, ou null (ancien permis en une image, pièce
/// d'identité d'avant le 12 nov. 2026, autre document).
DriverDocumentSlot? driverDocumentSlotOf(DriverDocument doc) {
  final name = _fileName(doc);
  for (final slot in driverDocumentSlots) {
    if (slot.type == doc.type && name.startsWith('${slot.id}_')) return slot;
  }
  return null;
}

/// Ancien permis envoyé en une seule image : il vaut recto et verso.
bool isLegacyLicence(DriverDocument doc) =>
    doc.type == DriverDocumentType.driversLicence &&
    driverDocumentSlotOf(doc) == null;

/// Documents rangés par place ; les autres (ancien permis compris) à part.
({Map<String, List<DriverDocument>> bySlot, List<DriverDocument> others})
groupDriverDocuments(Iterable<DriverDocument> docs) {
  final bySlot = {for (final slot in driverDocumentSlots) slot.id: <DriverDocument>[]};
  final others = <DriverDocument>[];
  for (final doc in docs) {
    final slot = driverDocumentSlotOf(doc);
    if (slot == null) {
      others.add(doc);
    } else {
      bySlot[slot.id]!.add(doc);
    }
  }
  return (bySlot: bySlot, others: others);
}
