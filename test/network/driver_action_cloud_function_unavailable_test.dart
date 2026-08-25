// ---------------------------------------------------------------------------
// driver_action_cloud_function_unavailable_test.dart — Phase 7, Bloc G
// (gaps G-1 + G-2 : Cloud Function `unavailable` + retry idempotent).
//
// GAP réel confirmé par grep exhaustif de `test/` avant ce fichier : aucune
// occurrence de `CloudFunctionException(` n'était injectée dans un test —
// le code de `DriverActiveMissionScreen._runAction()` catche déjà
// `CloudFunctionException` (voir `driver_active_mission_screen.dart` ligne
// ~134 : `on CloudFunctionException { setState(() => _actionErrorKey =
// 'driver_active_mission_cf_error'); }`), mais ce chemin n'était jamais
// réellement exercé par un test.
//
// NE DUPLIQUE PAS :
//   - les transitions de statut elles-mêmes (déjà couvertes exhaustivement
//     par `driver_active_mission_status_gaps_test.dart`, 9/9 PASS) ;
//   - la garde de réentrance anti-double-tap UI (déjà couverte par
//     `delivery_request_flow_double_submit_test.dart`, MIS-C-09).
//
// SCÉNARIOS :
//   G-1 : tap "partir vers le pickup" -> Cloud Function renvoie
//         `CloudFunctionException('unavailable', ...)` -> aucun faux
//         succès (mission reste `assigned`), message d'erreur traduit
//         affiché, `_actionInProgress` nettoyé (bouton redevient
//         actionnable, spinner disparu), aucun crash.
//   G-2 : retry (2e tap sur le même bouton, même statut) -> cette fois le
//         fake repository réussit -> mission avance à `driverToPickup`
//         (une seule fois), message d'erreur effacé, aucune transition
//         dupliquée/sautée, `updateTrackingStatus` appelé exactement 2
//         fois au total (1 échec + 1 succès), jamais plus.
//
// STRATÉGIE (réutilise l'architecture existante, ne la réécrit pas) :
//   - `BackendLocator.missionRepositoryOverride` avec un
//     `_FlakyMissionRepository` qui échoue les N premiers appels à
//     `updateTrackingStatus()` (throw `CloudFunctionException`) puis
//     réussit, MÊME PATTERN de fake `StreamController` que
//     `driver_active_mission_status_gaps_test.dart`.
//   - `GeolocatorPlatform.instance = FakeGeolocatorPlatform` (mission
//     `assigned` -> `driverToPickup` n'est PAS un statut de partage GPS
//     dans `_kGpsSharingStatuses`, mais on le fixe par prudence/cohérence
//     avec les autres fichiers de ce bloc).
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

import 'package:movik_connect/backend/backend_exceptions.dart';
import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/delivery_quote.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_active_mission_screen.dart';

const _driverId = 'driver_test_cf_unavailable_001';
const _missionId = 'mission_test_cf_unavailable';

/// GPS toujours prêt — même pattern que les autres fichiers de test de ce
/// bloc, neutre pour ce scénario (statut `assigned`/`driverToPickup` n'est
/// pas dans `_kGpsSharingStatuses`).
class FakeGeolocatorPlatform extends GeolocatorPlatform {
  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => LocationPermission.always;

  @override
  Future<LocationPermission> requestPermission() async => LocationPermission.always;

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

/// `MissionRepository` fake — `updateTrackingStatus()` échoue avec
/// `CloudFunctionException('unavailable', ...)` pour les `failuresBeforeSuccess`
/// premiers appels, puis réussit normalement (fait avancer la mission et
/// notifie le `StreamBuilder`, comme le ferait un vrai listener Firestore
/// après succès réel côté serveur).
class _FlakyMissionRepository implements MissionRepository {
  DeliveryMission mission;
  final int failuresBeforeSuccess;
  final _controller = StreamController<DeliveryMission?>();

  int updateTrackingStatusCallCount = 0;
  int updateTrackingStatusFailureCount = 0;
  int updateTrackingStatusSuccessCount = 0;
  MissionStatus? lastTargetStatus;

  _FlakyMissionRepository(this.mission, {required this.failuresBeforeSuccess}) {
    _controller.add(mission);
  }

  void dispose() => _controller.close();

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => _controller.stream;

  @override
  Future<void> updateTrackingStatus({
    required String missionId,
    required MissionStatus targetStatus,
  }) async {
    updateTrackingStatusCallCount++;
    lastTargetStatus = targetStatus;
    if (updateTrackingStatusCallCount <= failuresBeforeSuccess) {
      updateTrackingStatusFailureCount++;
      throw const CloudFunctionException(
        'unavailable',
        'Le service est temporairement indisponible. Réessayez.',
      );
    }
    updateTrackingStatusSuccessCount++;
    mission = _copyWithStatus(mission, targetStatus);
    _controller.add(mission);
  }

  // ---- Méthodes non utilisées par ce parcours de test ----
  @override
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  }) =>
      throw UnimplementedError();

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
  Future<void> markPickupCompleted(String missionId) async {}

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
    pricingVersion: m.pricingVersion,
    createdAt: m.createdAt,
    driverOfferAmount: m.driverOfferAmount,
    customerTotal: m.customerTotal,
  );
}

DeliveryMission _buildAssignedMission() {
  return DeliveryMission(
    id: _missionId,
    customerId: 'customer_test_001',
    customerDisplayName: 'Client Test',
    itemCategoryKey: 'cat_furniture',
    description: 'Réfrigérateur',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: MissionStatus.assigned,
    driverId: _driverId,
    driverDisplayName: 'Chauffeur Test',
    pricingVersion: 'TEST-V1',
    createdAt: DateTime(2024, 1, 1),
    driverOfferAmount: 95,
    customerTotal: 140,
  );
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/fournisseur/mission/$_missionId',
    routes: [
      GoRoute(
        path: '/fr/fournisseur/mission/:missionId',
        builder: (context, state) => DriverActiveMissionScreen(
          missionId: state.pathParameters['missionId']!,
        ),
      ),
      GoRoute(
        path: '/fr/provider/dashboard',
        builder: (context, state) => const Scaffold(body: Text('dashboard')),
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

String _t(String key) => AppStrings.t(key, 'fr');

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GeolocatorPlatform.instance = FakeGeolocatorPlatform();
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
  });

  testWidgets(
    'G-1 : Cloud Function unavailable sur updateTrackingStatus -> aucun faux '
    'succès, message traduit affiché, bouton redevient actionnable, aucun crash',
    (tester) async {
      final fakeRepo = _FlakyMissionRepository(
        _buildAssignedMission(),
        failuresBeforeSuccess: 1,
      );
      BackendLocator.missionRepositoryOverride = fakeRepo;

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _driverId;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final startButtonFinder = find.widgetWithText(
        ElevatedButton,
        _t('driver_active_mission_start_to_pickup'),
      );
      expect(startButtonFinder, findsOneWidget);

      await tester.ensureVisible(startButtonFinder);
      await tester.tap(startButtonFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Aucun faux succès : la Cloud Function a échoué, la mission DOIT
      // rester au statut `assigned` (pas de transition fantôme).
      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.updateTrackingStatusFailureCount, 1);
      expect(fakeRepo.updateTrackingStatusSuccessCount, 0);
      expect(fakeRepo.mission.status, MissionStatus.assigned);

      // Message d'erreur traduit (clé existante, réutilisée telle quelle)
      // affiché à l'utilisateur.
      expect(find.text(_t('driver_active_mission_cf_error')), findsOneWidget);

      // Le bouton "partir vers le pickup" est toujours présent ET de
      // nouveau actionnable (onPressed non-null) : `_actionInProgress` a
      // bien été nettoyé dans le bloc `finally` de `_runAction()`.
      final buttonAfterFailure = tester.widget<ElevatedButton>(startButtonFinder);
      expect(buttonAfterFailure.onPressed, isNotNull);

      // Aucun spinner résiduel affiché sur le bouton (preuve visuelle
      // supplémentaire que `busy` est bien retombé à `false`).
      expect(
        find.descendant(
          of: startButtonFinder,
          matching: find.byType(CircularProgressIndicator),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'G-2 : retry après échec CF unavailable -> succès, une seule transition '
    'effectuée au total, aucune duplication, message d\'erreur effacé',
    (tester) async {
      final fakeRepo = _FlakyMissionRepository(
        _buildAssignedMission(),
        failuresBeforeSuccess: 1,
      );
      BackendLocator.missionRepositoryOverride = fakeRepo;

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _driverId;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final startButtonFinder = find.widgetWithText(
        ElevatedButton,
        _t('driver_active_mission_start_to_pickup'),
      );

      // Premier tap : échoue (CF unavailable), cf. G-1.
      await tester.ensureVisible(startButtonFinder);
      await tester.tap(startButtonFinder);
      await tester.pumpAndSettle();
      expect(fakeRepo.updateTrackingStatusCallCount, 1);
      expect(fakeRepo.mission.status, MissionStatus.assigned);
      expect(find.text(_t('driver_active_mission_cf_error')), findsOneWidget);

      // Retry : deuxième tap sur le MÊME bouton (mission toujours
      // `assigned`, donc toujours le même bouton "partir vers le pickup" —
      // pas un bouton différent, preuve que l'écran n'a pas avancé à tort).
      await tester.ensureVisible(startButtonFinder);
      await tester.tap(startButtonFinder);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Exactement 2 appels au total (1 échec + 1 succès) : ni plus (pas de
      // duplication), ni moins (le retry a réellement redéclenché l'appel).
      expect(fakeRepo.updateTrackingStatusCallCount, 2);
      expect(fakeRepo.updateTrackingStatusFailureCount, 1);
      expect(fakeRepo.updateTrackingStatusSuccessCount, 1);
      expect(fakeRepo.lastTargetStatus, MissionStatus.driverToPickup);

      // La mission a bien avancé UNE SEULE FOIS au nouveau statut attendu
      // (pas de saut de statut, pas de double avancement).
      expect(fakeRepo.mission.status, MissionStatus.driverToPickup);

      // Le message d'erreur a été effacé après le succès du retry.
      expect(find.text(_t('driver_active_mission_cf_error')), findsNothing);

      // L'écran affiche désormais l'action du NOUVEAU statut
      // (`driverToPickup` -> "arrivé au pickup"), preuve supplémentaire
      // d'une transition réelle et unique.
      expect(
        find.widgetWithText(
          ElevatedButton,
          _t('driver_active_mission_arrived_at_pickup'),
        ),
        findsOneWidget,
      );
      expect(
        find.widgetWithText(
          ElevatedButton,
          _t('driver_active_mission_start_to_pickup'),
        ),
        findsNothing,
      );
    },
  );
}
