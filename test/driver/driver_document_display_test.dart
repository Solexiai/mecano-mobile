import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/backend/models/driver_document.dart';
import 'package:movik_connect/models/driver_document_slots.dart';
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

    // Daniel, 2026-11-12 : permis recto et verso.
    test('distingue le recto et le verso du permis ; ancien permis gardé', () {
      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.driversLicence,
            'driver_documents/driver_test/drivers_licence_front_1.jpg',
          ),
        ),
        'doc_slot_licence_front',
      );
      expect(
        driverDocumentLabelKey(
          _doc(
            DriverDocumentType.driversLicence,
            'driver_documents/driver_test/drivers_licence_back_2.pdf',
          ),
        ),
        'doc_slot_licence_back',
      );
      final legacy = _doc(
        DriverDocumentType.driversLicence,
        'driver_documents/driver_test/drivers_licence_3.jpg',
      );
      expect(driverDocumentLabelKey(legacy), 'doc_type_drivers_licence');
      expect(isLegacyLicence(legacy), isTrue);
    });
  });

  test('range les documents par place, les autres à part', () {
    final groups = groupDriverDocuments([
      _doc(DriverDocumentType.driversLicence, 'driver_documents/d/drivers_licence_front_1.jpg'),
      _doc(DriverDocumentType.insurance, 'driver_documents/d/insurance_1.jpg'),
      _doc(DriverDocumentType.identity, 'driver_documents/d/identity_1.jpg'),
      _doc(DriverDocumentType.vehiclePhoto, 'driver_documents/d/vehicle_plate_photo_1.jpg'),
    ]);
    expect(groups.bySlot['drivers_licence_front'], hasLength(1));
    expect(groups.bySlot['drivers_licence_back'], isEmpty);
    expect(groups.bySlot['insurance'], hasLength(1));
    expect(groups.bySlot['vehicle_plate_photo'], hasLength(1));
    expect(groups.others.single.type, DriverDocumentType.identity);
    expect(
      driverDocumentSlots.where((s) => s.required).map((s) => s.id),
      ['drivers_licence_front', 'drivers_licence_back', 'vehicle_registration', 'insurance'],
    );
    expect(driverDocumentSlots.map((s) => s.type), isNot(contains(DriverDocumentType.identity)));
  });
}
