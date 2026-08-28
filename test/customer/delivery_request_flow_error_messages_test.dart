// ---------------------------------------------------------------------------
// delivery_request_flow_error_messages_test.dart — Phase 7, Bloc AB (AB-3 —
// Premier échec client).
//
// AB-3-A (Quote impossible) — GAP RÉEL trouvé et corrigé :
// `DeliveryRequestFlowScreen._describeError()` renvoyait AUPARAVANT
// directement `CloudFunctionException.message` /
// `BackendNotConfiguredException.message` au client final — c'est-à-dire le
// texte BRUT interne du serveur (ex. "requestQuote: delivery_quotes/xyz
// introuvable après calculateDeliveryQuote." ou "Aucune configuration
// tarifaire active (pricing_configs/active).") :
//   - révèle des noms de collections Firestore / Cloud Functions internes ;
//   - reste TOUJOURS en français, quelle que soit la langue de l'app
//     (mélange de langues, anti-pattern AB-7) ;
//   - n'est pas un message "compréhensible" pour un client final.
// De plus, l'échec de CRÉATION DE MISSION (`createMissionFromQuote`) n'avait
// AUCUN message générique de secours : la clé `delivery_mission_error`
// existait déjà dans app_strings.dart mais n'était jamais utilisée.
//
// APRÈS le fix : toute erreur backend/métier (hors kill switch) est mappée
// vers une clé i18n générique déjà traduite FR/EN/ES
// (`delivery_quote_error` pour le devis, `delivery_mission_error` pour la
// création de mission). Aucun texte brut du serveur n'atteint plus l'UI.
//
// AB-3-B (Kill switch) — RÉGRESSION seulement : `isKillSwitchException()`
// mappe déjà correctement vers `service_temporarily_unavailable` (Bloc X,
// déjà vert) ; ce test prouve que ce chemin continue de fonctionner
// APRÈS le refactor de `_describeError()` ci-dessus (paramètre `genericKey`
// ajouté ne doit pas casser le cas kill switch, vérifié en premier dans la
// fonction).
//
// AB-3-C (Réseau indisponible) — vérifie qu'une exception réseau brute et
// non enveloppée (ex: `Exception('SocketException: Failed host lookup')`)
// est également mappée vers le message générique, jamais affichée
// brute — et qu'AUCUNE mission n'est créée dans ce cas (pas de faux succès).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
import 'package:movik_connect/screens/delivery/delivery_request_flow_screen.dart';

/// Fake `MissionRepository` entièrement paramétrable : permet de simuler
/// n'importe quel échec de `requestQuote`/`createMissionFromQuote` (kill
/// switch, backend non configuré, exception réseau brute) et de compter les
/// appels réels à `createMissionFromQuote` pour prouver l'absence de faux
/// succès / mission fantôme.
class _ScriptedMissionRepository implements MissionRepository {
  Object? quoteError;
  Object? createError;
  int createMissionCallCount = 0;
  int requestQuoteCallCount = 0;

  @override
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  }) async {
    requestQuoteCallCount++;
    if (quoteError != null) throw quoteError!;
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
    if (createError != null) throw createError!;
    return DeliveryMission(
      id: 'mission_test_$createMissionCallCount',
      customerId: 'customer_test_001',
      itemCategoryKey: request.itemCategoryKey,
      description: request.description,
      requiredVehicleCategory: request.requiredVehicleCategory,
      status: MissionStatus.searchingDriver,
      pricingVersion: 'TEST-V1',
      createdAt: DateTime.now(),
    );
  }

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
  Future<AcceptMissionResult> acceptMission({required String missionId, required String driverId}) async =>
      const AcceptMissionResult(success: false, errorCode: 'not_used_in_test');
  @override
  Future<void> markPickupCompleted(String missionId) async {}
  @override
  Future<void> markDeliveryCompleted(String missionId, {required String proofOfDeliveryUrl}) async {}
  @override
  Future<void> updateTrackingStatus({required String missionId, required MissionStatus targetStatus}) async {}
}

Widget _buildTestApp(FirebaseAuthProvider auth) {
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

// Même helper que delivery_request_flow_double_submit_test.dart : le
// bouton peut être hors zone visible (SingleChildScrollView, 800x600).
Future<void> tapEnsuringVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

Future<void> fillFormUpToVehicleStep(WidgetTester tester) async {
  await tapEnsuringVisible(tester, find.text(AppStrings.t('cat_furniture', 'fr')).first);
  await tester.pump();
  await tester.ensureVisible(find.byType(TextField).first);
  await tester.enterText(find.byType(TextField).first, 'Canapé 3 places');
  await tester.pump();
  await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
  await tester.pumpAndSettle();

  final textFields = find.byType(TextField);
  const values = [
    '123 rue Test', 'Montréal', 'H2X1Y1', '45.5', '-73.6',
    '456 rue Cible', 'Laval', 'H7X1Y1', '45.6', '-73.7',
  ];
  for (var i = 0; i < values.length; i++) {
    await tester.ensureVisible(textFields.at(i));
    await tester.enterText(textFields.at(i), values[i]);
  }
  await tester.pump();
  await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
  await tester.pumpAndSettle();

  await tapEnsuringVisible(tester, find.text(AppStrings.t(VehicleCategory.cargoVan.key, 'fr')));
  await tester.pump();
}

void main() {
  late _ScriptedMissionRepository fakeRepo;
  late FirebaseAuthProvider auth;

  setUp(() {
    fakeRepo = _ScriptedMissionRepository();
    BackendLocator.missionRepositoryOverride = fakeRepo;
    auth = FirebaseAuthProvider(backendConfigured: false)
      ..debugForceSignedIn = true
      ..debugForceUid = 'customer_test_001'
      ..debugForceDisplayName = 'Client Test';
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
  });

  testWidgets(
    'AB-3-A : devis impossible (BackendNotConfiguredException) -> message générique traduit affiché, JAMAIS le texte brut serveur, retry possible, aucune mission créée',
    (tester) async {
      fakeRepo.quoteError = const BackendNotConfiguredException(
        'requestQuote: delivery_quotes/xyz introuvable après calculateDeliveryQuote.',
      );

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await fillFormUpToVehicleStep(tester);

      // Étape "Suivant" -> entrée dans l'étape devis -> _requestQuote()
      // déclenché automatiquement -> échoue.
      await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Message générique traduit visible.
      expect(find.text(AppStrings.t('delivery_quote_error', 'fr')), findsOneWidget);

      // AUCUN texte brut interne du serveur ne doit jamais apparaître.
      expect(find.textContaining('delivery_quotes/xyz'), findsNothing);
      expect(find.textContaining('calculateDeliveryQuote'), findsNothing);
      expect(find.textContaining('BackendNotConfiguredException'), findsNothing);

      // Retry possible : bouton "Réessayer" présent et actionnable.
      final retryButton = find.widgetWithText(ElevatedButton, AppStrings.t('common_retry', 'fr'));
      expect(retryButton, findsOneWidget);

      // Aucune mission créée accidentellement.
      expect(fakeRepo.createMissionCallCount, 0);

      // Retry : cette fois le devis réussit (on retire l'erreur avant de
      // retaper), prouvant que le chemin de retry fonctionne réellement.
      fakeRepo.quoteError = null;
      await tapEnsuringVisible(tester, retryButton);
      await tester.pumpAndSettle();
      expect(fakeRepo.requestQuoteCallCount, 2);
      expect(find.text(AppStrings.t('delivery_quote_total', 'fr')), findsOneWidget);
    },
  );

  testWidgets(
    'AB-3-A (variante CloudFunctionException métier) : message générique traduit affiché, jamais le message brut de la Cloud Function',
    (tester) async {
      fakeRepo.quoteError = const CloudFunctionException(
        'failed-precondition',
        'pricing_versions/v3 introuvable.',
      );

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await fillFormUpToVehicleStep(tester);
      await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.t('delivery_quote_error', 'fr')), findsOneWidget);
      expect(find.textContaining('pricing_versions/v3'), findsNothing);
      expect(fakeRepo.createMissionCallCount, 0);
    },
  );

  testWidgets(
    'AB-3-B (régression Bloc X) : kill switch (accept_new_delivery_requests=false) sur le devis -> message service_temporarily_unavailable, pas le message métier générique, aucun nom de flag visible',
    (tester) async {
      fakeRepo.quoteError = const CloudFunctionException(
        'failed-precondition',
        kKillSwitchServerMessage,
      );

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await fillFormUpToVehicleStep(tester);
      await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // Message kill switch spécifique, PAS le message générique
      // `delivery_quote_error` (qui serait trompeur : ce n'est pas un échec
      // de calcul, c'est un service désactivé).
      expect(find.text(AppStrings.t('service_temporarily_unavailable', 'fr')), findsOneWidget);
      expect(find.text(AppStrings.t('delivery_quote_error', 'fr')), findsNothing);
      // Aucun nom de flag interne exposé.
      expect(find.textContaining('accept_new_delivery_requests'), findsNothing);
      expect(find.textContaining('runtime_flags'), findsNothing);
      expect(fakeRepo.createMissionCallCount, 0);
    },
  );

  testWidgets(
    'AB-3-C : réseau indisponible pendant la création de la mission (exception brute non enveloppée) -> message générique, aucune mission créée (pas de faux succès), retry possible',
    (tester) async {
      // Simule une coupure réseau brute (jamais interceptée/enveloppée par
      // le repository, cas le plus défavorable pour l'UI).
      fakeRepo.createError = Exception('SocketException: Failed host lookup (network unavailable)');

      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();
      await fillFormUpToVehicleStep(tester);
      await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', 'fr')));
      await tester.pumpAndSettle();

      // Devis obtenu normalement (seule la création de mission échoue).
      expect(find.text(AppStrings.t('delivery_quote_total', 'fr')), findsOneWidget);

      final submitButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('delivery_confirm_and_create', 'fr'),
      );
      await tapEnsuringVisible(tester, submitButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Message générique de création de mission affiché, jamais le texte
      // brut de la SocketException.
      expect(find.text(AppStrings.t('delivery_mission_error', 'fr')), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
      expect(find.textContaining('Failed host lookup'), findsNothing);

      // AUCUNE mission créée malgré l'appel (le fake a bien été invoqué une
      // fois, mais a échoué -> aucun DeliveryMission retourné/affiché).
      expect(fakeRepo.createMissionCallCount, 1);
      expect(find.byType(DeliveryRequestFlowScreen), findsOneWidget);
      // Pas d'écran de confirmation de mission créée.
      expect(find.textContaining(AppStrings.t('delivery_confirm_and_create', 'fr')), findsWidgets);

      // Retry réel possible : on retire l'erreur puis on retape le même
      // bouton -> la mission est cette fois créée avec succès (une seule
      // fois de plus).
      fakeRepo.createError = null;
      final retryButton = find.widgetWithText(
        ElevatedButton,
        AppStrings.t('delivery_confirm_and_create', 'fr'),
      );
      await tapEnsuringVisible(tester, retryButton);
      await tester.pumpAndSettle();
      expect(fakeRepo.createMissionCallCount, 2);
    },
  );
}
