// 2026-11-07 (« comme Uber ») : suivi de position tant que le chauffeur est
// en service — envoi au plus toutes les 2 min OU dès 100 m parcourus.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/services/driver_online_location_service.dart';

class _Repo implements LocationRepository {
  final reports = <DriverLocation>[];
  bool fail = false;
  @override
  Future<void> reportDriverLocation(DriverLocation location) async {
    if (fail) throw Exception('réseau');
    reports.add(location);
  }

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) => Stream.value(null);
  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(String driverId, {required String missionId}) =>
      Stream.value(const []);
}

Position _pos(double lat, double lng) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 11, 7),
  accuracy: 10,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _Repo repo;
  late StreamController<Position> positions;
  LocationSettings? captured;
  final service = DriverOnlineLocationService.instance;

  setUp(() {
    repo = _Repo();
    positions = StreamController<Position>();
    captured = null;
    BackendLocator.locationRepositoryOverride = repo;
    DriverOnlineLocationService.permissionOverride = () async => true;
    DriverOnlineLocationService.positionStreamOverride = (s) {
      captured = s;
      return positions.stream;
    };
    service.resetForTest();
  });

  tearDown(() async {
    await service.stop();
    await positions.close();
    BackendLocator.locationRepositoryOverride = null;
    DriverOnlineLocationService.permissionOverride = null;
    DriverOnlineLocationService.positionStreamOverride = null;
  });

  test('démarre avec une notification persistante Android, envoie la première position', () async {
    await service.start(title: 'Movi-K — En service', text: 'Position partagée');
    expect(service.isRunning, isTrue);
    final android = captured as AndroidSettings;
    expect(android.foregroundNotificationConfig?.notificationTitle, 'Movi-K — En service');
    expect(android.foregroundNotificationConfig?.setOngoing, isTrue);
    positions.add(_pos(45.6987, -73.6603));
    await Future<void>.delayed(Duration.zero);
    expect(repo.reports, hasLength(1));
    expect(repo.reports.single.latitude, 45.6987);
  });

  test('throttle : 10 m plus loin dans les 2 min = pas d’envoi ; 150 m = envoi', () async {
    await service.start(title: 't', text: 'x');
    positions.add(_pos(45.6987, -73.6603));
    await Future<void>.delayed(Duration.zero);
    positions.add(_pos(45.69879, -73.6603)); // ~10 m
    await Future<void>.delayed(Duration.zero);
    expect(repo.reports, hasLength(1));
    positions.add(_pos(45.70005, -73.6603)); // ~150 m
    await Future<void>.delayed(Duration.zero);
    expect(repo.reports, hasLength(2));
  });

  test('shouldSend : délai de 2 min écoulé => envoi même sans déplacement', () async {
    await service.start(title: 't', text: 'x');
    positions.add(_pos(45.0, -73.0));
    await Future<void>.delayed(Duration.zero);
    final now = DateTime.now();
    expect(service.shouldSend(_pos(45.0, -73.0), now.add(const Duration(seconds: 30))), isFalse);
    expect(service.shouldSend(_pos(45.0, -73.0), now.add(const Duration(minutes: 2, seconds: 1))), isTrue);
  });

  test('échec réseau : réessaie au relevé suivant ; stop coupe le flux ; permission refusée = rien', () async {
    await service.start(title: 't', text: 'x');
    repo.fail = true;
    positions.add(_pos(45.0, -73.0));
    await Future<void>.delayed(Duration.zero);
    repo.fail = false;
    positions.add(_pos(45.0, -73.0)); // même point, mais l'envoi précédent a échoué
    await Future<void>.delayed(Duration.zero);
    expect(repo.reports, hasLength(1));
    await service.stop();
    expect(service.isRunning, isFalse);

    DriverOnlineLocationService.permissionOverride = () async => false;
    await service.start(title: 't', text: 'x');
    expect(service.isRunning, isFalse);
  });
}
