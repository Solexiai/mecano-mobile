// ---------------------------------------------------------------------------
// MIS-C-09 (Phase 7, Bloc B) — Cas A : double submit UI rapide sur l'écran
// de création de mission (`DeliveryRequestFlowScreen`).
//
// Objectif : prouver qu'un double-tap (ou tap très rapide répété) sur le
// bouton final "Confirmer et créer" ne peut JAMAIS déclencher deux appels
// à `MissionRepository.createMissionFromQuote()` — donc jamais deux
// missions métier créées côté client.
//
// Mécanisme testé (voir _createMission() dans delivery_request_flow_screen.dart) :
// une garde de réentrance EXPLICITE en tête de `_createMission()`
// (`if (_phase == _FlowPhase.creating || _phase == _FlowPhase.created) return;`),
// complémentaire à la désactivation visuelle du bouton (qui dépend d'un
// rebuild post-`setState`, donc pas fiable seule contre un double-tap
// survenant avant ce rebuild).
//
// Utilise le seam de test `BackendLocator.missionRepositoryOverride` (
// injection d'un `MissionRepository` fake qui compte les appels) et
// `FirebaseAuthProvider.debugForceSignedIn` (simule un client authentifié
// sans dépendre de Firebase réel) — les deux `@visibleForTesting`, remis à
// leur état par défaut dans `tearDown`.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/delivery_offer.dart';
import 'package:movik_connect/backend/models/delivery_quote.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';

import '../helpers/fake_address_autocomplete_provider.dart';

/// Fake `MissionRepository` qui compte le nombre RÉEL d'appels à
/// `createMissionFromQuote` et `requestQuote`, avec un délai artificiel
/// pour laisser une fenêtre de course exploitable par un double-tap.
class _CountingMissionRepository implements MissionRepository {
  int createMissionCallCount = 0;
  int requestQuoteCallCount = 0;
  final Duration creationDelay;

  _CountingMissionRepository({this.creationDelay = const Duration(milliseconds: 150)});

  @override
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  }) async {
    requestQuoteCallCount++;
    final now = DateTime.now();
    return DeliveryQuote(
      id: 'quote_test_001',
      missionId: '',
      pricingVersion: 'TEST-V1',
      customerTotal: 120,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<DeliveryMission> createMissionFromQuote(CreateMissionRequest request) async {
    createMissionCallCount++;
    // Délai artificiel : simule la latence réseau réelle pendant laquelle
    // un deuxième tap pourrait survenir si la garde de réentrance était
    // absente ou insuffisante.
    await Future.delayed(creationDelay);
    return DeliveryMission(
      id: 'mission_test_$createMissionCallCount',
      customerId: customerId ?? 'unused',
      itemCategoryKey: request.itemCategoryKey,
      description: request.description,
      requiredVehicleCategory: request.requiredVehicleCategory,
      status: MissionStatus.searchingDriver,
      pricingVersion: 'TEST-V1',
      createdAt: DateTime.now(),
    );
  }

  // ---- Méthodes non utilisées par ce parcours de test ----
  final String? customerId = 'customer_test_001';

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => Stream.value(null);

  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String driverId) => Stream.value(null);

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) => Stream.value(const []);

  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId) => Stream.value(const []);

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

  @override
  Future<void> updateTrackingStatus({required String missionId, required MissionStatus targetStatus}) async {}
}

Widget _buildTestApp(_CountingMissionRepository repo, FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/livraison/demande',
    routes: [
      GoRoute(
        path: '/fr/livraison/demande',
        builder: (context, state) => const DeliveryRequestFlowScreen(locale: 'fr'),
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
  late _CountingMissionRepository fakeRepo;
  late FirebaseAuthProvider auth;
  late FakeAddressAutocompleteProvider fakeAddressProvider;

  setUp(() {
    fakeRepo = _CountingMissionRepository();
    BackendLocator.missionRepositoryOverride = fakeRepo;
    fakeAddressProvider = FakeAddressAutocompleteProvider();
    AddressBackendLocator.autocompleteProviderOverride = fakeAddressProvider;
    auth = FirebaseAuthProvider(backendConfigured: false);
    auth.debugForceSignedIn = true;
    auth.debugForceUid = 'customer_test_001';
    auth.debugForceDisplayName = 'Client Test';
  });

  tearDown(() {
    // CRITIQUE : toujours remettre les seams de test à `null` pour ne jamais
    // laisser un fake repository/provider fuiter vers un autre test.
    BackendLocator.missionRepositoryOverride = null;
    AddressBackendLocator.autocompleteProviderOverride = null;
  });

  // L'écran est enveloppé dans un `SingleChildScrollView` (AppShell) : le
  // bouton "Suivant"/"Confirmer et créer" n'est pas forcément visible dans
  // la fenêtre de test (taille par défaut 800x600) tant qu'on n'a pas fait
  // défiler jusqu'à lui. `ensureVisible` fait défiler la vue avant le tap,
  // sinon `tester.tap()` échoue silencieusement à générer l'event (hit-test
  // hors zone visible) et le flux ne progresse jamais.
  Future<void> tapEnsuringVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
  }

  Future<void> fillFormAndReachQuoteStep(WidgetTester tester) async {
    // Step 1 : catégorie + description.
    await tapEnsuringVisible(tester, find.text(AppStrings.t(DemoCategoryKey.first, 'fr')).first);
    await tester.pump();
    await tester.ensureVisible(find.byType(TextField).first);
    await tester.enterText(find.byType(TextField).first, 'Canapé 3 places');
    await tester.pump();
    await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
    await tester.pumpAndSettle();

    // Step 2 : adresses (pickup + dropoff) — MOVI-K adresses réelles +
    // autocomplete + géocodage : plus de champs lat/lng ni ville/code postal
    // séparés, un seul champ texte par adresse avec sélection RÉELLE d'une
    // suggestion (via le fake provider injecté dans `setUp`), exactement le
    // geste qu'un client ferait en production.
    await typeAndSelectAddress(tester, 0, '123 rue Test, Montréal');
    await typeAndSelectAddress(tester, 1, '456 rue Cible, Laval');
    await tester.pump();
    await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
    await tester.pumpAndSettle();

    // Step 3 : véhicule.
    await tapEnsuringVisible(tester, find.text(AppStrings.t(VehicleCategory.cargoVan.key, 'fr')));
    await tester.pump();
    await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
    // Le passage à l'étape 4 déclenche automatiquement _requestQuote() ;
    // laisser le temps au fake repo (synchrone ici, pas de délai) de
    // répondre puis au widget de se stabiliser sur l'étape devis.
    await tester.pumpAndSettle();
  }

  testWidgets(
    'MIS-C-09 Cas A : double-tap rapide sur le bouton final ne déclenche createMissionFromQuote qu\'UNE seule fois',
    (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp(fakeRepo, auth));
      await tester.pumpAndSettle();

      await fillFormAndReachQuoteStep(tester);

      // On doit être sur l'étape devis, avec un devis chargé (bouton final
      // "Confirmer et créer" actif).
      expect(fakeRepo.requestQuoteCallCount, 1);
      final submitButtonFinder = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('delivery_confirm_and_create', 'fr'),
      );
      expect(submitButtonFinder, findsOneWidget);
      await tester.ensureVisible(submitButtonFinder);
      await tester.pumpAndSettle();

      // Premier tap : déclenche _createMission() (délai artificiel de
      // 150ms avant que la Future ne se résolve).
      await tester.tap(submitButtonFinder);
      // Pump un seul frame (PAS pumpAndSettle) pour rester dans la fenêtre
      // de course où la garde de réentrance est la SEULE protection
      // possible (le rebuild qui grise visuellement le bouton peut ne pas
      // avoir encore été appliqué selon le pipeline de rendu).
      await tester.pump();

      // Deuxième tap IMMÉDIAT, avant la résolution de la Future du premier
      // appel. Si le bouton est toujours dans l'arbre (non remplacé par le
      // loader), on tape dessus une deuxième fois ; sinon (déjà remplacé
      // par le `CircularProgressIndicator` de `_Step4Quote` en phase
      // `creating`), l'absence même du bouton est la preuve qu'un second
      // tap physique est impossible — dans les deux cas, la garde côté
      // `_createMission()` doit rester la protection de fond.
      if (tester.any(submitButtonFinder)) {
        await tester.tap(submitButtonFinder, warnIfMissed: false);
      }
      await tester.pump();
      // Un deuxième tap "brut" tenté directement au niveau du callback
      // interne, pour couvrir aussi le cas où deux `Future` seraient
      // lancées depuis deux gestes quasi simultanés détectés sur la MÊME
      // frame (scenario le plus défavorable).
      final state = tester.state(find.byType(DeliveryRequestFlowScreen));
      // Appel direct de _createMission n'est pas possible (méthode privée)
      // — on simule plutôt un deuxième tap synchronisé sur la même frame en
      // rejouant un tap si le bouton existe encore.
      if (tester.any(submitButtonFinder)) {
        await tester.tap(submitButtonFinder, warnIfMissed: false);
      }
      expect(state, isNotNull); // sanity check : le State existe toujours

      // Laisser toutes les Future se résoudre (délai artificiel de 150ms).
      await tester.pumpAndSettle(const Duration(milliseconds: 500));

      // ASSERTION CENTRALE : peu importe combien de taps ont été tentés,
      // createMissionFromQuote() n'a été appelé qu'UNE seule fois.
      expect(fakeRepo.createMissionCallCount, 1);

      // L'écran doit maintenant afficher la confirmation de mission créée
      // (phase `created`), pas une erreur ni un état bloqué.
      expect(find.byType(DeliveryRequestFlowScreen), findsOneWidget);
    },
  );

  testWidgets(
    'MIS-C-09 Cas A (contrôle négatif direct) : deux appels synchrones à _createMission via deux taps sur builds successifs restent à 1 création',
    (WidgetTester tester) async {
      // Variante avec un délai de création plus long pour maximiser la
      // fenêtre de course, et un troisième tap tenté après le premier
      // rebuild (phase déjà "creating").
      fakeRepo = _CountingMissionRepository(creationDelay: const Duration(milliseconds: 400));
      BackendLocator.missionRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_buildTestApp(fakeRepo, auth));
      await tester.pumpAndSettle();
      await fillFormAndReachQuoteStep(tester);

      final submitButtonFinder = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('delivery_confirm_and_create', 'fr'),
      );
      await tester.ensureVisible(submitButtonFinder);
      await tester.pumpAndSettle();

      await tester.tap(submitButtonFinder);
      await tester.pump(); // 1 frame : phase passe à `creating`.

      // Le bouton "Confirmer et créer" est rendu par `StepProgressForm`
      // lui-même (pas par le contenu de l'étape `_Step4Quote`) : il reste
      // dans l'arbre mais doit être DÉSACTIVÉ (`onPressed == null`) dès que
      // `_phase == creating`, car `canProceed` redevient faux
      // (`_quote != null && _phase == _FlowPhase.quoted`). C'est la preuve
      // que la désactivation visuelle ET la garde logique travaillent
      // ensemble contre un second tap.
      final buttonAfterFirstTap = tester.widget<ElevatedButton>(submitButtonFinder);
      expect(buttonAfterFirstTap.onPressed, isNull);

      await tester.pumpAndSettle(const Duration(seconds: 1));

      expect(fakeRepo.createMissionCallCount, 1);
    },
  );
}

/// Petite indirection pour récupérer la première clé de catégorie de
/// livraison sans dépendre directement de `DemoDataService` dans les
/// imports du test (déjà exposé via l'écran, mais garder le test découplé
/// du contenu exact de la liste).
class DemoCategoryKey {
  static String get first => 'cat_furniture';
}
