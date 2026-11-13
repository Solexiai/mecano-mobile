import '../../../../backend/models/driver_document.dart';
import '../../../../models/driver_document_slots.dart';
import '../../../../models/enums.dart';

/// Libellé d'un document : sa place (permis recto/verso, photos du
/// véhicule…) quand le nom du fichier l'indique, sinon son type.
String driverDocumentLabelKey(DriverDocument doc) =>
    driverDocumentSlotOf(doc)?.labelKey ?? doc.type.key;
