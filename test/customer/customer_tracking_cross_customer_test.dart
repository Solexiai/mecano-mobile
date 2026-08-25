// ---------------------------------------------------------------------------
// customer_tracking_cross_customer_test.dart — Phase 7, Bloc F (gap F-1).
//
// AVANT ce correctif : `CustomerTrackingScreen` n'avait AUCUNE vérification
// défensive de propriété (`mission.customerId == uid`) avant d'afficher les
// données d'une mission — contrairement à `DriverActiveMissionScreen`, qui
// possède un check symétrique explicite (`mission.driverId != uid`).
//
// En production, `firestore.rules` (`delivery_requests/{missionId}: allow
// read: if resource.data.customer_id == uid() || ...`, voir
// `functions/test/integration/securityRules.test.ts`, cas "un autre client
// (pas le propriétaire) ne peut PAS lire ni modifier cette mission" — déjà
// vert) empêche déjà un `StreamBuilder` Firestore réel de recevoir le
// document d'un autre client : la requête échoue par `permission-denied`
// AVANT que Flutter ne reçoive quoi que ce soit.
//
// Ce test prouve — en injectant un `MissionRepository` FAKE qui renvoie
// délibérément (comme le ferait un bug de configuration, un environnement
// de dev sans Security Rules actives, ou une régression future du
// repository) les données d'une mission appartenant à `customer_B` alors
// que l'utilisateur connecté est `customer_A` — que l'écran Flutter possède
// désormais SA PROPRE défense en profondeur, indépendante des Security
// Rules serveur :
//
//   TEST → FAIL → FIX → RETEST (bug de sécurité réel découvert ce tour) :
//   - AVANT le fix : le nom du chauffeur de B, le statut "En transit", la
//     timeline complète de la mission de B s'affichaient intégralement —
//     fuite de données (nom, adresses dénormalisées, montants) vers un
//     client non autorisé si jamais la ligne de défense serveur était
//     contournée/mal configurée.
//   - APRÈS le fix (`mission.customerId != auth.effectiveUid` ->
//     `driver_active_mission_access_denied`) : aucune donnée de la mission
//     de B n'est jamais rendue, quel que soit ce que renvoie le
//     repository.
// ---------------------------------------------------------------------------

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

/// Simule un `MissionRepository` qui — malgré firestore.rules — renverrait
/// (bug/mauvaise config/environnement de test sans rules actives) les
/// données complètes d'une mission appartenant à un AUTRE client
/// (`customer_B`), quel que soit l'utilisateur connecté qui appelle
/// `watchMission()`. Ceci simule le pire cas : la ligne de défense serveur
/// est absente, seule la défense Flutter compte.
class _FakeMissionRepositoryReturnsForeignMission implements MissionRepository {
  final DeliveryMission mission;
  const _FakeMissionRepositoryReturnsForeignMission(this.mission);

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => Stream.value(mission);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

DeliveryMission _missionOfCustomerB({required MissionStatus status}) {
  return DeliveryMission(
    id: 'mission_of_B',
    customerId: 'customer_B',
    customerDisplayName: 'Client B Secret',
    itemCategoryKey: 'cat_furniture',
    description: 'Colis confidentiel de B',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: status,
    driverId: 'driver_B',
    driverDisplayName: 'Chauffeur Secret De B',
    pricingVersion: 'TEST',
    createdAt: DateTime(2024, 1, 1),
    driverOfferAmount: 42,
    customerTotal: 99,
  );
}

Widget _wrap(FirebaseAuthProvider auth, {String missionId = 'mission_of_B'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/fr/livraison/suivi/$missionId',
        routes: [
          GoRoute(
            path: '/fr/livraison/suivi/:missionId',
            builder: (c, s) => CustomerTrackingScreen(
              missionId: s.pathParameters['missionId']!,
            ),
          ),
        ],
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
  });

  testWidgets(
    'F-1 : client A connecté ouvrant la mission du client B — AUCUNE donnée de B affichée, refus propre, pas de crash (mission en cours)',
    (tester) async {
      BackendLocator.missionRepositoryOverride =
          _FakeMissionRepositoryReturnsForeignMission(
        _missionOfCustomerB(status: MissionStatus.inTransit),
      );

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'customer_A';

      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Refus propre, pas d'écran blanc.
      expect(
        find.text(AppStrings.t('driver_active_mission_access_denied', 'fr')),
        findsOneWidget,
      );

      // Aucune fuite : ni le nom du client B, ni celui de son chauffeur,
      // ni le statut de sa mission ne doivent jamais apparaître.
      expect(find.text('Client B Secret'), findsNothing);
      expect(find.text('Chauffeur Secret De B'), findsNothing);
      expect(find.textContaining('Colis confidentiel'), findsNothing);
    },
  );

  testWidgets(
    'F-1 : client A connecté ouvrant la mission COMPLETED du client B — AUCUNE donnée de B affichée (vue _CompletedMissionView aussi protégée)',
    (tester) async {
      BackendLocator.missionRepositoryOverride =
          _FakeMissionRepositoryReturnsForeignMission(
        _missionOfCustomerB(status: MissionStatus.completed),
      );

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'customer_A';

      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings.t('driver_active_mission_access_denied', 'fr')),
        findsOneWidget,
      );
      expect(find.text('Client B Secret'), findsNothing);
      expect(find.textContaining('Colis confidentiel'), findsNothing);
    },
  );

  testWidgets(
    'F-1 (régression) : client A ouvrant SA PROPRE mission continue de fonctionner normalement après le fix',
    (tester) async {
      final ownMission = DeliveryMission(
        id: 'mission_of_A',
        customerId: 'customer_A',
        customerDisplayName: 'Client A',
        itemCategoryKey: 'cat_furniture',
        description: 'Mon canapé',
        requiredVehicleCategory: VehicleCategory.cargoVan,
        status: MissionStatus.inTransit,
        driverId: 'driver_A',
        driverDisplayName: 'Mon Chauffeur',
        pricingVersion: 'TEST',
        createdAt: DateTime(2024, 1, 1),
        driverOfferAmount: 42,
        customerTotal: 99,
      );
      BackendLocator.missionRepositoryOverride =
          _FakeMissionRepositoryReturnsForeignMission(ownMission);

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'customer_A';

      await tester.pumpWidget(_wrap(auth, missionId: 'mission_of_A'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // La mission de A doit s'afficher normalement (pas de faux-positif
      // du check d'ownership).
      expect(find.text('Mon Chauffeur'), findsOneWidget);
      expect(
        find.text(AppStrings.t('driver_active_mission_access_denied', 'fr')),
        findsNothing,
      );
    },
  );
}
