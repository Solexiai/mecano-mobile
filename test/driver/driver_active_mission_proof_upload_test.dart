// ---------------------------------------------------------------------------
// Test widget — DriverActiveMissionScreen : échec d'upload de la preuve de
// livraison (Phase 7, Bloc C — "proof upload failure").
//
// Couvre le cas explicitement demandé, jusqu'ici NON testé (grep exhaustif
// de `DriverActiveMissionScreen`/`proofUploadRepositoryOverride` dans
// test/ avant ce fichier : aucune occurrence) :
//
//   chauffeur arrive à destination (arrivedAtDropoff)
//   -> capture photo (ImagePicker simulé)
//   -> confirme la prévisualisation
//   -> tente l'upload -> ProofUploadRepository.uploadDeliveryProof() THROW
//   -> message d'erreur utilisateur propre affiché
//   -> mission NON marquée completed (reste arrivedAtDropoff)
//   -> MissionRepository.markDeliveryCompleted() JAMAIS appelé
//   -> aucune URL de preuve fictive n'est jamais transmise
//   -> retry possible (bouton "capturer photo" réapparaît, non bloqué)
//
// STRATÉGIE (réutilise l'architecture existante, ne la réécrit pas) :
//   - `BackendLocator.proofUploadRepositoryOverride` (seam créé dans ce
//     même bloc, cf. `proof_upload_repository.dart`) avec un fake qui
//     throw volontairement.
//   - `BackendLocator.missionRepositoryOverride` avec un fake qui compte
//     les appels à `markDeliveryCompleted` (doit rester à 0).
//   - `FirebaseAuthProvider(backendConfigured: false)` +
//     `debugForceSignedIn`/`debugForceUid` (pattern déjà établi dans
//     `delivery_request_flow_double_submit_test.dart`), combiné avec le
//     correctif Bloc C `effectiveUid` (au lieu de `user!.uid`) apporté à
//     `DriverActiveMissionScreen` pour rendre ce test possible sans mocker
//     tout `firebase_auth`.
//   - `ImagePickerPlatform.instance` : la capture caméra
//     (`ImagePicker().pickImage()`) délègue en interne à
//     `ImagePickerPlatform.instance.getImageFromSource()`
//     (`image_picker` 1.2.2, confirmé par lecture du package). On injecte
//     un `FakeImagePickerPlatform extends ImagePickerPlatform` — MÊME
//     PATTERN que `FakeGeolocatorPlatform extends GeolocatorPlatform` déjà
//     utilisé et validé dans `driver_location_reporter_test.dart`. Ce n'est
//     PAS un nouveau chantier architectural : c'est le mécanisme de test
//     officiel documenté par `image_picker_platform_interface` lui-même
//     (`PlatformInterface.verify`), pas un mock lourd de toute la
//     plateforme Firebase/Storage.
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/backend_exceptions.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/delivery_quote.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/proof_upload_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_active_mission_screen.dart';

const _driverId = 'driver_test_001';
const _missionId = 'mission_test_proof_upload';

/// Simule la capture caméra sans dépendre du vrai plugin natif —
/// `extends` (jamais `implements`) requis pour que `PlatformInterface.verify`
/// accepte l'instance (même contrainte documentée pour `GeolocatorPlatform`).
class FakeImagePickerPlatform extends ImagePickerPlatform {
  int pickImageCallCount = 0;

  // Un PNG 1x1 valide minimal — nécessaire car `_ProofPreviewDialog` passe
  // les bytes bruts à `Image.memory()` pour la prévisualisation réelle :
  // des octets arbitraires non-image feraient planter le décodeur Skia
  // (`Invalid image data`) et casseraient le test pour une raison sans
  // rapport avec le scénario testé (échec d'upload).
  Uint8List bytesToReturn = Uint8List.fromList(const [
    137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82,
    0, 0, 0, 1, 0, 0, 0, 1, 8, 4, 0, 0, 0, 181, 28, 12, 2, 0,
    0, 0, 11, 73, 68, 65, 84, 120, 218, 99, 100, 248, 15, 0, 1, 5,
    1, 1, 39, 24, 227, 102, 0, 0, 0, 0, 73, 69, 78, 68, 174, 66,
    96, 130,
  ]);

  @override
  Future<XFile?> getImageFromSource({
    required ImageSource source,
    ImagePickerOptions options = const ImagePickerOptions(),
  }) async {
    pickImageCallCount++;
    return XFile.fromData(bytesToReturn, name: 'proof.jpg', mimeType: 'image/jpeg');
  }
}

/// `ProofUploadRepository` fake — échoue systématiquement, comme un vrai
/// échec réseau/permission Storage/quota le ferait.
class _FailingProofUploadRepository implements ProofUploadRepository {
  int callCount = 0;

  @override
  Future<String> uploadDeliveryProof({
    required String missionId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    callCount++;
    throw Exception('Échec réseau Firebase Storage (simulation test)');
  }
}

/// `ProofUploadRepository` fake — succès, utilisé pour prouver que le
/// retry fonctionne réellement après un premier échec.
class _SucceedingProofUploadRepository implements ProofUploadRepository {
  int callCount = 0;

  @override
  Future<String> uploadDeliveryProof({
    required String missionId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    callCount++;
    return 'https://storage.example.com/delivery_proofs/$missionId/$fileName';
  }
}

/// `MissionRepository` fake minimal — sert uniquement à observer
/// `markDeliveryCompleted()` (doit rester à 0 après un échec d'upload) et à
/// fournir la mission via `watchMission()`.
class _FakeMissionRepository implements MissionRepository {
  int markDeliveryCompletedCallCount = 0;
  String? lastProofUrl;
  final DeliveryMission mission;

  _FakeMissionRepository(this.mission);

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => Stream.value(mission);

  @override
  Future<void> markDeliveryCompleted(String missionId, {required String proofOfDeliveryUrl}) async {
    markDeliveryCompletedCallCount++;
    lastProofUrl = proofOfDeliveryUrl;
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
  Future<void> markPickupCompleted(String missionId) async {}

  @override
  Future<void> updateTrackingStatus({required String missionId, required MissionStatus targetStatus}) async {}
}

DeliveryMission _buildMissionAtDropoff() {
  return DeliveryMission(
    id: _missionId,
    customerId: 'customer_test_001',
    itemCategoryKey: 'cat_furniture',
    description: 'Canapé 3 places',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: MissionStatus.arrivedAtDropoff,
    driverId: _driverId,
    pricingVersion: 'TEST-V1',
    createdAt: DateTime.now(),
    pickupAddress: const MissionAddress(
      line1: '123 rue Test',
      city: 'Montréal',
      postalCode: 'H2X1Y1',
      lat: 45.5,
      lng: -73.6,
    ),
    dropoffAddress: const MissionAddress(
      line1: '456 rue Cible',
      city: 'Laval',
      postalCode: 'H7X1Y1',
      lat: 45.6,
      lng: -73.7,
    ),
    driverOfferAmount: 80,
    customerTotal: 120,
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
  late FakeImagePickerPlatform fakeImagePicker;
  late _FakeMissionRepository fakeMissionRepo;
  late FirebaseAuthProvider auth;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeImagePicker = FakeImagePickerPlatform();
    ImagePickerPlatform.instance = fakeImagePicker;

    fakeMissionRepo = _FakeMissionRepository(_buildMissionAtDropoff());
    BackendLocator.missionRepositoryOverride = fakeMissionRepo;

    auth = FirebaseAuthProvider(backendConfigured: false);
    auth.debugForceSignedIn = true;
    auth.debugForceUid = _driverId;
    auth.debugForceDisplayName = 'Chauffeur Test';
  });

  tearDown(() {
    // CRITIQUE : toujours remettre les seams de test à `null`/valeur par
    // défaut pour ne jamais laisser un fake fuiter vers un autre test.
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.proofUploadRepositoryOverride = null;
  });

  Future<void> captureAndConfirmProof(WidgetTester tester) async {
    final captureButtonFinder = find.widgetWithText(
      ElevatedButton,
      AppStrings.t('driver_active_mission_capture_photo', 'fr'),
    );
    expect(captureButtonFinder, findsOneWidget);
    await tester.ensureVisible(captureButtonFinder);
    await tester.pumpAndSettle();
    await tester.tap(captureButtonFinder);
    await tester.pumpAndSettle();

    // Boîte de dialogue de prévisualisation : confirmation explicite avant
    // upload (jamais d'upload automatique).
    final confirmButtonFinder = find.widgetWithText(
      ElevatedButton,
      AppStrings.t('driver_active_mission_confirm_proof', 'fr'),
    );
    expect(confirmButtonFinder, findsOneWidget);
    await tester.tap(confirmButtonFinder);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'proof upload failure : échec upload -> erreur propre, mission NON completed, markDeliveryCompleted jamais appelé',
    (tester) async {
      final failingRepo = _FailingProofUploadRepository();
      BackendLocator.proofUploadRepositoryOverride = failingRepo;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      await captureAndConfirmProof(tester);

      // 1. Le fake picker a bien été sollicité (capture caméra simulée).
      expect(fakeImagePicker.pickImageCallCount, 1);

      // 2. L'upload a été tenté (le fake a bien throw).
      expect(failingRepo.callCount, 1);

      // 3. Message d'erreur utilisateur propre affiché (pas de crash, pas
      // de message générique trompeur).
      expect(
        find.text(AppStrings.t('driver_active_mission_proof_upload_error', 'fr')),
        findsOneWidget,
      );

      // 4. AUCUNE preuve fictive n'a jamais été transmise : la mission
      // n'est JAMAIS marquée completed côté repository.
      expect(fakeMissionRepo.markDeliveryCompletedCallCount, 0);
      expect(fakeMissionRepo.lastProofUrl, isNull);

      // 5. Aucune corruption d'état : la mission reste affichée dans son
      // statut réel (arrivedAtDropoff), pas de saut d'état côté UI. Le
      // bouton de capture photo est toujours présent (pas remplacé par un
      // état "completed" ou bloqué indéfiniment par le spinner d'upload).
      expect(
        find.text(AppStrings.t('driver_active_mission_already_completed', 'fr')),
        findsNothing,
      );
      expect(
        find.widgetWithText(
          ElevatedButton,
          AppStrings.t('driver_active_mission_capture_photo', 'fr'),
        ),
        findsOneWidget,
      );

      // 6. Le bouton n'est pas désactivé indéfiniment (uploadingProof est
      // bien retombé à false dans le `finally`) : retry possible.
      final retryButton = tester.widget<ElevatedButton>(
        find.widgetWithText(
          ElevatedButton,
          AppStrings.t('driver_active_mission_capture_photo', 'fr'),
        ),
      );
      expect(retryButton.onPressed, isNotNull);
    },
  );

  testWidgets(
    'proof upload failure : retry après échec réussit (nouvelle tentative avec repository fonctionnel)',
    (tester) async {
      final failingRepo = _FailingProofUploadRepository();
      BackendLocator.proofUploadRepositoryOverride = failingRepo;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Premier essai : échoue.
      await captureAndConfirmProof(tester);
      expect(fakeMissionRepo.markDeliveryCompletedCallCount, 0);
      expect(
        find.text(AppStrings.t('driver_active_mission_proof_upload_error', 'fr')),
        findsOneWidget,
      );

      // On simule la résolution du problème réseau : le repository
      // fonctionne maintenant (architecture prévue : le seam permet de
      // réessayer sans redémarrer l'app ni perdre l'état de la mission).
      final succeedingRepo = _SucceedingProofUploadRepository();
      BackendLocator.proofUploadRepositoryOverride = succeedingRepo;

      // Deuxième essai (retry) : doit maintenant appeler
      // markDeliveryCompleted avec une VRAIE url renvoyée par le
      // repository (jamais une url fictive construite côté client).
      await captureAndConfirmProof(tester);

      expect(succeedingRepo.callCount, 1);
      expect(fakeMissionRepo.markDeliveryCompletedCallCount, 1);
      expect(fakeMissionRepo.lastProofUrl, isNotNull);
      expect(
        fakeMissionRepo.lastProofUrl!.startsWith(
          'https://storage.example.com/delivery_proofs/$_missionId/',
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'proof upload failure : NotConfiguredProofUploadRepository (aucun seam positionné) échoue proprement sans faux succès',
    (tester) async {
      // Aucun override positionné : simule le cas où le backend Firebase
      // Storage n'est pas configuré (BackendBootstrap.status.isConfigured
      // == false, cas par défaut de ce projet à ce stade). Le comportement
      // attendu de `NotConfiguredProofUploadRepository` (créé dans ce même
      // bloc) est de throw `BackendNotConfiguredException` — jamais un
      // faux succès silencieux.
      expect(BackendLocator.proofUploadRepositoryOverride, isNull);
      expect(
        () => const NotConfiguredProofUploadRepository().uploadDeliveryProof(
          missionId: _missionId,
          fileName: 'x.jpg',
          bytes: const [1, 2, 3],
          contentType: 'image/jpeg',
        ),
        throwsA(isA<BackendNotConfiguredException>()),
      );
    },
  );
}
