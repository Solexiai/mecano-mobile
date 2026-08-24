// ---------------------------------------------------------------------------
// Test unitaire — DriverLocationReporter (Phase 7, Bloc C, ACTION 3).
//
// Couvre les cas négatifs GPS demandés explicitement par l'utilisateur et
// jusqu'ici NON couverts par aucun test existant (grep exhaustif de
// `DriverLocationReporter`/`LocationReporterError` dans test/ : aucune
// occurrence avant ce fichier) :
//   - GPS désactivé (isLocationServiceEnabled == false)
//   - GPS refusé (permission denied / deniedForever)
//   - échec du rapport de position (reportDriverLocation throw)
//   - cas nominal : démarrage, tick périodique, arrêt propre (stop())
//
// Stratégie : `FakeGeolocatorPlatform extends GeolocatorPlatform` (jamais
// `implements`, cf. doc du package — `extends` est requis pour que
// PlatformInterface.verify() accepte l'instance) injecté via
// `GeolocatorPlatform.instance =`, et `FakeLocationRepository implements
// LocationRepository` injecté via le seam de test
// `BackendLocator.locationRepositoryOverride` (même pattern que
// `missionRepositoryOverride`, Phase 7 Bloc B).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/services/driver_location_reporter.dart';

class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permissionOnCheck = LocationPermission.always;
  LocationPermission permissionOnRequest = LocationPermission.always;
  bool throwOnGetPosition = false;
  int getCurrentPositionCallCount = 0;
  int checkPermissionCallCount = 0;
  int requestPermissionCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCallCount++;
    return permissionOnCheck;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCallCount++;
    return permissionOnRequest;
  }

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    getCurrentPositionCallCount++;
    if (throwOnGetPosition) {
      throw Exception('GPS indisponible (simulation test)');
    }
    return Position(
      longitude: -73.7,
      latitude: 45.6,
      timestamp: DateTime.now(),
      accuracy: 5.0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

class FakeLocationRepository implements LocationRepository {
  int reportCallCount = 0;
  bool throwOnReport = false;
  DriverLocation? lastReported;

  @override
  Future<void> reportDriverLocation(DriverLocation location) async {
    reportCallCount++;
    if (throwOnReport) {
      throw Exception('Échec réseau Cloud Function recordTrackingPoint (simulation test)');
    }
    lastReported = location;
  }

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) => Stream.value(null);

  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(String driverId) =>
      Stream.value(const []);
}

void main() {
  late FakeGeolocatorPlatform fakeGeolocator;
  late FakeLocationRepository fakeRepository;

  setUp(() {
    fakeGeolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakeGeolocator;
    fakeRepository = FakeLocationRepository();
    BackendLocator.locationRepositoryOverride = fakeRepository;
  });

  tearDown(() {
    BackendLocator.locationRepositoryOverride = null;
  });

  group('DriverLocationReporter — GPS désactivé', () {
    test('start() signale serviceDisabled et ne démarre pas la boucle si le service GPS est désactivé', () async {
      fakeGeolocator.serviceEnabled = false;
      final reporter = DriverLocationReporter();
      LocationReporterError? capturedError;

      await reporter.start(onError: (e) => capturedError = e);

      expect(capturedError, LocationReporterError.serviceDisabled);
      expect(reporter.isRunning, isFalse);
      expect(fakeRepository.reportCallCount, 0);
    });
  });

  group('DriverLocationReporter — GPS refusé', () {
    test('start() signale permissionDenied si la permission est refusée après demande', () async {
      fakeGeolocator.permissionOnCheck = LocationPermission.denied;
      fakeGeolocator.permissionOnRequest = LocationPermission.denied;
      final reporter = DriverLocationReporter();
      LocationReporterError? capturedError;

      await reporter.start(onError: (e) => capturedError = e);

      expect(capturedError, LocationReporterError.permissionDenied);
      expect(reporter.isRunning, isFalse);
      expect(fakeGeolocator.requestPermissionCallCount, 1);
      expect(fakeRepository.reportCallCount, 0);
    });

    test('start() signale permissionDeniedForever si la permission est refusée définitivement', () async {
      fakeGeolocator.permissionOnCheck = LocationPermission.deniedForever;
      final reporter = DriverLocationReporter();
      LocationReporterError? capturedError;

      await reporter.start(onError: (e) => capturedError = e);

      expect(capturedError, LocationReporterError.permissionDeniedForever);
      expect(reporter.isRunning, isFalse);
      // deniedForever est constaté directement à checkPermission() : pas de
      // nouvelle demande de permission (comportement standard Android/iOS).
      expect(fakeGeolocator.requestPermissionCallCount, 0);
      expect(fakeRepository.reportCallCount, 0);
    });

    test(
      'checkPermission()==denied puis requestPermission()==granted : la boucle démarre normalement',
      () async {
        fakeGeolocator.permissionOnCheck = LocationPermission.denied;
        fakeGeolocator.permissionOnRequest = LocationPermission.whileInUse;
        final reporter = DriverLocationReporter();
        LocationReporterError? capturedError;

        await reporter.start(onError: (e) => capturedError = e);

        expect(capturedError, isNull);
        expect(reporter.isRunning, isTrue);
        expect(fakeRepository.reportCallCount, 1);
        reporter.stop();
      },
    );
  });

  group('DriverLocationReporter — échec du rapport de position', () {
    test('reportFailed est signalé si reportDriverLocation() échoue, sans jamais interrompre silencieusement', () async {
      fakeRepository.throwOnReport = true;
      final reporter = DriverLocationReporter();
      LocationReporterError? capturedError;

      await reporter.start(onError: (e) => capturedError = e);

      expect(capturedError, LocationReporterError.reportFailed);
      // La boucle continue de tourner (l'appelant décide d'arrêter ou pas) —
      // un échec ponctuel de rapport n'interrompt pas le Timer.
      expect(reporter.isRunning, isTrue);
      reporter.stop();
    });

    test('reportFailed est signalé si getCurrentPosition() échoue (GPS indisponible en cours de trajet)', () async {
      fakeGeolocator.throwOnGetPosition = true;
      final reporter = DriverLocationReporter();
      LocationReporterError? capturedError;

      await reporter.start(onError: (e) => capturedError = e);

      expect(capturedError, LocationReporterError.reportFailed);
      expect(fakeRepository.reportCallCount, 0);
      reporter.stop();
    });
  });

  group('DriverLocationReporter — cas nominal', () {
    test('start() envoie un premier rapport immédiat puis démarre le Timer périodique', () async {
      final reporter = DriverLocationReporter();
      LocationReporterError? capturedError;

      await reporter.start(onError: (e) => capturedError = e);

      expect(capturedError, isNull);
      expect(reporter.isRunning, isTrue);
      expect(fakeRepository.reportCallCount, 1);
      expect(fakeRepository.lastReported?.latitude, 45.6);
      expect(fakeRepository.lastReported?.longitude, -73.7);
      reporter.stop();
      expect(reporter.isRunning, isFalse);
    });

    test('start() est idempotent : un second appel alors que la boucle tourne déjà ne fait rien', () async {
      final reporter = DriverLocationReporter();
      await reporter.start(onError: (_) {});
      final countAfterFirstStart = fakeRepository.reportCallCount;

      await reporter.start(onError: (_) {});

      expect(fakeRepository.reportCallCount, countAfterFirstStart);
      reporter.stop();
    });

    test('stop() arrête bien la boucle : aucun nouveau rapport après stop()', () async {
      final reporter = DriverLocationReporter(interval: const Duration(milliseconds: 20));
      await reporter.start(onError: (_) {});
      reporter.stop();
      final countAfterStop = fakeRepository.reportCallCount;

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(fakeRepository.reportCallCount, countAfterStop);
      expect(reporter.isRunning, isFalse);
    });
  });
}
