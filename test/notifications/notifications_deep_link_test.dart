// ---------------------------------------------------------------------------
// notifications_deep_link_test.dart — Phase 7, Bloc F (gap F-3).
//
// Couvre le deep-link navigation-on-tap de `NotificationsScreen` : tap sur
// une notification -> `markAsRead` -> `context.go(...)` vers la mission
// liée, avec branchement client/chauffeur selon `auth.hasRole(PlatformRole.driver)`.
//
// NE RÉAUDITE PAS et NE DUPLIQUE PAS :
//   - la protection F-1 (`mission.customerId != auth.effectiveUid`) dans
//     `CustomerTrackingScreen` — déjà prouvée par
//     `customer_tracking_cross_customer_test.dart` (3/3 verts). Ce fichier
//     se contente de vérifier qu'elle est bien atteinte/déclenchée DEPUIS le
//     tap d'une notification, pas de re-tester le contenu du refus lui-même.
//   - la protection symétrique (`mission.driverId != uid`) dans
//     `DriverActiveMissionScreen` — déjà documentée et couverte
//     indirectement par `driver_active_mission_status_gaps_test.dart` (le
//     comportement `mission == null` -> "introuvable" y est déjà exercé).
//     Idem : on prouve seulement qu'elle est bien atteinte via le deep-link
//     notification, pas re-testée en détail.
//
// SCÉNARIOS (énoncé exact du Bloc F, gap F-3) :
//   F-3.1 : notification client valide -> markAsRead -> navigation
//           /fr/livraison/suivi/X -> CustomerTrackingScreen reçoit X.
//   F-3.2 : notification pointe vers une mission supprimée/inexistante ->
//           navigation -> mission introuvable -> fallback existant réutilisé
//           (aucune nouvelle logique métier créée).
//   F-3.3 : notification pointe vers une mission d'un AUTRE utilisateur,
//           testé côté client (réutilise F-1) ET côté chauffeur (réutilise
//           la protection existante de DriverActiveMissionScreen).
//   Cas nominal chauffeur : prouve que le branchement client/chauffeur de
//           `NotificationsScreen` fonctionne réellement (route
//           `/fournisseur/mission/:id`, pas `/livraison/suivi/:id`).
//   missionId null/empty : skip silencieux actuel — aucune régression sans
//           bug démontré.
//
// STRATÉGIE (réutilise l'architecture existante, ne la réécrit pas) :
//   - `BackendLocator.notificationRepositoryOverride` (seam ajouté dans ce
//     même tour, cf. `backend_locator.dart`) avec un fake minimal
//     implémentant les 4 méthodes de `NotificationRepository`.
//   - `BackendLocator.missionRepositoryOverride` (seam préexistant) avec un
//     fake `noSuchMethod`-based ne supportant que `watchMission()`, comme
//     dans `customer_tracking_cross_customer_test.dart`.
//   - `FirebaseAuthProvider(backendConfigured: false)` +
//     `debugForceSignedIn`/`debugForceUid`/`debugForceRoles` (pattern déjà
//     établi partout ailleurs dans Bloc B/C/E/F).
//   - `GeolocatorPlatform.instance = FakeGeolocatorPlatform` (même pattern
//     que `driver_active_mission_status_gaps_test.dart`) pour les scénarios
//     qui atterrissent sur `DriverActiveMissionScreen` (celui-ci démarre le
//     partage GPS dès qu'une mission est dans un statut de trajet actif —
//     sans ce fake, `Geolocator.isLocationServiceEnabled()` lèverait une
//     `MissingPluginException` non interceptée dans ce contexte de test).
//   - Un routeur `GoRouter` minimal ne déclarant QUE les 3 routes
//     nécessaires (`/fr/notifications`, `/fr/livraison/suivi/:missionId`,
//     `/fr/fournisseur/mission/:missionId`) — jamais l'arbre complet
//     `main.dart`/Hive.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator_platform_interface/geolocator_platform_interface.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/app_notification.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/notification_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';
import 'package:movik_connect/screens/driver/driver_active_mission_screen.dart';
import 'package:movik_connect/screens/notifications/notifications_screen.dart';

/// GPS toujours prêt (service activé, permission accordée) — évite tout
/// bandeau/erreur GPS non désiré et toute `MissingPluginException` lorsque
/// `DriverActiveMissionScreen` démarre `DriverLocationReporter` au premier
/// build d'une mission en statut de trajet actif. Même pattern que
/// `driver_active_mission_status_gaps_test.dart`.
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

/// Fake `NotificationRepository` — liste déterministe injectée via
/// `BackendLocator.notificationRepositoryOverride`. Observe précisément les
/// appels à `markAsRead`/`markAllAsRead` sans dépendre de Firebase.
class _FakeNotificationRepository implements NotificationRepository {
  _FakeNotificationRepository(this.notifications);

  final List<AppNotification> notifications;
  final List<String> markAsReadCalls = [];
  int markAllAsReadCallCount = 0;

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      Stream.value(notifications);

  @override
  Stream<int> watchUnreadCount(String userId) =>
      Stream.value(notifications.where((n) => !n.isRead).length);

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    markAsReadCalls.add(notificationId);
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    markAllAsReadCallCount++;
  }
}

/// Fake `MissionRepository` — ne renvoie qu'UNE mission (ou `null`) via
/// `watchMission()`, quel que soit le `missionId` demandé. Suffisant : dans
/// chaque scénario, un seul écran de mission est atteint après le tap.
/// `noSuchMethod` pour tout le reste (jamais exercé par ces scénarios),
/// pattern identique à `customer_tracking_cross_customer_test.dart`.
class _FakeMissionRepositorySingle implements MissionRepository {
  _FakeMissionRepositorySingle(this.mission);

  final DeliveryMission? mission;

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => Stream.value(mission);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DeliveryMission _buildMission({
  required String id,
  required String customerId,
  String? customerDisplayName,
  String? driverId,
  String? driverDisplayName,
  MissionStatus status = MissionStatus.inTransit,
}) {
  return DeliveryMission(
    id: id,
    customerId: customerId,
    customerDisplayName: customerDisplayName,
    itemCategoryKey: 'cat_furniture',
    description: 'Réfrigérateur',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: status,
    driverId: driverId,
    driverDisplayName: driverDisplayName,
    pricingVersion: 'TEST-V1',
    createdAt: DateTime(2024, 1, 1),
    driverOfferAmount: 95,
    customerTotal: 140,
  );
}

AppNotification _buildNotification({
  required String id,
  required String userId,
  String? missionId,
  bool isRead = false,
  String titleKey = 'notif_driver_assigned_title',
  String bodyKey = 'notif_driver_assigned_body',
  String type = 'driver_assigned',
}) {
  return AppNotification(
    id: id,
    userId: userId,
    type: type,
    titleKey: titleKey,
    bodyKey: bodyKey,
    missionId: missionId,
    createdAt: DateTime(2024, 1, 1, 10),
    isRead: isRead,
  );
}

/// Routeur minimal : SEULES les 3 routes réellement nécessaires au
/// deep-link testé (jamais l'arbre complet `main.dart`).
Widget _buildTestApp(FirebaseAuthProvider auth, {required String userId}) {
  final router = GoRouter(
    initialLocation: '/fr/notifications',
    routes: [
      GoRoute(
        path: '/fr/notifications',
        builder: (context, state) => NotificationsScreen(userId: userId),
      ),
      GoRoute(
        path: '/fr/livraison/suivi/:missionId',
        builder: (context, state) => CustomerTrackingScreen(
          missionId: state.pathParameters['missionId']!,
        ),
      ),
      GoRoute(
        path: '/fr/fournisseur/mission/:missionId',
        builder: (context, state) => DriverActiveMissionScreen(
          missionId: state.pathParameters['missionId']!,
        ),
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
    BackendLocator.notificationRepositoryOverride = null;
    BackendLocator.missionRepositoryOverride = null;
  });

  group('F-3.1 — notification client valide', () {
    testWidgets(
      'tap -> markAsRead appelé -> navigation /fr/livraison/suivi/X -> '
      'CustomerTrackingScreen reçoit exactement X, aucun crash, navigation unique',
      (tester) async {
        const userId = 'customer_A';
        const missionId = 'mission_valid_001';

        final notif = _buildNotification(
          id: 'notif_1',
          userId: userId,
          missionId: missionId,
        );
        final fakeNotifRepo = _FakeNotificationRepository([notif]);
        BackendLocator.notificationRepositoryOverride = fakeNotifRepo;
        BackendLocator.missionRepositoryOverride = _FakeMissionRepositorySingle(
          _buildMission(
            id: missionId,
            customerId: userId,
            driverId: 'driver_1',
            driverDisplayName: 'Chauffeur Test',
            status: MissionStatus.inTransit,
          ),
        );

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.customer];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        // La notification est bien affichée avant le tap.
        expect(find.text(_t('notif_driver_assigned_title')), findsOneWidget);

        await tester.tap(find.text(_t('notif_driver_assigned_title')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // markAsRead appelé exactement une fois, avec le bon id.
        expect(fakeNotifRepo.markAsReadCalls, [notif.id]);

        // Navigation unique vers CustomerTrackingScreen, avec le bon missionId.
        expect(find.byType(NotificationsScreen), findsNothing);
        final trackingScreens = find.byType(CustomerTrackingScreen);
        expect(trackingScreens, findsOneWidget);
        final screen = tester.widget<CustomerTrackingScreen>(trackingScreens);
        expect(screen.missionId, missionId);

        // La mission s'affiche normalement (pas de refus d'accès à tort).
        expect(find.text('Chauffeur Test'), findsOneWidget);
        expect(
          find.text(_t('driver_active_mission_access_denied')),
          findsNothing,
        );
      },
    );
  });

  group('F-3.2 — mission supprimée / inexistante', () {
    testWidgets(
      'tap -> navigation tracking X -> mission introuvable -> fallback '
      'existant réutilisé (aucun écran blanc, aucune exception)',
      (tester) async {
        const userId = 'customer_A';
        const missionId = 'mission_deleted_001';

        final notif = _buildNotification(
          id: 'notif_2',
          userId: userId,
          missionId: missionId,
          titleKey: 'notif_completed_title',
          bodyKey: 'notif_completed_body',
          type: 'completed',
        );
        final fakeNotifRepo = _FakeNotificationRepository([notif]);
        BackendLocator.notificationRepositoryOverride = fakeNotifRepo;
        // Mission supprimée : le repository ne renvoie plus rien (`null`),
        // exactement comme `watchMission()` le ferait pour un document
        // Firestore inexistant.
        BackendLocator.missionRepositoryOverride =
            _FakeMissionRepositorySingle(null);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.customer];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('notif_completed_title')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeNotifRepo.markAsReadCalls, [notif.id]);

        // Fallback EXISTANT de CustomerTrackingScreen réutilisé tel quel
        // (mission == null -> "introuvable") : pas de nouvelle logique.
        expect(
          find.text(_t('driver_active_mission_not_found')),
          findsOneWidget,
        );
        // Aucun contenu de mission fictif ne doit apparaître.
        expect(find.text('Chauffeur Test'), findsNothing);
      },
    );
  });

  group('F-3.3 — mission appartenant à un autre utilisateur', () {
    testWidgets(
      'côté client : tap -> navigation tracking X -> X appartient à '
      'customer_B -> réutilise la protection F-1 (aucune donnée de B affichée)',
      (tester) async {
        const userId = 'customer_A';
        const missionId = 'mission_of_B_001';

        final notif = _buildNotification(
          id: 'notif_3',
          userId: userId,
          missionId: missionId,
          titleKey: 'notif_in_transit_title',
          bodyKey: 'notif_in_transit_body',
          type: 'in_transit',
        );
        final fakeNotifRepo = _FakeNotificationRepository([notif]);
        BackendLocator.notificationRepositoryOverride = fakeNotifRepo;
        BackendLocator.missionRepositoryOverride = _FakeMissionRepositorySingle(
          _buildMission(
            id: missionId,
            customerId: 'customer_B',
            customerDisplayName: 'Client B Secret',
            driverId: 'driver_B',
            driverDisplayName: 'Chauffeur Secret De B',
            status: MissionStatus.inTransit,
          ),
        );

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.customer];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('notif_in_transit_title')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeNotifRepo.markAsReadCalls, [notif.id]);

        // Protection F-1 (déjà existante dans CustomerTrackingScreen)
        // atteinte via le deep-link notification : refus propre, AUCUNE
        // fuite de donnée de B.
        expect(
          find.text(_t('driver_active_mission_access_denied')),
          findsOneWidget,
        );
        expect(find.text('Client B Secret'), findsNothing);
        expect(find.text('Chauffeur Secret De B'), findsNothing);
      },
    );

    testWidgets(
      'côté chauffeur : tap -> navigation /fr/fournisseur/mission/X -> X '
      'appartient à driver_B -> réutilise la protection existante de '
      'DriverActiveMissionScreen (aucune donnée sensible affichée)',
      (tester) async {
        const userId = 'driver_A';
        const missionId = 'mission_of_other_driver_001';

        final notif = _buildNotification(
          id: 'notif_4',
          userId: userId,
          missionId: missionId,
        );
        final fakeNotifRepo = _FakeNotificationRepository([notif]);
        BackendLocator.notificationRepositoryOverride = fakeNotifRepo;
        BackendLocator.missionRepositoryOverride = _FakeMissionRepositorySingle(
          _buildMission(
            id: missionId,
            customerId: 'customer_of_B',
            driverId: 'driver_B',
            driverDisplayName: 'Chauffeur Secret De B',
            status: MissionStatus.driverToPickup,
          ),
        );

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.driver];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('notif_driver_assigned_title')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeNotifRepo.markAsReadCalls, [notif.id]);

        // Bien arrivé sur l'écran chauffeur (pas client), avec le bon id.
        final driverScreens = find.byType(DriverActiveMissionScreen);
        expect(driverScreens, findsOneWidget);
        expect(
          tester.widget<DriverActiveMissionScreen>(driverScreens).missionId,
          missionId,
        );

        // Protection EXISTANTE (`mission.driverId != uid`) réutilisée telle
        // quelle : refus propre, aucune donnée de la mission de B affichée.
        expect(
          find.text(_t('driver_active_mission_access_denied')),
          findsOneWidget,
        );
        expect(find.text('Chauffeur Secret De B'), findsNothing);
      },
    );
  });

  group('Cas nominal chauffeur', () {
    testWidgets(
      'chauffeur connecté -> tap notification mission X -> navigation '
      '/fr/fournisseur/mission/X -> DriverActiveMissionScreen reçoit X '
      '(prouve le branchement client/chauffeur de NotificationsScreen)',
      (tester) async {
        const userId = 'driver_A';
        const missionId = 'mission_driver_own_001';

        final notif = _buildNotification(
          id: 'notif_5',
          userId: userId,
          missionId: missionId,
        );
        final fakeNotifRepo = _FakeNotificationRepository([notif]);
        BackendLocator.notificationRepositoryOverride = fakeNotifRepo;
        BackendLocator.missionRepositoryOverride = _FakeMissionRepositorySingle(
          _buildMission(
            id: missionId,
            customerId: 'customer_own',
            driverId: userId,
            driverDisplayName: 'Chauffeur Test',
            status: MissionStatus.assigned,
          ),
        );

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.driver];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('notif_driver_assigned_title')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(fakeNotifRepo.markAsReadCalls, [notif.id]);

        // Route CHAUFFEUR atteinte (pas la route client) : preuve du bon
        // branchement `auth.hasRole(PlatformRole.driver)`.
        expect(find.byType(CustomerTrackingScreen), findsNothing);
        final driverScreens = find.byType(DriverActiveMissionScreen);
        expect(driverScreens, findsOneWidget);
        expect(
          tester.widget<DriverActiveMissionScreen>(driverScreens).missionId,
          missionId,
        );

        // Mission propre au chauffeur : affichage normal, aucun refus.
        expect(
          find.text(_t('driver_active_mission_access_denied')),
          findsNothing,
        );
      },
    );
  });

  group('missionId null / vide', () {
    testWidgets(
      'notification sans missionId -> tap -> markAsRead appelé -> AUCUNE '
      'navigation (reste sur NotificationsScreen), aucun crash',
      (tester) async {
        const userId = 'customer_A';

        final notif = _buildNotification(
          id: 'notif_6',
          userId: userId,
          missionId: null,
          titleKey: 'notif_document_expiring_soon_title',
          bodyKey: 'notif_document_expiring_soon_body',
          type: 'document_expiring_soon',
        );
        final fakeNotifRepo = _FakeNotificationRepository([notif]);
        BackendLocator.notificationRepositoryOverride = fakeNotifRepo;

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.customer];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('notif_document_expiring_soon_title')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Comportement actuel : `markAsRead` est appelé même sans
        // `missionId` (le skip ne porte QUE sur la navigation) — on
        // documente ce comportement existant sans le modifier (aucun bug
        // démontré).
        expect(fakeNotifRepo.markAsReadCalls, [notif.id]);

        // Aucune navigation : toujours sur NotificationsScreen, aucun écran
        // de mission n'a été atteint.
        expect(find.byType(NotificationsScreen), findsOneWidget);
        expect(find.byType(CustomerTrackingScreen), findsNothing);
        expect(find.byType(DriverActiveMissionScreen), findsNothing);
      },
    );

    // Le chevron `Icons.chevron_right` n'est affiché QUE si `missionId !=
    // null` (voir `_NotificationTile.build()`) — preuve visuelle
    // supplémentaire, déjà existante dans le widget, que ce cas est
    // correctement distingué sans logique nouvelle à créer ici.
    testWidgets(
      'notification sans missionId -> aucun chevron affiché (indicateur '
      'visuel déjà existant, non cliquable comme un item de mission)',
      (tester) async {
        const userId = 'customer_A';
        final notif = _buildNotification(
          id: 'notif_7',
          userId: userId,
          missionId: null,
          titleKey: 'notif_document_expiring_soon_title',
          bodyKey: 'notif_document_expiring_soon_body',
        );
        BackendLocator.notificationRepositoryOverride =
            _FakeNotificationRepository([notif]);

        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = userId
          ..debugForceRoles = const [PlatformRole.customer];

        await tester.pumpWidget(_buildTestApp(auth, userId: userId));
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.chevron_right), findsNothing);
      },
    );
  });
}
