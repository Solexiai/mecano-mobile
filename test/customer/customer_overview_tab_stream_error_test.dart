// ---------------------------------------------------------------------------
// customer_overview_tab_stream_error_test.dart — Phase 7, Bloc AB (gap AB-2).
//
// AVANT ce correctif : le `StreamBuilder<List<DeliveryMission>>` de
// `CustomerOverviewTab` (onglet "Vue d'ensemble" du tableau de bord client,
// premier écran vu après connexion) ne testait JAMAIS `snapshot.hasError`.
//
// En cas d'échec réel du flux `watchCustomerMissions()` (réseau, permission
// transitoire, régression future du repository) :
//   - `snapshot.data` reste `null` -> `deliveries` devient `[]` ;
//   - si le client n'a par ailleurs aucun job mécanique (domaine local, hors
//     Firebase), `total == 0` -> l'écran affichait silencieusement
//     `_EmptyState` ("Vous n'avez encore aucune demande, créez-en une !").
//
// C'est-à-dire qu'une VRAIE ERREUR TECHNIQUE était déguisée en zéro-état
// légitime — exactement l'anti-pattern interdit par AB-2 ("un écran vide ne
// doit jamais dissimuler une erreur technique réelle"). L'onglet voisin
// `CustomerRequestsTab` gérait déjà ce cas correctement (icône d'erreur +
// message + bouton "Réessayer") ; ce test prouve que `CustomerOverviewTab`
// applique désormais le même traitement.
//
//   TEST -> FAIL (AVANT fix) -> FIX -> RETEST (APRÈS fix, ce fichier) :
//   - AVANT le fix : sur un flux en erreur ET aucun job mécanique, le texte
//     `overview_empty_title` ("créez votre première demande") s'affichait à
//     la place d'un message d'erreur -> faux zéro-état.
//   - APRÈS le fix : le texte `requests_error` s'affiche avec une icône
//     d'erreur explicite, et ni le zéro-état ni la liste ne sont rendus.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/providers/mechanic_provider.dart';
import 'package:movik_connect/screens/dashboard/customer/tabs/customer_overview_tab.dart';

/// Simule un `MissionRepository` dont le flux `watchCustomerMissions()`
/// échoue réellement (comme le ferait une coupure réseau ou une erreur de
/// permission transitoire côté Firestore), pour prouver que l'écran ne
/// déguise jamais cette erreur en zéro-état.
class _FakeMissionRepositoryErrorStream implements MissionRepository {
  const _FakeMissionRepositoryErrorStream();

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) =>
      Stream<List<DeliveryMission>>.error(
        Exception('simulated-network-failure'),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Simule un `MissionRepository` "normal" (flux vide, sans erreur), pour la
/// régression : le vrai zéro-état doit continuer à s'afficher quand il n'y a
/// réellement aucune donnée ET aucune erreur.
class _FakeMissionRepositoryEmptyStream implements MissionRepository {
  const _FakeMissionRepositoryEmptyStream();

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) =>
      Stream<List<DeliveryMission>>.value(const <DeliveryMission>[]);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _wrap(FirebaseAuthProvider auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider(create: (_) => MechanicRequestProvider()),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: CustomerOverviewTab(onGoToTab: (_) {}),
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
    'AB-2 : flux watchCustomerMissions() en erreur -> message d\'erreur explicite affiché, PAS le zéro-état, pas de crash',
    (tester) async {
      BackendLocator.missionRepositoryOverride =
          const _FakeMissionRepositoryErrorStream();

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'customer_A';

      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Le message d'erreur explicite doit être visible.
      expect(find.text(AppStrings.t('requests_error', 'fr')), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);

      // Le faux zéro-état ("créez votre première demande") ne doit JAMAIS
      // s'afficher à la place d'une vraie erreur technique.
      expect(find.text(AppStrings.t('overview_empty_title', 'fr')), findsNothing);
      expect(find.byIcon(Icons.inbox_outlined), findsNothing);
    },
  );

  testWidgets(
    'AB-2 (régression) : flux vide SANS erreur -> le vrai zéro-état continue de s\'afficher normalement',
    (tester) async {
      BackendLocator.missionRepositoryOverride =
          const _FakeMissionRepositoryEmptyStream();

      final auth = FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = 'customer_A';

      await tester.pumpWidget(_wrap(auth));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Vrai zéro-état légitime (aucune erreur, juste aucune donnée).
      expect(find.text(AppStrings.t('overview_empty_title', 'fr')), findsOneWidget);
      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);

      // Aucun message d'erreur ne doit apparaître dans ce cas.
      expect(find.text(AppStrings.t('requests_error', 'fr')), findsNothing);
    },
  );
}
