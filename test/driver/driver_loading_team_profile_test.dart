import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/models/enums.dart';

DriverProfileV2 profile(int size) => DriverProfileV2(
  uid: 'test_driver',
  fullName: 'Test Driver',
  city: 'Granby',
  status: DriverStatus.registrationIncomplete,
  serviceRadiusKm: 25,
  acceptedVehicleCategories: const [],
  acceptedItemCategoryKeys: const [],
  createdAt: DateTime.utc(2026, 10, 19),
  maxLoadingTeamSize: size,
);

void main() {
  for (var size = 1; size <= 5; size++) {
    test('profile round-trip retains $size total people including driver', () {
      final json = profile(size).toJson();
      expect(json['max_loading_team_size'], size);
      expect(
        DriverProfileV2.fromJson('test_driver', json).maxLoadingTeamSize,
        size,
      );
    });
  }
  test('legacy assistance boolean does not invent a team size', () {
    for (final legacy in [true, false]) {
      final old = DriverProfileV2.fromJson('legacy', {
        'loading_assistance_available': legacy,
      });
      expect(old.maxLoadingTeamSize, isNull);
      expect(old.loadingAssistanceAvailable, legacy);
      expect(old.toJson().containsKey('max_loading_team_size'), isFalse);
    }
  });
  test('invalid stored counts remain unknown', () {
    for (final invalid in [0, 6, -1, '3', 2.5, true, null]) {
      expect(
        DriverProfileV2.fromJson('test_driver', {
          'max_loading_team_size': invalid,
        }).maxLoadingTeamSize,
        isNull,
      );
    }
  });
  test('serialization rejects a team outside one to five', () {
    for (final invalid in [0, 6, -1]) {
      expect(() => profile(invalid).toJson(), throwsArgumentError);
    }
  });
}
