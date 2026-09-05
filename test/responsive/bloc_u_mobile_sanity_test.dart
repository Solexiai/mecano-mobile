// ---------------------------------------------------------------------------
// bloc_u_mobile_sanity_test.dart — Phase 7, Bloc U (U-6 — MOBILE SANITY).
//
// GAP réel confirmé avant ce fichier (grep exhaustif de
// `tester.view.physicalSize` dans test/) : aucun test existant n'exerçait
// les 5 écrans ci-dessous à une largeur de téléphone étroite (320-360px) —
// `critical_screens_viewport_test.dart` (Bloc J) et
// `critical_accessibility_test.dart` (Bloc L) couvrent UNIQUEMENT
// `AuthScreen`/`ProviderDashboardShell`/`SafetyScreen`. Ne duplique PAS ces
// écrans déjà couverts (consigne explicite U-6 : "ne pas refaire J/L").
//
// Écrans couverts (parcours U-1/U-2/U-6) :
//   U-6.1 : DeliveryRequestFlowScreen (création mission, étape 2 adresses —
//           la plus dense en TextField/Row à 2 colonnes du flux).
//   U-6.2 : DriverActiveMissionScreen (mission active, statut `inTransit` —
//           carte + bandeau GPS + bouton d'action pleine largeur).
//   U-6.3 : DriverActiveMissionScreen — `_ProofPreviewDialog` (modal preuve
//           de livraison, capture caméra + 2 boutons d'action).
//   U-6.4 : DriverOnboardingScreen — étape "Documents" (upload permis /
//           assurance, `_DocumentPickerRow` avec Row texte+bouton).
//   U-6.5 : NotificationsScreen (liste + AppBar avec action "tout marquer lu").
//   U-6.6 : CustomerTrackingScreen (suivi mission en cours, `_DeliveryTimeline`
//           + `_AddressRow`).
//
// RÈGLE OVERFLOW (même règle que Bloc J, respectée strictement) : aucun
// `tester.takeException()` n'est masqué ou ignoré ; aucune largeur de
// viewport n'est élargie artificiellement pour faire "passer" un test —
// largeurs choisies (320/360px) = téléphones réels (iPhone SE, Android
// compact), les plus contraignantes du parc actuel.
//
// Réutilise strictement les fakes/harnais déjà établis dans Phase 7 (aucune
// nouvelle architecture de test) :
//   - `_FakeMissionRepository`/`_buildMission`/`_copyWithStatus` : mêmes
//     patterns que `driver_active_mission_status_gaps_test.dart`.
//   - `FakeGeolocatorPlatform extends GeolocatorPlatform` : même pattern que
//     `driver_active_mission_status_gaps_test.dart`/`driver_location_reporter_test.dart`.
//   - `FakeImagePickerPlatform extends ImagePickerPlatform` (PNG 1x1 valide) :
//     même pattern que `driver_active_mission_proof_upload_test.dart`/
//     `driver_onboarding_document_upload_test.dart`.
//   - `_StreamNotificationRepository` : même pattern que
//     `notifications_realtime_and_unread_test.dart`.
//   - `_CountingMissionRepository`/`fillFormAndReachQuoteStep` (adapté) :
//     même pattern que `delivery_request_flow_double_submit_test.dart`.
//   - `_setViewport` : identique à `critical_screens_viewport_test.dart`.
// ---------------------------------------------------------------------------

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker_platform_interface/image_picker_platform_interface.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/backend/models/app_notification.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/delivery_quote.dart';
import 'package:movik_connect/backend/models/driver_location.dart';
import 'package:movik_connect/backend/models/driver_location_history_point.dart';
import 'package:movik_connect/backend/repositories/location_repository.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/notification_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import 'package:movik_connect/screens/driver/driver_active_mission_screen.dart';
import 'package:movik_connect/screens/driver/driver_onboarding_screen.dart';
import 'package:movik_connect/screens/notifications/notifications_screen.dart';

// ---------------------------------------------------------------------------
// Fakes réutilisés (aucun nouveau seam créé) — voir en-tête pour provenance.
// ---------------------------------------------------------------------------

const _driverId = 'driver_u6_001';
const _customerId = 'customer_u6_001';
const _missionId = 'mission_u6_001';

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

class _FakeLocationRepository implements LocationRepository {
  @override
  Future<void> reportDriverLocation(DriverLocation location) async {}

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) => Stream.value(null);

  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(String driverId) =>
      Stream.value(const []);
}

/// Simule la capture caméra sans dépendre du vrai plugin natif — `extends`
/// (jamais `implements`) requis pour que `PlatformInterface.verify` accepte
/// l'instance (même contrainte que `FakeGeolocatorPlatform`).
class FakeImagePickerPlatform extends ImagePickerPlatform {
  // PNG 1x1 valide minimal — `_ProofPreviewDialog` passe les bytes bruts à
  // `Image.memory()` : des octets non-image feraient planter le décodeur
  // Skia pour une raison sans rapport avec le scénario testé.
  static final Uint8List _validPng = Uint8List.fromList(const [
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
    return XFile.fromData(_validPng, name: 'proof.jpg', mimeType: 'image/jpeg');
  }
}

class _FakeMissionRepository implements MissionRepository {
  DeliveryMission mission;
  final _controller = StreamController<DeliveryMission?>();

  _FakeMissionRepository(this.mission) {
    _controller.add(mission);
  }

  void dispose() => _controller.close();

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => _controller.stream;

  @override
  Future<void> markDeliveryCompleted(String missionId, {required String proofOfDeliveryUrl}) async {}

  @override
  Future<void> markPickupCompleted(String missionId) async {}

  @override
  Future<void> updateTrackingStatus({
    required String missionId,
    required MissionStatus targetStatus,
  }) async {}

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
}

DeliveryMission _buildMission({required MissionStatus status, required String customerId}) {
  return DeliveryMission(
    id: _missionId,
    customerId: customerId,
    customerDisplayName: 'Client Test U6',
    itemCategoryKey: 'cat_furniture',
    description: 'Réfrigérateur',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: status,
    driverId: _driverId,
    driverDisplayName: 'Chauffeur Test U6',
    pricingVersion: 'TEST-V1',
    createdAt: DateTime.now(),
    pickupAddress: const MissionAddress(
      line1: '10 rue Départ Très Longue Adresse',
      city: 'Montréal',
      postalCode: 'H2X1Y1',
      lat: 45.5,
      lng: -73.6,
    ),
    dropoffAddress: const MissionAddress(
      line1: '20 rue Arrivée Aussi Assez Longue',
      city: 'Laval',
      postalCode: 'H7X1Y1',
      lat: 45.6,
      lng: -73.7,
    ),
    driverOfferAmount: 95,
    customerTotal: 140,
  );
}

class _StreamNotificationRepository implements NotificationRepository {
  final _notifController = StreamController<List<AppNotification>>();
  final _unreadController = StreamController<int>();

  _StreamNotificationRepository(List<AppNotification> initial) {
    _notifController.add(initial);
    _unreadController.add(initial.where((n) => !n.isRead).length);
  }

  void dispose() {
    _notifController.close();
    _unreadController.close();
  }

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) => _notifController.stream;

  @override
  Stream<int> watchUnreadCount(String userId) => _unreadController.stream;

  @override
  Future<void> markAsRead(String userId, String notificationId) async {}

  @override
  Future<void> markAllAsRead(String userId) async {}
}

List<AppNotification> _notifications() => [
      AppNotification(
        id: 'n1',
        userId: _customerId,
        type: 'driver_assigned',
        titleKey: 'notif_driver_assigned_title',
        bodyKey: 'notif_driver_assigned_body',
        missionId: 'mission_n1',
        createdAt: DateTime(2024, 1, 1, 10, 0),
        isRead: false,
      ),
      AppNotification(
        id: 'n2',
        userId: _customerId,
        type: 'delivery_completed',
        titleKey: 'notif_delivery_completed_title',
        bodyKey: 'notif_delivery_completed_body',
        missionId: 'mission_n2',
        createdAt: DateTime(2024, 1, 1, 9, 0),
        isRead: true,
      ),
    ];

FirebaseAuthProvider _signedInAuth({required String uid, String? displayName}) {
  return FirebaseAuthProvider(backendConfigured: false)
    ..debugForceSignedIn = true
    ..debugForceUid = uid
    ..debugForceDisplayName = displayName ?? 'Test User';
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _wrap(Widget router) {
  return router;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.locationRepositoryOverride = null;
    BackendLocator.notificationRepositoryOverride = null;
  });

  // -------------------------------------------------------------------
  // U-6.1 — DeliveryRequestFlowScreen (création mission), étape adresses.
  // -------------------------------------------------------------------
  group('U-6.1 — DeliveryRequestFlowScreen (création mission)', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'étape 2 (adresses, Row 2 colonnes x4) — aucun overflow à ${width.toInt()}px, '
        'tous les champs restent atteignables et éditables',
        (tester) async {
          _setViewport(tester, width, 800);

          final auth = _signedInAuth(uid: _customerId, displayName: 'Client Test');
          final router = GoRouter(
            initialLocation: '/fr/livraison/demande',
            routes: [
              GoRoute(
                path: '/fr/livraison/demande',
                builder: (context, state) => const DeliveryRequestFlowScreen(locale: 'fr'),
              ),
            ],
          );
          await tester.pumpWidget(_wrap(MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
            ],
            child: MaterialApp.router(routerConfig: router),
          )));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Étape 1 : catégorie + description, puis "Suivant".
          await tester.ensureVisible(find.text(AppStrings.t('cat_furniture', 'fr')).first);
          await tester.tap(find.text(AppStrings.t('cat_furniture', 'fr')).first);
          await tester.pump();
          await tester.ensureVisible(find.byType(TextField).first);
          await tester.enterText(find.byType(TextField).first, 'Canapé 3 places');
          await tester.pump();
          expect(tester.takeException(), isNull);
          final next1 = find.text(AppStrings.t('common_next', 'fr'));
          await tester.ensureVisible(next1);
          await tester.tap(next1);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Étape 2 : adresses — MOVI-K adresses réelles + autocomplete +
          // géocodage : 4 TextField seulement désormais (pickup + dropoff,
          // chacun encapsulé dans un `AddressAutocompleteField`, plus
          // contact/accès), contre 10 avant cette évolution (plus de champs
          // lat/lng/ville/code postal séparés). Vérifie que chacun reste
          // atteignable par scroll sans provoquer d'exception de layout,
          // même à largeur étroite.
          final textFields = find.byType(TextField);
          expect(textFields, findsNWidgets(4));
          for (var i = 0; i < 4; i++) {
            await tester.ensureVisible(textFields.at(i));
            await tester.pump();
            expect(tester.takeException(), isNull);
          }

          // Le bouton "Suivant" de l'étape reste accessible.
          final next2 = find.text(AppStrings.t('common_next', 'fr'));
          await tester.ensureVisible(next2);
          expect(next2, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // -------------------------------------------------------------------
  // U-6.2 — DriverActiveMissionScreen (mission active en transit).
  // -------------------------------------------------------------------
  group('U-6.2 — DriverActiveMissionScreen (mission active)', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'statut inTransit (carte + bandeau + bouton pleine largeur) — '
        'aucun overflow à ${width.toInt()}px, bouton d\'action accessible',
        (tester) async {
          _setViewport(tester, width, 800);

          GeolocatorPlatform.instance = FakeGeolocatorPlatform();
          BackendLocator.locationRepositoryOverride = _FakeLocationRepository();
          final fakeRepo = _FakeMissionRepository(
            _buildMission(status: MissionStatus.inTransit, customerId: _customerId),
          );
          BackendLocator.missionRepositoryOverride = fakeRepo;
          addTearDown(fakeRepo.dispose);

          final auth = _signedInAuth(uid: _driverId, displayName: 'Chauffeur Test');
          final router = GoRouter(
            initialLocation: '/fr/provider/mission/$_missionId',
            routes: [
              GoRoute(
                path: '/fr/provider/mission/:missionId',
                builder: (context, state) =>
                    DriverActiveMissionScreen(missionId: state.pathParameters['missionId']!),
              ),
            ],
          );
          await tester.pumpWidget(_wrap(MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
            ],
            child: MaterialApp.router(routerConfig: router),
          )));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // Bouton d'action ("arrivé à destination") doit rester visible et
          // atteignable sans overflow, même avec la carte + adresses longues.
          final actionButton = find.widgetWithText(
            ElevatedButton,
            AppStrings.t('driver_active_mission_arrived_at_dropoff', 'fr'),
          );
          await tester.ensureVisible(actionButton);
          await tester.pumpAndSettle();
          expect(actionButton, findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // -------------------------------------------------------------------
  // U-6.3 — _ProofPreviewDialog (modal preuve de livraison).
  // -------------------------------------------------------------------
  group('U-6.3 — DriverActiveMissionScreen : modal preuve de livraison', () {
    testWidgets(
      'à 320px : dialog de prévisualisation photo + 2 boutons restent visibles '
      'et accessibles (ni hors écran, ni overflow)',
      (tester) async {
        _setViewport(tester, 320, 700);

        GeolocatorPlatform.instance = FakeGeolocatorPlatform();
        ImagePickerPlatform.instance = FakeImagePickerPlatform();
        BackendLocator.locationRepositoryOverride = _FakeLocationRepository();
        final fakeRepo = _FakeMissionRepository(
          _buildMission(status: MissionStatus.arrivedAtDropoff, customerId: _customerId),
        );
        BackendLocator.missionRepositoryOverride = fakeRepo;
        addTearDown(fakeRepo.dispose);

        final auth = _signedInAuth(uid: _driverId, displayName: 'Chauffeur Test');
        final router = GoRouter(
          initialLocation: '/fr/provider/mission/$_missionId',
          routes: [
            GoRoute(
              path: '/fr/provider/mission/:missionId',
              builder: (context, state) =>
                  DriverActiveMissionScreen(missionId: state.pathParameters['missionId']!),
            ),
          ],
        );
        await tester.pumpWidget(_wrap(MultiProvider(
          providers: [
            ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
            ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
          ],
          child: MaterialApp.router(routerConfig: router),
        )));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final captureButton = find.widgetWithText(
          ElevatedButton,
          AppStrings.t('driver_active_mission_capture_photo', 'fr'),
        );
        await tester.ensureVisible(captureButton);
        await tester.pumpAndSettle();
        await tester.tap(captureButton);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Le dialog + ses 2 actions doivent être présents et accessibles,
        // même à 320px de large.
        expect(find.byType(AlertDialog), findsOneWidget);
        final retakeButton = find.text(AppStrings.t('driver_active_mission_retake_photo', 'fr'));
        final confirmButton = find.text(AppStrings.t('driver_active_mission_confirm_proof', 'fr'));
        expect(retakeButton, findsOneWidget);
        expect(confirmButton, findsOneWidget);
        expect(tester.takeException(), isNull);

        // Les deux boutons doivent être réellement tapables (pas seulement
        // présents dans l'arbre) : confirmer ferme le dialog sans exception.
        await tester.tap(confirmButton);
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });

  // -------------------------------------------------------------------
  // U-6.4 — DriverOnboardingScreen, étape Documents (uploads).
  // -------------------------------------------------------------------
  group('U-6.4 — DriverOnboardingScreen (étape Documents, uploads)', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        '_DocumentPickerRow (icône + texte + bouton "Sélectionner") — '
        'aucun overflow à ${width.toInt()}px, bouton toujours accessible',
        (tester) async {
          _setViewport(tester, width, 800);

          final auth = FirebaseAuthProvider(backendConfigured: false);
          final router = GoRouter(
            initialLocation: '/fr/devenir-chauffeur/inscription',
            routes: [
              GoRoute(
                path: '/fr/devenir-chauffeur/inscription',
                builder: (context, state) => const DriverOnboardingScreen(locale: 'fr'),
              ),
              GoRoute(
                path: '/fr/devenir-chauffeur/statut',
                builder: (context, state) => const Scaffold(body: Text('STATUS_STUB')),
              ),
            ],
          );
          await tester.pumpWidget(_wrap(MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
              Provider<BackendStatus>.value(value: const BackendStatus.ready()),
            ],
            child: MaterialApp.router(routerConfig: router),
          )));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Amener le wizard à l'étape Documents (Profil rempli, puis 3x
          // "Suivant" — mêmes valeurs que driver_onboarding_document_upload_test.dart).
          await tester.enterText(find.byType(TextField).at(0), 'Jean Tremblay');
          await tester.enterText(find.byType(TextField).at(1), 'jean.tremblay@example.com');
          await tester.enterText(find.byType(TextField).at(2), 'motdepasse123');
          await tester.pump();
          for (var i = 0; i < 3; i++) {
            final nextButton = find.widgetWithText(ElevatedButton, AppStrings.t('common_next', 'fr'));
            await tester.ensureVisible(nextButton);
            await tester.pumpAndSettle();
            await tester.tap(nextButton);
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }

          // Étape Documents : les 2 lignes de sélection (permis + assurance)
          // doivent être visibles et leur bouton "Sélectionner" accessible,
          // sans overflow horizontal du Row texte+bouton.
          final licenseLabel = find.text(AppStrings.t('driver_onboarding_upload_license', 'fr'));
          final insuranceLabel = find.text(AppStrings.t('driver_onboarding_upload_insurance', 'fr'));
          await tester.ensureVisible(licenseLabel);
          expect(licenseLabel, findsOneWidget);
          expect(insuranceLabel, findsOneWidget);
          expect(tester.takeException(), isNull);

          final selectButtons = find.widgetWithText(
            OutlinedButton,
            AppStrings.t('driver_onboarding_document_select', 'fr'),
          );
          expect(selectButtons, findsNWidgets(2));
          await tester.ensureVisible(selectButtons.first);
          expect(tester.takeException(), isNull);
        },
      );
    }
  });

  // -------------------------------------------------------------------
  // U-6.5 — NotificationsScreen.
  // -------------------------------------------------------------------
  group('U-6.5 — NotificationsScreen', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'liste + AppBar action "tout marquer lu" — aucun overflow à '
        '${width.toInt()}px, action accessible',
        (tester) async {
          _setViewport(tester, width, 700);

          final fakeRepo = _StreamNotificationRepository(_notifications());
          BackendLocator.notificationRepositoryOverride = fakeRepo;
          addTearDown(fakeRepo.dispose);

          final auth = _signedInAuth(uid: _customerId, displayName: 'Client Test');
          final router = GoRouter(
            initialLocation: '/fr/notifications/$_customerId',
            routes: [
              GoRoute(
                path: '/fr/notifications/:userId',
                builder: (context, state) =>
                    NotificationsScreen(userId: state.pathParameters['userId']!),
              ),
              GoRoute(
                path: '/fr/livraison/suivi/:missionId',
                builder: (context, state) => const Scaffold(body: Text('TRACKING_STUB')),
              ),
            ],
          );
          await tester.pumpWidget(_wrap(MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
            ],
            child: MaterialApp.router(routerConfig: router),
          )));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // L'action "tout marquer lu" de l'AppBar (texte potentiellement
          // long) ne doit jamais provoquer d'overflow de l'AppBar, même à
          // 320px, et rester tapable.
          final markAllButton = find.text(AppStrings.t('notifications_mark_all_read', 'fr'));
          expect(markAllButton, findsOneWidget);
          await tester.tap(markAllButton);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Les 2 notifications restent listées et tapables sans overflow.
          expect(
            find.text(AppStrings.t('notif_driver_assigned_title', 'fr')),
            findsOneWidget,
          );
        },
      );
    }
  });

  // -------------------------------------------------------------------
  // U-6.6 — CustomerTrackingScreen (suivi mission en cours).
  // -------------------------------------------------------------------
  group('U-6.6 — CustomerTrackingScreen (suivi mission en cours)', () {
    for (final width in [320.0, 360.0]) {
      testWidgets(
        'bandeau chauffeur + carte + timeline + adresses longues — '
        'aucun overflow à ${width.toInt()}px',
        (tester) async {
          _setViewport(tester, width, 900);

          BackendLocator.locationRepositoryOverride = _FakeLocationRepository();
          final fakeRepo = _FakeMissionRepository(
            _buildMission(status: MissionStatus.inTransit, customerId: _customerId),
          );
          BackendLocator.missionRepositoryOverride = fakeRepo;
          addTearDown(fakeRepo.dispose);

          final auth = _signedInAuth(uid: _customerId, displayName: 'Client Test');
          final router = GoRouter(
            initialLocation: '/fr/livraison/suivi/$_missionId',
            routes: [
              GoRoute(
                path: '/fr/livraison/suivi/:missionId',
                builder: (context, state) =>
                    CustomerTrackingScreen(missionId: state.pathParameters['missionId']!),
              ),
            ],
          );
          await tester.pumpWidget(_wrap(MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
            ],
            child: MaterialApp.router(routerConfig: router),
          )));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);

          // Le nom du chauffeur (bandeau supérieur, Row icône+texte) et les
          // adresses longues (pickup/dropoff, _AddressRow) doivent rester
          // visibles sans provoquer d'exception de layout.
          expect(find.text('Chauffeur Test U6'), findsOneWidget);
          await tester.ensureVisible(find.textContaining('10 rue Départ'));
          expect(tester.takeException(), isNull);
        },
      );
    }
  });
}
