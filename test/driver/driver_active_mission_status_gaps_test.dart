// ---------------------------------------------------------------------------
// Test widget — DriverActiveMissionScreen : couverture des statuts de
// trajet non couverts par `driver_active_mission_proof_upload_test.dart`
// (Phase 7, Bloc C — item 3, sous-tâche 2/3).
//
// NE DUPLIQUE PAS les tests proof déjà verts (upload failure / retry /
// NotConfigured) : ce fichier couvre exclusivement les transitions
// intermédiaires de trajet et la disponibilité des actions par statut :
//   - assigned          -> bouton "partir vers le pickup" (driverToPickup)
//   - driverToPickup     -> bouton "arrivé au pickup" (arrivedAtPickup)
//   - arrivedAtPickup    -> bouton "confirmer prise en charge" (markPickupCompleted)
//   - pickedUp           -> bouton "démarrer le trajet" (inTransit)
//   - inTransit          -> bouton "arrivé à destination" (arrivedAtDropoff)
//   - arrivedAtDropoff   -> bouton "capturer photo" (couvert en détail par
//     le fichier proof_upload ; ici on vérifie juste qu'AUCUNE autre action
//     de trajet n'apparaît à ce statut)
//   - completed          -> écran "déjà complétée", aucune action de trajet
//   - erreur GPS pendant le trajet -> bandeau d'avertissement affiché sans
//     bloquer les actions
//   - actions disponibles UNIQUEMENT au statut correspondant (pas de bouton
//     d'une autre étape visible simultanément)
//
// STRATÉGIE (réutilise l'architecture existante) :
//   - `BackendLocator.missionRepositoryOverride` avec un
//     `_FakeMissionRepository` qui compte les appels à
//     `updateTrackingStatus()`/`markPickupCompleted()` et permet de rejouer
//     la mission avec un nouveau statut via un `StreamController`.
//   - `BackendLocator.locationRepositoryOverride` avec un
//     `_FakeLocationRepository` neutre (Stream.value(null)) pour éviter
//     toute dépendance à Firestore réel dans `LiveTrackingMap`.
//   - `GeolocatorPlatform.instance = FakeGeolocatorPlatform` (même pattern
//     que `driver_location_reporter_test.dart`) pour contrôler
//     déterministement le partage GPS déclenché par
//     `DriverActiveMissionScreen._syncGpsSharing()` sans dépendre du vrai
//     plugin natif ni de vrais timers longs.
//   - `FirebaseAuthProvider(backendConfigured: false)` +
//     `debugForceSignedIn`/`debugForceUid` (pattern établi).
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

const _driverId = 'driver_test_gaps_001';
const _missionId = 'mission_test_status_gaps';

/// GPS toujours prêt (service activé, permission accordée) — évite tout
/// bandeau d'avertissement GPS non désiré dans les tests de statut nominal,
/// et permet un test dédié où l'on force explicitement une erreur.
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission permissionOnCheck = LocationPermission.always;
  LocationPermission permissionOnRequest = LocationPermission.always;

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => permissionOnCheck;

  @override
  Future<LocationPermission> requestPermission() async => permissionOnRequest;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) async {
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

/// `LocationRepository` neutre : `LiveTrackingMap` (imbriqué dans
/// `_MissionCard`) l'utilise pour sa propre carte, sans rapport avec le
/// scénario testé ici — ne doit jamais throw ni bloquer le test.
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
/// statut (simulateur de mise à jour temps réel Firestore) et observe
/// précisément quelle méthode/quel `targetStatus` a été appelé.
class _FakeMissionRepository implements MissionRepository {
  DeliveryMission mission;
  // Volontairement NON-broadcast (single-subscription) : un `.add()` appelé
  // avant tout `listen()` reste bufferisé et est délivré dès l'abonnement
  // du `StreamBuilder` — contrairement à un controller `.broadcast()`, où
  // un événement ajouté avant le premier listener est silencieusement
  // perdu, laissant le `StreamBuilder` bloqué en `ConnectionState.waiting`
  // (spinner indéterminé) pour toujours -> `pumpAndSettle` time out. Un
  // seul écouteur à la fois (le `StreamBuilder` de l'écran) : compatible
  // avec la contrainte single-subscription.
  final _controller = StreamController<DeliveryMission?>();

  int markPickupCompletedCallCount = 0;
  int updateTrackingStatusCallCount = 0;
  MissionStatus? lastTargetStatus;

  /// Si positionné, `updateTrackingStatus()` attend ce `Completer` avant de
  /// résoudre — permet de figer l'état "busy" (`_actionInProgress == true`)
  /// pour tester précisément le double-tap sans dépendre d'un timing
  /// asynchrone fragile (même pattern que
  /// `provider_jobs_tab_test.dart`/`pendingAcceptCompleter`).
  Completer<void>? pendingUpdateTrackingStatusCompleter;

  _FakeMissionRepository(this.mission) {
    _controller.add(mission);
  }

  /// Simule la mise à jour serveur reçue via le listener temps réel — fait
  /// avancer la mission au nouveau statut ET notifie le StreamBuilder,
  /// exactement comme le ferait un vrai `onSnapshot()` après que la Cloud
  /// Function a écrit le nouveau statut côté serveur.
  void advanceTo(MissionStatus status) {
    mission = _copyWithStatus(mission, status);
    _controller.add(mission);
  }

  void dispose() => _controller.close();

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => _controller.stream;

  @override
  Future<void> markPickupCompleted(String missionId) async {
    markPickupCompletedCallCount++;
    advanceTo(MissionStatus.pickedUp);
  }

  @override
  Future<void> updateTrackingStatus({
    required String missionId,
    required MissionStatus targetStatus,
  }) async {
    updateTrackingStatusCallCount++;
    lastTargetStatus = targetStatus;
    if (pendingUpdateTrackingStatusCompleter != null) {
      await pendingUpdateTrackingStatusCompleter!.future;
    }
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
    customerId: 'customer_test_gaps_001',
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

  testWidgets(
    'assigned : seul le bouton "partir vers le pickup" est visible ; tap -> updateTrackingStatus(driverToPickup)',
    (tester) async {
      final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.assigned));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final startButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_start_to_pickup'),
      );
      expect(startButton, findsOneWidget);
      // Aucune action d'une autre étape ne doit être visible simultanément.
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_arrived_at_pickup')),
        findsNothing,
      );
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_mark_pickup')),
        findsNothing,
      );

      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.lastTargetStatus, MissionStatus.driverToPickup);
      // La mission a avancé (rejouée par le fake) : le bouton correspondant
      // au NOUVEAU statut apparaît désormais, l'ancien a disparu.
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_arrived_at_pickup')),
        findsOneWidget,
      );
      expect(startButton, findsNothing);
    },
  );

  testWidgets(
    'driverToPickup : bouton "arrivé au pickup" ; tap -> updateTrackingStatus(arrivedAtPickup)',
    (tester) async {
      final fakeRepo =
          _FakeMissionRepository(_buildMission(status: MissionStatus.driverToPickup));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final arrivedButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_arrived_at_pickup'),
      );
      expect(arrivedButton, findsOneWidget);

      await tester.ensureVisible(arrivedButton);
      await tester.tap(arrivedButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.lastTargetStatus, MissionStatus.arrivedAtPickup);
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_mark_pickup')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'arrivedAtPickup : bouton "confirmer prise en charge" ; tap -> markPickupCompleted (jamais updateTrackingStatus)',
    (tester) async {
      final fakeRepo =
          _FakeMissionRepository(_buildMission(status: MissionStatus.arrivedAtPickup));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final markPickupButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_mark_pickup'),
      );
      expect(markPickupButton, findsOneWidget);

      await tester.ensureVisible(markPickupButton);
      await tester.tap(markPickupButton);
      await tester.pumpAndSettle();

      // RÈGLE CRITIQUE : la transition pickedUp passe par
      // `markPickupCompleted()` (impact financier / Cloud Function
      // dédiée), JAMAIS par `updateTrackingStatus()` — vérifie que
      // l'écran appelle la bonne méthode.
      expect(fakeRepo.markPickupCompletedCallCount, 1);
      expect(fakeRepo.updateTrackingStatusCallCount, 0);
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_start_transit')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'pickedUp : bouton "démarrer le trajet" ; tap -> updateTrackingStatus(inTransit)',
    (tester) async {
      final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.pickedUp));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final startTransitButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_start_transit'),
      );
      expect(startTransitButton, findsOneWidget);

      await tester.ensureVisible(startTransitButton);
      await tester.tap(startTransitButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.lastTargetStatus, MissionStatus.inTransit);
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_arrived_at_dropoff')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'inTransit : bouton "arrivé à destination" ; tap -> updateTrackingStatus(arrivedAtDropoff)',
    (tester) async {
      final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.inTransit));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final arrivedDropoffButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_arrived_at_dropoff'),
      );
      expect(arrivedDropoffButton, findsOneWidget);

      await tester.ensureVisible(arrivedDropoffButton);
      await tester.tap(arrivedDropoffButton);
      await tester.pumpAndSettle();

      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.lastTargetStatus, MissionStatus.arrivedAtDropoff);
      // Une fois à arrivedAtDropoff : SEUL le bouton de capture photo est
      // proposé — aucune action de trajet résiduelle (in_transit, etc.).
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_capture_photo')),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_arrived_at_dropoff')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'arrivedAtDropoff : aucune action de trajet résiduelle visible (seule la capture photo, couverte en détail ailleurs)',
    (tester) async {
      final fakeRepo =
          _FakeMissionRepository(_buildMission(status: MissionStatus.arrivedAtDropoff));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(ElevatedButton, btn('driver_active_mission_capture_photo')),
        findsOneWidget,
      );
      for (final leftoverKey in [
        'driver_active_mission_start_to_pickup',
        'driver_active_mission_arrived_at_pickup',
        'driver_active_mission_mark_pickup',
        'driver_active_mission_start_transit',
        'driver_active_mission_arrived_at_dropoff',
      ]) {
        expect(
          find.widgetWithText(ElevatedButton, btn(leftoverKey)),
          findsNothing,
          reason: 'Le bouton "$leftoverKey" ne doit pas être visible au statut arrivedAtDropoff',
        );
      }
    },
  );

  testWidgets(
    'completed : écran "déjà complétée" affiché, aucune action de trajet, aucun bouton de capture',
    (tester) async {
      final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.completed));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      expect(
        find.text(btn('driver_active_mission_already_completed')),
        findsOneWidget,
      );
      // Aucun bouton d'action de trajet ni de capture photo ne doit rester
      // affiché une fois la mission complétée.
      for (final leftoverKey in [
        'driver_active_mission_start_to_pickup',
        'driver_active_mission_arrived_at_pickup',
        'driver_active_mission_mark_pickup',
        'driver_active_mission_start_transit',
        'driver_active_mission_arrived_at_dropoff',
        'driver_active_mission_capture_photo',
      ]) {
        expect(
          find.widgetWithText(ElevatedButton, btn(leftoverKey)),
          findsNothing,
          reason: 'Le bouton "$leftoverKey" ne doit jamais apparaître une fois completed',
        );
      }
      // Seul le CTA générique de retour à la liste des jobs est présent.
      expect(
        find.widgetWithText(ElevatedButton, btn('driver_jobs_title')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'erreur GPS pendant le trajet (service désactivé) : bandeau affiché SANS bloquer les actions de trajet',
    (tester) async {
      fakeGeolocator.serviceEnabled = false;
      final fakeRepo =
          _FakeMissionRepository(_buildMission(status: MissionStatus.driverToPickup));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Bandeau d'avertissement GPS affiché (service désactivé).
      expect(
        find.text(btn('driver_active_mission_gps_disabled')),
        findsOneWidget,
      );

      // L'action de trajet correspondant au statut réel reste disponible :
      // une panne GPS ne doit jamais bloquer la progression manuelle de la
      // mission (le partage de position est une fonctionnalité annexe,
      // distincte de la state machine métier).
      final arrivedButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_arrived_at_pickup'),
      );
      expect(arrivedButton, findsOneWidget);
      final button = tester.widget<ElevatedButton>(arrivedButton);
      expect(button.onPressed, isNotNull);

      await tester.ensureVisible(arrivedButton);
      await tester.tap(arrivedButton);
      await tester.pumpAndSettle();
      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.lastTargetStatus, MissionStatus.arrivedAtPickup);
    },
  );

  testWidgets(
    'double-tap rapide sur une action de trajet ne déclenche updateTrackingStatus qu une seule fois (busy bloque le second tap)',
    (tester) async {
      final fakeRepo = _FakeMissionRepository(_buildMission(status: MissionStatus.pickedUp));
      BackendLocator.missionRepositoryOverride = fakeRepo;
      addTearDown(fakeRepo.dispose);

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Fige `updateTrackingStatus()` en cours d'exécution (busy) pour
      // pouvoir observer précisément l'état intermédiaire avant qu'il ne se
      // résolve — évite toute dépendance à un timing asynchrone fragile.
      fakeRepo.pendingUpdateTrackingStatusCompleter = Completer<void>();

      final startTransitButton = find.widgetWithText(
        ElevatedButton,
        btn('driver_active_mission_start_transit'),
      );
      expect(startTransitButton, findsOneWidget);

      await tester.ensureVisible(startTransitButton);
      await tester.tap(startTransitButton);
      await tester.pump(); // laisse `_runAction` positionner `busy = true`.

      // Le bouton est maintenant "busy" : son contenu textuel est remplacé
      // par un spinner (`button()` dans `_MissionCard._buildActions()`),
      // donc on le retrouve désormais par TYPE (unique sur l'écran) plutôt
      // que par le texte disparu. `onPressed` doit être `null`.
      final busyButtonFinder = find.byType(ElevatedButton);
      expect(busyButtonFinder, findsOneWidget);
      final busyButton = tester.widget<ElevatedButton>(busyButtonFinder);
      expect(busyButton.onPressed, isNull);

      // Second tap sur ce même bouton désactivé : ne doit rien déclencher.
      await tester.tap(busyButtonFinder, warnIfMissed: false);
      await tester.pump();

      expect(fakeRepo.updateTrackingStatusCallCount, 1);

      // Libère la première tentative pour terminer proprement le test.
      fakeRepo.pendingUpdateTrackingStatusCompleter!.complete();
      await tester.pumpAndSettle();
      expect(fakeRepo.updateTrackingStatusCallCount, 1);
    },
  );
}
