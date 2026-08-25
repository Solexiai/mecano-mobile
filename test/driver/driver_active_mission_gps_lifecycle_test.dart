// ---------------------------------------------------------------------------
// Test widget — DriverActiveMissionScreen : LIFECYCLE du partage GPS lié au
// statut de mission (Phase 7, Bloc H, item H-2 — priorité explicite).
//
// NE DUPLIQUE PAS :
//   - `driver_location_reporter_test.dart` (permissions GPS désactivé/
//     refusé/deniedForever/refus-puis-accord/échec de rapport, idempotence
//     de `start()`, `stop()` isolé) — couvert au niveau de la classe
//     `DriverLocationReporter` seule, référencé dans PHASE7_QA_MATRIX.md.
//   - `driver_active_mission_status_gaps_test.dart` (BUG-006 : boucle
//     infinie de resynchronisation GPS sur échec permanent, bandeau
//     d'avertissement, disponibilité des actions de trajet par statut).
//
// CE FICHIER couvre exclusivement le GAP identifié H-2 : la preuve, au
// niveau de `DriverActiveMissionScreen` (pas seulement de la classe isolée
// `DriverLocationReporter`), que :
//   - CAS 1 : mission dans un statut de trajet actif (`_kGpsSharingStatuses`)
//     -> le partage démarre réellement (1 rapport de position immédiat,
//     permission vérifiée une seule fois).
//   - CAS 2 : mission -> `completed` -> le partage s'arrête (aucun nouveau
//     rapport, aucune nouvelle vérification de permission).
//   - CAS 3 : mission -> `cancelled` -> même exigence que CAS 2.
//   - IDEMPOTENCE : une succession de statuts qui restent tous dans
//     `_kGpsSharingStatuses` ne redémarre JAMAIS une seconde boucle (la
//     permission n'est vérifiée qu'une seule fois au total).
//   - Démontage de l'écran (dispose) alors que le partage est actif ->
//     `stop()` appelé sans exception, aucun rapport résiduel après.
//   - `DriverLocationReporter.stop()` appelé deux fois de suite (hors
//     contexte écran) -> aucune exception, état propre (`isRunning` reste
//     `false`) — exigence explicite H-2 "double-stop".
//
// STRATÉGIE : réutilise exactement l'architecture déjà établie et validée
// par `driver_active_mission_status_gaps_test.dart` (`_FakeMissionRepository`
// StreamController non-broadcast + `FakeGeolocatorPlatform extends
// GeolocatorPlatform` + `BackendLocator.locationRepositoryOverride`), en
// ajoutant uniquement des compteurs d'appels pour observer précisément le
// lifecycle (aucune modification du code de production nécessaire : tout
// est déjà observable via les seams de test existants).
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/delivery_quote.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_active_mission_screen.dart';
import 'package:movik_connect/services/driver_location_reporter.dart';

const _driverId = 'driver_test_gps_lifecycle_001';
const _missionId = 'mission_test_gps_lifecycle';

/// GPS toujours prêt (service activé, permission accordée), avec compteurs
/// d'appels pour observer précisément combien de fois `start()` a réellement
/// exécuté sa logique de permission (preuve d'idempotence au niveau écran).
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permissionOnCheck = LocationPermission.always;
  int checkPermissionCallCount = 0;
  int getCurrentPositionCallCount = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCallCount++;
    return permissionOnCheck;
  }

  @override
  Future<LocationPermission> requestPermission() async => permissionOnCheck;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
    getCurrentPositionCallCount++;
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

/// `LocationRepository` spy : compte les rapports de position réellement
/// envoyés (preuve directe qu'aucun rapport n'est envoyé après arrêt).
class _FakeLocationRepository implements LocationRepository {
  int reportCallCount = 0;

  @override
  Future<void> reportDriverLocation(DriverLocation location) async {
    reportCallCount++;
  }

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) => Stream.value(null);

  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(String driverId) =>
      Stream.value(const []);
}

/// `MissionRepository` fake — permet de rejouer la mission avec un nouveau
/// statut (simulateur de mise à jour temps réel Firestore), même pattern
/// exact que `driver_active_mission_status_gaps_test.dart`.
class _FakeMissionRepository implements MissionRepository {
  DeliveryMission mission;
  final _controller = StreamController<DeliveryMission?>();

  _FakeMissionRepository(this.mission) {
    _controller.add(mission);
  }

  void advanceTo(MissionStatus status) {
    mission = _copyWithStatus(mission, status);
    _controller.add(mission);
  }

  void dispose() => _controller.close();

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => _controller.stream;

  @override
  Future<void> markPickupCompleted(String missionId) async {
    advanceTo(MissionStatus.pickedUp);
  }

  @override
  Future<void> updateTrackingStatus({
    required String missionId,
    required MissionStatus targetStatus,
  }) async {
    advanceTo(targetStatus);
  }

  // ---- Méthodes non utilisées par ce parcours de test ----
  @override
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  }) => throw UnimplementedError();

  @override
  Future<DeliveryMission> createMissionFromQuote(CreateMissionRequest request) =>
      throw UnimplementedError();

  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String driverId) => Stream.value(null);

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) => Stream.value(const []);

  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId) =>
      Stream.value(const []);

  @override
  Stream<List<DeliveryOffer>> watchOffersForDriver(String driverId) => Stream.value(const []);

  @override
  Future<AcceptMissionResult> acceptMission({required String missionId, required String driverId}) async {
    return const AcceptMissionResult(success: false, errorCode: 'not_used_in_test');
  }

  @override
  Future<void> markDeliveryCompleted(String missionId, {required String proofOfDeliveryUrl}) async {}
}

DeliveryMission _copyWithStatus(DeliveryMission m, MissionStatus status) {
  return DeliveryMission(
    id: m.id,
    customerId: m.customerId,
    customerDisplayName: m.customerDisplayName,
    itemCategoryKey: m.itemCategoryKey,
    description: m.description,
    requiredVehicleCategory: m.requiredVehicleCategory,
    status: status,
    driverId: m.driverId,
    driverDisplayName: m.driverDisplayName,
    acceptedAt: m.acceptedAt,
    pricingVersion: m.pricingVersion,
    activeQuoteId: m.activeQuoteId,
    activeFinancialSnapshotId: m.activeFinancialSnapshotId,
    createdAt: m.createdAt,
    driverToPickupAt: m.driverToPickupAt,
    arrivedAtPickupAt: m.arrivedAtPickupAt,
    pickedUpAt: m.pickedUpAt,
    inTransitAt: m.inTransitAt,
    arrivedAtDropoffAt: m.arrivedAtDropoffAt,
    completedAt: m.completedAt,
    cancelledAt: m.cancelledAt,
    cancellationReason: m.cancellationReason,
    proofOfDeliveryUrl: m.proofOfDeliveryUrl,
    pickupAddress: m.pickupAddress,
    dropoffAddress: m.dropoffAddress,
    distanceKm: m.distanceKm,
    estimatedDurationMinutes: m.estimatedDurationMinutes,
    driverOfferAmount: m.driverOfferAmount,
    customerTotal: m.customerTotal,
  );
}

DeliveryMission _buildMission({required MissionStatus status}) {
  return DeliveryMission(
    id: _missionId,
    customerId: 'customer_test_gps_lifecycle_001',
    itemCategoryKey: 'cat_furniture',
    description: 'Réfrigérateur',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: status,
    driverId: _driverId,
    pricingVersion: 'TEST-V1',
    createdAt: DateTime.now(),
    pickupAddress: const MissionAddress(
      line1: '10 rue Départ',
      city: 'Montréal',
      postalCode: 'H2X1Y1',
      lat: 45.5,
      lng: -73.6,
    ),
    dropoffAddress: const MissionAddress(
      line1: '20 rue Arrivée',
      city: 'Laval',
      postalCode: 'H7X1Y1',
      lat: 45.6,
      lng: -73.7,
    ),
    driverOfferAmount: 95,
    customerTotal: 140,
  );
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/provider/mission/$_missionId',
    routes: [
      GoRoute(
        path: '/fr/provider/mission/:missionId',
        builder: (context, state) =>
            DriverActiveMissionScreen(missionId: state.pathParameters['missionId']!),
      ),
      GoRoute(
        path: '/fr/provider/dashboard',
        builder: (context, state) => const Scaffold(body: Text('DASHBOARD_STUB')),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late FakeGeolocatorPlatform fakeGeolocator;
  late _FakeLocationRepository fakeLocationRepo;
  late FirebaseAuthProvider auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeGeolocator = FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakeGeolocator;
    fakeLocationRepo = _FakeLocationRepository();
    BackendLocator.locationRepositoryOverride = fakeLocationRepo;

    auth = FirebaseAuthProvider(backendConfigured: false);
    auth.debugForceSignedIn = true;
    auth.debugForceUid = _driverId;
    auth.debugForceDisplayName = 'Chauffeur Test';
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.locationRepositoryOverride = null;
  });

  String btn(String key) => AppStrings.t(key, 'fr');

  group('H-2 — Lifecycle GPS : CAS 1 (mission active -> start)', () {
    testWidgets(
      'mission assigned (statut de partage) : 1 rapport de position immédiat, permission vérifiée une seule fois',
      (tester) async {
        final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.assigned));
        BackendLocator.missionRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();

        expect(fakeLocationRepo.reportCallCount, 1);
        expect(fakeGeolocator.checkPermissionCallCount, 1);
        expect(fakeGeolocator.getCurrentPositionCallCount, 1);
      },
    );
  });

  group('H-2 — Lifecycle GPS : CAS 2 (mission completed -> stop)', () {
    testWidgets(
      'inTransit -> completed : le partage s\'arrête, aucun nouveau rapport, aucune nouvelle vérification de permission',
      (tester) async {
        final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.inTransit));
        BackendLocator.missionRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();

        // Le partage a démarré normalement au statut actif (preuve CAS 1
        // déjà établie ci-dessus, ré-affirmée ici comme précondition).
        expect(fakeLocationRepo.reportCallCount, 1);
        expect(fakeGeolocator.checkPermissionCallCount, 1);

        fakeRepo.advanceTo(MissionStatus.completed);
        await tester.pumpAndSettle();

        // Écran "déjà complétée" affiché, ressources GPS nettoyées (stop()
        // appelé par le bloc `mission.status == MissionStatus.completed`).
        expect(
          find.text(btn('driver_active_mission_already_completed')),
          findsOneWidget,
        );
        expect(fakeLocationRepo.reportCallCount, 1, reason: 'aucun nouveau rapport après completed');
        expect(
          fakeGeolocator.checkPermissionCallCount,
          1,
          reason: 'stop() ne doit jamais retenter une vérification de permission',
        );

        // Laisse passer plusieurs frames supplémentaires pour confirmer
        // qu'aucune boucle résiduelle ne persiste (même esprit que la
        // sonde anti-régression BUG-006).
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(fakeLocationRepo.reportCallCount, 1);
        expect(fakeGeolocator.checkPermissionCallCount, 1);
      },
    );
  });

  group('H-2 — Lifecycle GPS : CAS 3 (mission cancelled -> stop)', () {
    testWidgets(
      'driverToPickup -> cancelled : le partage s\'arrête, aucun nouveau rapport, aucune nouvelle vérification de permission',
      (tester) async {
        final fakeRepo =
            _FakeMissionRepository(_buildMission(status: MissionStatus.driverToPickup));
        BackendLocator.missionRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();

        expect(fakeLocationRepo.reportCallCount, 1);
        expect(fakeGeolocator.checkPermissionCallCount, 1);

        fakeRepo.advanceTo(MissionStatus.cancelled);
        await tester.pumpAndSettle();

        expect(
          find.text(btn('driver_active_mission_cancelled')),
          findsOneWidget,
        );
        expect(fakeLocationRepo.reportCallCount, 1, reason: 'aucun nouveau rapport après cancelled');
        expect(
          fakeGeolocator.checkPermissionCallCount,
          1,
          reason: 'stop() ne doit jamais retenter une vérification de permission',
        );

        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(fakeLocationRepo.reportCallCount, 1);
        expect(fakeGeolocator.checkPermissionCallCount, 1);
      },
    );
  });

  group('H-2 — Idempotence du lifecycle au niveau écran', () {
    testWidgets(
      'succession de statuts tous "partage actif" (assigned -> driverToPickup -> arrivedAtPickup) : la boucle GPS ne redémarre JAMAIS une seconde fois',
      (tester) async {
        final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.assigned));
        BackendLocator.missionRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        expect(fakeGeolocator.checkPermissionCallCount, 1);
        expect(fakeLocationRepo.reportCallCount, 1);

        // Deux transitions supplémentaires, toutes dans
        // `_kGpsSharingStatuses` : `_syncGpsSharing()` ne doit rappeler
        // `start()` que si `!_locationReporter.isRunning` — puisque la
        // boucle tourne déjà en continu, aucune nouvelle vérification de
        // permission ni aucun second `checkPermission()` ne doit survenir.
        fakeRepo.advanceTo(MissionStatus.driverToPickup);
        await tester.pumpAndSettle();
        expect(fakeGeolocator.checkPermissionCallCount, 1);

        fakeRepo.advanceTo(MissionStatus.arrivedAtPickup);
        await tester.pumpAndSettle();
        expect(fakeGeolocator.checkPermissionCallCount, 1);

        // Un seul rapport immédiat au total depuis le tout premier
        // `start()` (le Timer périodique réel de 8s n'a pas le temps de
        // se déclencher pendant la durée du test).
        expect(fakeLocationRepo.reportCallCount, 1);
      },
    );
  });

  group('H-2 — Nettoyage à la fermeture de l\'écran (dispose)', () {
    testWidgets(
      'démontage de l\'écran alors que le partage est actif : stop() exécuté sans exception, aucun rapport résiduel',
      (tester) async {
        final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.pickedUp));
        BackendLocator.missionRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        expect(fakeLocationRepo.reportCallCount, 1);

        // Remplace l'arbre de widgets par un écran neutre : démonte
        // `DriverActiveMissionScreen` (appelle `dispose()` -> `stop()`).
        await tester.pumpWidget(const MaterialApp(home: Scaffold(body: Text('AUTRE_ECRAN'))));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeLocationRepo.reportCallCount, 1);
      },
    );
  });

  group('H-2 — Idempotence stop()/stop() (isolé, hors écran)', () {
    test(
      'stop() appelé deux fois de suite ne lève aucune exception et laisse un état propre',
      () {
        final reporter = DriverLocationReporter();

        expect(reporter.isRunning, isFalse);
        expect(() => reporter.stop(), returnsNormally);
        expect(reporter.isRunning, isFalse);
        expect(() => reporter.stop(), returnsNormally);
        expect(reporter.isRunning, isFalse);
      },
    );
  });
}
