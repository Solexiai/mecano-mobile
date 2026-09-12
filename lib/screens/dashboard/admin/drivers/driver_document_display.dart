import '../../../../backend/models/driver_document.dart';
import '../../../../models/enums.dart';

String driverDocumentLabelKey(DriverDocument doc) {
  if (doc.type != DriverDocumentType.vehiclePhoto) {
    return doc.type.key;
  }

  final path = doc.storageBucketPath.toLowerCase();

  if (path.contains('vehicle_main_photo_')) {
    return 'admin_driver_doc_vehicle_main_photo';
  }
  if (path.contains('vehicle_rear_photo_')) {
    return 'admin_driver_doc_vehicle_rear_photo';
  }
  if (path.contains('vehicle_plate_photo_')) {
    return 'admin_driver_doc_vehicle_plate_photo';
  }

  return doc.type.key;
}
