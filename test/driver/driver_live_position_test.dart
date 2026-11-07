// 2026-11-07 : fraîcheur de la position affichée sur la carte d'accueil
// (même règle que le dispatch serveur : 30 minutes).
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/services/driver_live_position.dart';

void main() {
  final now = DateTime(2026, 11, 7, 14, 0);
  DriverLocation loc(DateTime? at) => DriverLocation(
    driverId: 'd',
    latitude: 45.6987,
    longitude: -73.6603,
    updatedAt: at,
  );

  test('position de moins de 30 min : affichée', () {
    final p = livePositionFor(loc(now.subtract(const Duration(minutes: 29))), now);
    expect(p?.latitude, 45.6987);
    expect(p?.longitude, -73.6603);
  });

  test('position de plus de 30 min, date absente ou document absent : rien', () {
    expect(livePositionFor(loc(now.subtract(const Duration(minutes: 31))), now), isNull);
    expect(livePositionFor(loc(null), now), isNull);
    expect(livePositionFor(null, now), isNull);
  });
}
