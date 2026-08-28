// ---------------------------------------------------------------------------
// Test widget — ProviderJobsTab (Phase 7, Bloc C, item 3).
//
// Couvre :
//   - chauffeur admissible voit une mission disponible (watchAvailableMissionsForDriver)
//   - acceptation mission déclenchée (acceptMission appelé avec le bon
//     missionId/driverId)
//   - loading pendant la requête (bouton "en cours" + désactivé)
//   - erreur backend affichée proprement (result.success == false)
//   - mission déjà prise gérée proprement (errorCode 'delivery_already_assigned')
//   - aucune double acceptation UI (bouton désactivé pendant l'appel,
//     acceptMission jamais appelé deux fois pour un double-tap rapide)
//
// Seam utilisé : `BackendLocator.missionRepositoryOverride` (déjà existant,
// même pattern que `driver_active_mission_proof_upload_test.dart`) — aucun
// nouveau seam nécessaire ici (ProviderJobsTab n'utilise que
// MissionRepository, jamais DriverRepository).
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/delivery_quote.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_jobs_tab.dart';

const _driverId = 'driver_jobs_test_001';

DeliveryMission _buildAvailableMission({String id = 'mission_available_001'}) {
  return DeliveryMission(
    id: id,
    customerId: 'customer_jobs_001',
    itemCategoryKey: 'cat_furniture',
    description: 'Canapé 3 places',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: MissionStatus.searchingDriver,
    pricingVersion: 'TEST-V1',
    createdAt: DateTime.now(),
    pickupAddress: const MissionAddress(
      line1: '123 rue Test', city: 'Montréal', postalCode: 'H2X1Y1', lat: 45.5, lng: -73.6,
    ),
    dropoffAddress: const MissionAddress(
      line1: '456 rue Cible', city: 'Laval', postalCode: 'H7X1Y1', lat: 45.6, lng: -73.7,
    ),
    driverOfferAmount: 80,
    customerTotal: 120,
  );
}

/// Fake MissionRepository — seules les méthodes réellement exercées par
/// `ProviderJobsTab` ont un comportement instrumenté ; les autres lèvent
/// `UnimplementedError` (jamais appelées par cet écran).
class _FakeMissionRepository implements MissionRepository {
  List<DeliveryMission> availableMissions;
  int acceptMissionCallCount = 0;
  final List<String> acceptedMissionIds = [];
  final List<String> acceptedDriverIds = [];

  /// Si non-null, `acceptMission()` attend ce Completer avant de résoudre —
  /// permet de vérifier explicitement l'état "loading" pendant la requête.
  Completer<AcceptMissionResult>? pendingAcceptCompleter;

  /// Résultat renvoyé immédiatement si `pendingAcceptCompleter` est null.
  AcceptMissionResult nextAcceptResult = const AcceptMissionResult(success: true);

  _FakeMissionRepository(this.availableMissions);

  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId) =>
      Stream.value(availableMissions);

  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String driverId) => Stream.value(null);

  @override
  Future<AcceptMissionResult> acceptMission({
    required String missionId,
    required String driverId,
  }) async {
    acceptMissionCallCount++;
    acceptedMissionIds.add(missionId);
    acceptedDriverIds.add(driverId);
    if (pendingAcceptCompleter != null) {
      return pendingAcceptCompleter!.future;
    }
    return nextAcceptResult;
  }

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
  Stream<DeliveryMission?> watchMission(String missionId) => throw UnimplementedError();

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) =>
      throw UnimplementedError();

  @override
  Stream<List<DeliveryOffer>> watchOffersForDriver(String driverId) => throw UnimplementedError();

  @override
  Future<void> markPickupCompleted(String missionId) => throw UnimplementedError();

  @override
  Future<void> markDeliveryCompleted(String missionId, {required String proofOfDeliveryUrl}) =>
      throw UnimplementedError();

  @override
  Future<void> updateTrackingStatus({
    required String missionId,
    required MissionStatus targetStatus,
  }) =>
      throw UnimplementedError();
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/provider/jobs',
    routes: [
      GoRoute(path: '/fr/provider/jobs', builder: (context, state) => const Scaffold(body: ProviderJobsTab())),
      GoRoute(
        path: '/fr/provider/mission/:missionId',
        builder: (context, state) => const Scaffold(body: Text('MISSION_STUB')),
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
  late _FakeMissionRepository fakeRepo;
  late FirebaseAuthProvider auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeRepo = _FakeMissionRepository([_buildAvailableMission()]);
    BackendLocator.missionRepositoryOverride = fakeRepo;
    auth = FirebaseAuthProvider(backendConfigured: false);
    auth.debugForceSignedIn = true;
    auth.debugForceUid = _driverId;
    auth.debugForceDisplayName = 'Chauffeur Test';
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
  });

  testWidgets('chauffeur admissible voit la mission disponible avec son offre', (tester) async {
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.t('driver_jobs_title', 'fr')), findsOneWidget);
    expect(find.text('80\$'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')), findsOneWidget);
  });

  testWidgets('liste vide affiche driver_jobs_empty', (tester) async {
    fakeRepo.availableMissions = [];
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.t('driver_jobs_empty', 'fr')), findsOneWidget);
  });

  testWidgets(
    'acceptation réussie : acceptMission appelé avec missionId/driverId corrects puis navigation',
    (tester) async {
      fakeRepo.nextAcceptResult = const AcceptMissionResult(success: true);
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')));
      await tester.pumpAndSettle();

      expect(fakeRepo.acceptMissionCallCount, 1);
      expect(fakeRepo.acceptedMissionIds, ['mission_available_001']);
      expect(fakeRepo.acceptedDriverIds, [_driverId]);
      // Navigation réussie vers l'écran mission (stub).
      expect(find.text('MISSION_STUB'), findsOneWidget);
    },
  );

  testWidgets('loading pendant la requête : bouton désactivé et spinner affiché', (tester) async {
    fakeRepo.pendingAcceptCompleter = Completer<AcceptMissionResult>();
    await tester.pumpWidget(_buildTestApp(auth));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')));
    await tester.pump(); // un seul frame : la requête est encore "en vol"

    expect(find.text(AppStrings.t('driver_jobs_accepting', 'fr')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);

    // Nettoyage : résout la requête en attente pour ne pas laisser de Timer/
    // Future pendant après le test.
    fakeRepo.pendingAcceptCompleter!.complete(const AcceptMissionResult(success: true));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'aucune double acceptation UI : double-tap rapide ne déclenche acceptMission qu une seule fois',
    (tester) async {
      fakeRepo.pendingAcceptCompleter = Completer<AcceptMissionResult>();
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      final buttonFinder = find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr'));
      await tester.tap(buttonFinder);
      await tester.pump();
      // Deuxième tap immédiat : le bouton est déjà désactivé (onPressed:
      // null pendant `isAccepting`), donc `tester.tap()` ne déclenche rien
      // de plus — on le vérifie explicitement via le compteur.
      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accepting', 'fr')), warnIfMissed: false);
      await tester.pump();

      expect(fakeRepo.acceptMissionCallCount, 1);

      fakeRepo.pendingAcceptCompleter!.complete(const AcceptMissionResult(success: true));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'backend refusal (erreur inconnue) affiché proprement, sans navigation',
    (tester) async {
      fakeRepo.nextAcceptResult = const AcceptMissionResult(success: false, errorCode: 'unknown_error');
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.t('driver_jobs_accept_error', 'fr')), findsOneWidget);
      // Toujours sur l'écran des jobs, pas de navigation vers la mission.
      expect(find.text(AppStrings.t('driver_jobs_title', 'fr')), findsOneWidget);
      expect(find.text('MISSION_STUB'), findsNothing);
      // Le bouton redevient actif (retry possible), le chauffeur n'est pas bloqué.
      final button = tester.widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')),
      );
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'mission déjà prise (delivery_already_assigned) gérée proprement : erreur affichée, pas de crash',
    (tester) async {
      fakeRepo.nextAcceptResult =
          const AcceptMissionResult(success: false, errorCode: 'delivery_already_assigned');
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.t('driver_jobs_accept_error', 'fr')), findsOneWidget);
      expect(find.text('MISSION_STUB'), findsNothing);
    },
  );

  testWidgets(
    'exception réseau inattendue pendant acceptMission : catch générique, erreur affichée sans crash',
    (tester) async {
      // Remplace acceptMission par une variante qui lève directement, pour
      // exercer le bloc `catch (_)` de `_ProviderJobsTabState._accept()`.
      final throwingRepo = _ThrowingMissionRepository(fakeRepo);
      BackendLocator.missionRepositoryOverride = throwingRepo;
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, AppStrings.t('driver_jobs_accept', 'fr')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.t('driver_jobs_accept_error', 'fr')), findsOneWidget);
    },
  );

  // -------------------------------------------------------------------------
  // AB-8 — couverture manquante identifiée pendant la clôture Bloc AB :
  // `test/responsive/critical_screens_viewport_test.dart` (groupe J-1/J-2)
  // varie déjà la largeur de `ProviderDashboardShell` (320-600px), MAIS sans
  // jamais positionner `missionRepositoryOverride` avec une mission
  // disponible -> l'onglet "Demandes disponibles" y est TOUJOURS rendu dans
  // son état vide (`driver_jobs_empty`), jamais avec une VRAIE carte mission
  // + CTA "Accepter". Ce groupe comble ce GAP précis (premier job, carte
  // mission, CTA accept, texte long, petit écran, absence d'overflow) sans
  // dupliquer la couverture fonctionnelle déjà exhaustive ci-dessus.
  // -------------------------------------------------------------------------
  group('AB-8 — ProviderJobsTab, carte mission + CTA accept à petit viewport', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'AB-8 : première mission disponible (libellé catégorie long + adresses longues) — aucun overflow à ${width.toInt()}px, CTA Accepter visible',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);

          // Libellés délibérément longs (catégorie + adresses complètes +
          // description) pour reproduire les conditions exactes du sweep
          // mobile AB-8 (texte long sur petit écran).
          final longMission = DeliveryMission(
            id: 'mission_available_long_001',
            customerId: 'customer_jobs_002',
            itemCategoryKey: 'cat_building_materials',
            description:
                'Livraison de matériaux de construction volumineux nécessitant deux personnes pour le chargement',
            requiredVehicleCategory: VehicleCategory.cargoVan,
            status: MissionStatus.searchingDriver,
            pricingVersion: 'TEST-V1',
            createdAt: DateTime.now(),
            pickupAddress: const MissionAddress(
              line1: '4567 boulevard Henri-Bourassa Est, bureau 302',
              city: 'Montréal',
              postalCode: 'H2X1Y1',
              lat: 45.5,
              lng: -73.6,
            ),
            dropoffAddress: const MissionAddress(
              line1: '891 avenue du Parc-Industriel, quai de chargement 12',
              city: 'Laval',
              postalCode: 'H7X1Y1',
              lat: 45.6,
              lng: -73.7,
            ),
            distanceKm: 23.4,
            estimatedDurationMinutes: 42,
            driverOfferAmount: 95,
            customerTotal: 145,
          );
          fakeRepo.availableMissions = [longMission];

          await tester.pumpWidget(_buildTestApp(auth));
          await tester.pumpAndSettle();

          // Preuve que la VRAIE carte mission (pas l'état vide) est rendue.
          expect(
            find.widgetWithText(
              ElevatedButton,
              AppStrings.t('driver_jobs_accept', 'fr'),
            ),
            findsOneWidget,
          );
          expect(find.text('95\$'), findsOneWidget);

          // RÈGLE OVERFLOW : jamais masqué.
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}

/// Décore `_FakeMissionRepository` pour faire lever `acceptMission()` — sert
/// uniquement à exercer le bloc `catch (_)` (exception réseau/inattendue,
/// distincte du cas `result.success == false` renvoyé proprement).
class _ThrowingMissionRepository implements MissionRepository {
  final _FakeMissionRepository delegate;
  _ThrowingMissionRepository(this.delegate);

  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId) =>
      delegate.watchAvailableMissionsForDriver(driverId);

  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String driverId) =>
      delegate.watchActiveMissionForDriver(driverId);

  @override
  Future<AcceptMissionResult> acceptMission({required String missionId, required String driverId}) async {
    throw Exception('Erreur réseau simulée (test).');
  }

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
  Stream<DeliveryMission?> watchMission(String missionId) => throw UnimplementedError();

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) => throw UnimplementedError();

  @override
  Stream<List<DeliveryOffer>> watchOffersForDriver(String driverId) => throw UnimplementedError();

  @override
  Future<void> markPickupCompleted(String missionId) => throw UnimplementedError();

  @override
  Future<void> markDeliveryCompleted(String missionId, {required String proofOfDeliveryUrl}) =>
      throw UnimplementedError();

  @override
  Future<void> updateTrackingStatus({required String missionId, required MissionStatus targetStatus}) =>
      throw UnimplementedError();
}
