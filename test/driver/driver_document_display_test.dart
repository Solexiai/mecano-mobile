import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/admin/drivers/driver_document_display.dart';

DriverDocument _doc(DriverDocumentType type, String path) {
  return DriverDocument(
    id: 'doc_test',
    driverId: 'driver_test',
    type: type,
    status: DriverDocumentStatus.uploaded,
    storageBucketPath: path,
    uploadedAt: DateTime(2026, 9, 12),
  );
}

void main() {
  group('driverDocumentLabelKey', () {
    test('distingue les trois photos du véhicule par leur chemin Storage', () {
      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.vehiclePhoto,
            'driver_documents/driver_test/vehicle_main_photo_123.jpg',
          ),
        ),
        'admin_driver_doc_vehicle_main_photo',
      );

      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.vehiclePhoto,
            'driver_documents/driver_test/vehicle_rear_photo_456.jpg',
          ),
        ),
        'admin_driver_doc_vehicle_rear_photo',
      );

      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.vehiclePhoto,
            'driver_documents/driver_test/vehicle_plate_photo_789.jpg',
          ),
        ),
        'admin_driver_doc_vehicle_plate_photo',
      );
    });

    test('conserve le libellé générique pour une ancienne photo véhicule', () {
      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.vehiclePhoto,
            'driver_documents/driver_test/legacy_vehicle.jpg',
          ),
        ),
        'doc_type_vehicle_photo',
      );
    });

    test('ne modifie pas les autres types de document', () {
      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.insurance,
            'driver_documents/driver_test/insurance.jpg',
          ),
        ),
        'doc_type_insurance',
      );
    });
  });
}
