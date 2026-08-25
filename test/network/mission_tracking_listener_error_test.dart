// ---------------------------------------------------------------------------
// mission_tracking_listener_error_test.dart — Phase 7, Bloc G (gap G-3 :
// Firestore listener error).
//
// GAP réel confirmé par grep exhaustif de `test/` avant ce fichier : aucune
// occurrence de `hasError`/`addError` n'était injectée dans un test, alors
// que plusieurs écrans (dont `CustomerTrackingScreen`) gèrent déjà
// `StreamBuilder.hasError` en production :
//
//   if (snap.hasError) {
//     return _CenteredMessage(
//       icon: Icons.wifi_off_outlined,
//       message: t('driver_active_mission_network_error'),
//     );
//   }
//
// Ce fichier prouve, sur `CustomerTrackingScreen` (déjà porteur de ce
// pattern) :
//   G-3.1 : listener `watchMission()` -> erreur -> aucun crash, aucun écran
//           blanc, message réseau cohérent affiché, ET les anciennes
//           données de la mission (nom du chauffeur, statut) précédemment
//           affichées ne restent PAS visibles comme si elles étaient
//           toujours valides (pas de contenu trompeur).
//   G-3.2 : après l'erreur, une nouvelle émission valide sur le MÊME flux
//           (reprise naturelle que l'architecture actuelle permet déjà,
//           un seul `StreamController` réutilisé — pas de couche offline
//           supplémentaire construite pour ce test) -> les données
//           redeviennent visibles normalement, aucun crash.
//
// NE DUPLIQUE PAS :
//   - le check de propriété customerId (déjà couvert par
//     `customer_tracking_cross_customer_test.dart`, Bloc F/F-1) ;
//   - l'authentification requise (déjà couvert par
//     `customer_tracking_screen_auth_test.dart`).
// ---------------------------------------------------------------------------

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';

const _customerId = 'customer_test_listener_error_001';
const _missionId = 'mission_test_listener_error';

/// `MissionRepository` fake exposant un `StreamController` manipulable
/// directement par le test (`emitError`/`emitMission`), pour simuler un
/// listener Firestore qui échoue puis reprend — même pattern de
/// `StreamController` non-broadcast que les autres fakes de ce dossier
/// (`driver_active_mission_status_gaps_test.dart`).
class _MissionStreamRepository implements MissionRepository {
  final _controller = StreamController<DeliveryMission?>();

  _MissionStreamRepository(DeliveryMission initial) {
    _controller.add(initial);
  }

  void emitError(Object error) => _controller.addError(error);
  void emitMission(DeliveryMission mission) => _controller.add(mission);
  void dispose() => _controller.close();

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => _controller.stream;

  // Méthodes non utilisées par ce parcours de test.
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DeliveryMission _trackableMission({required MissionStatus status}) {
  return DeliveryMission(
    id: _missionId,
    customerId: _customerId,
    customerDisplayName: 'Client Test',
    itemCategoryKey: 'cat_furniture',
    description: 'Canapé 3 places',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: status,
    driverId: 'driver_test_001',
    driverDisplayName: 'Chauffeur Visible Avant Erreur',
    pricingVersion: 'TEST-V1',
    createdAt: DateTime(2024, 1, 1),
    driverOfferAmount: 95,
    customerTotal: 140,
  );
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/livraison/suivi/$_missionId',
    routes: [
      GoRoute(
        path: '/fr/livraison/suivi/:missionId',
        builder: (context, state) => CustomerTrackingScreen(
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
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
  });

  testWidgets(
    'G-3.1 : listener Firestore watchMission() -> error -> aucun crash, aucun '
    'écran blanc, message réseau cohérent, aucune ancienne donnée trompeuse '
    'affichée comme encore valide',
    (tester) async {
      final fakeRepo = _MissionStreamRepository(
        _trackableMission(status: MissionStatus.inTransit),
      );
      BackendLocator.missionRepositoryOverride = fakeRepo;

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _customerId;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Avant l'erreur : la mission s'affiche normalement (preuve que le
      // test part bien d'un état "données valides visibles").
      expect(find.text('Chauffeur Visible Avant Erreur'), findsOneWidget);

      // Le listener échoue (ex: permission-denied transitoire, coupure
      // réseau, erreur de désérialisation côté SDK).
      fakeRepo.emitError(Exception('simulated Firestore listener error'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Message réseau cohérent affiché (clé déjà utilisée par
      // DriverActiveMissionScreen pour le même type d'erreur — réutilisation
      // volontaire, pas de nouvelle clé i18n créée pour ce test).
      expect(
        find.text(_t('driver_active_mission_network_error')),
        findsOneWidget,
      );

      // Aucun écran blanc : au moins un Scaffold/AppBar reste affiché.
      expect(find.byType(Scaffold), findsOneWidget);

      // CRITIQUE : l'ancienne donnée (nom du chauffeur, précédemment
      // affichée) ne doit PLUS apparaître comme si elle était toujours
      // valide — `StreamBuilder` doit avoir basculé vers un état d'erreur
      // sans conserver le contenu obsolète.
      expect(find.text('Chauffeur Visible Avant Erreur'), findsNothing);
    },
  );

  testWidgets(
    'G-3.2 : après une erreur listener, une nouvelle émission valide sur le '
    'même flux -> reprise naturelle, données à nouveau affichées, aucun '
    'crash',
    (tester) async {
      final fakeRepo = _MissionStreamRepository(
        _trackableMission(status: MissionStatus.inTransit),
      );
      BackendLocator.missionRepositoryOverride = fakeRepo;

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _customerId;

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      fakeRepo.emitError(Exception('simulated Firestore listener error'));
      await tester.pumpAndSettle();
      expect(
        find.text(_t('driver_active_mission_network_error')),
        findsOneWidget,
      );

      // Reprise : le flux émet à nouveau des données valides (nouvelle
      // notification Firestore réussie après reconnexion réseau) — même
      // `StreamController`, aucune couche offline additionnelle requise.
      fakeRepo.emitMission(_trackableMission(status: MissionStatus.completed));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Le message d'erreur a disparu, la vue "mission complétée" (choisie
      // pour ce second état afin de rester indépendante de la carte GPS)
      // est maintenant affichée normalement.
      expect(
        find.text(_t('driver_active_mission_network_error')),
        findsNothing,
      );
      expect(
        find.text(_t('customer_tracking_completed_title')),
        findsOneWidget,
      );
    },
  );
}
