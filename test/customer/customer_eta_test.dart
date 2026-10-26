// Heure d'arrivée estimée du suivi (maquette écran 2, 2026-10-25).
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/customer/customer_mission_view.dart';

DeliveryMission _m(
  MissionStatus status, {
  DateTime? pickedUpAt,
  double? minutes = 25,
}) => DeliveryMission(
  id: 'eta',
  customerId: 'c',
  customerDisplayName: 'C',
  itemCategoryKey: 'cat_furniture',
  description: 'Divan',
  requiredVehicleCategory: VehicleCategory.pickupTruck,
  status: status,
  pricingVersion: 'TEST',
  createdAt: DateTime(2026, 10, 23, 9),
  pickedUpAt: pickedUpAt,
  estimatedDurationMinutes: minutes,
  driverOfferAmount: 20,
  customerTotal: 25,
);

void main() {
  final loaded = DateTime(2026, 10, 23, 13, 58);
  final now = DateTime(2026, 10, 23, 14, 5);
  test('after pickup: pickup time plus the route time', () {
    expect(
      customerEstimatedArrival(
        _m(MissionStatus.inTransit, pickedUpAt: loaded),
        now,
      ),
      DateTime(2026, 10, 23, 14, 23),
    );
    expect(customerTimeLabel(DateTime(2026, 10, 23, 14, 23), 'fr'), '14 h 23');
  });
  test('no estimate before pickup, without data, or once past', () {
    expect(
      customerEstimatedArrival(
        _m(MissionStatus.driverToPickup, pickedUpAt: loaded),
        now,
      ),
      isNull,
    );
    expect(customerEstimatedArrival(_m(MissionStatus.inTransit), now), isNull);
    expect(
      customerEstimatedArrival(
        _m(MissionStatus.inTransit, pickedUpAt: loaded, minutes: null),
        now,
      ),
      isNull,
    );
    expect(
      customerEstimatedArrival(
        _m(MissionStatus.inTransit, pickedUpAt: loaded),
        DateTime(2026, 10, 23, 15),
      ),
      isNull,
    );
  });
}
