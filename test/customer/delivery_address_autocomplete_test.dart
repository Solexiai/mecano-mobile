// ---------------------------------------------------------------------------
// delivery_address_autocomplete_test.dart — SUITE DE TESTS OBLIGATOIRE
// (MOVI-K — CORRECTION UX LIVRAISON — ADRESSES RÉELLES + AUTOCOMPLETE +
// GÉOCODAGE, item (n) du mandat).
//
// Couvre les 10 scénarios explicitement exigés :
//   1. Lat/Lng ABSENTS de l'UI (aucun champ visible, aucun texte technique).
//   2. Sélection valide -> coordonnées sauvegardées (via ResolvedAddress).
//   3. Ville/code postal auto-extraits après sélection (jamais redemandés).
//   4. Indépendance pickup/dropoff (deux adresses différentes -> deux
//      ResolvedAddress différentes, jamais l'une n'écrase l'autre).
//   5. Modifier le texte APRÈS sélection invalide les anciennes coordonnées.
//   6. Adresse non résolue -> la mission est REFUSÉE (fail closed), message
//      `delivery_address_invalid_selection` affiché.
//   7. Fournisseur cartographique indisponible -> message d'erreur PROPRE
//      (`delivery_address_provider_unavailable`), jamais un crash ni un
//      texte technique brut.
//   8. FR/EN/ES : les nouveaux textes visibles sont bien traduits dans les
//      trois langues (jamais une clé i18n brute affichée).
//   9. Compatibilité historique lat/lng (voir aussi
//      test/backend/mission_address_backward_compatibility_test.dart pour la
//      couverture unitaire complète de `MissionAddress.fromJson`) — ici,
//      preuve que le flux ACTUEL produit bien des `MissionAddress` avec
//      lat/lng valides consommables par le format historique.
//   10. Aucune régression du flux devis (`requestQuote`/quote affiché) une
//       fois les adresses résolues via le nouveau système.
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
import 'package:movik_connect/widgets/address_autocomplete_field.dart';

import '../helpers/fake_address_autocomplete_provider.dart';

/// Fake `MissionRepository` qui capture la DERNIÈRE `CreateMissionRequest`
/// envoyée — permet d'inspecter précisément les adresses (`MissionAddress`)
/// réellement transmises au backend, sans dépendre de Firebase.
class _CapturingMissionRepository implements MissionRepository {
  CreateMissionRequest? lastCreateRequest;
  int requestQuoteCallCount = 0;
  int createMissionCallCount = 0;
  Object? createError;

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
      customerTotal: 99,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 15)),
    );
  }

  @override
  Future<DeliveryMission> createMissionFromQuote(CreateMissionRequest request) async {
    createMissionCallCount++;
    lastCreateRequest = request;
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

Widget _buildTestApp(FirebaseAuthProvider auth, {String locale = 'fr'}) {
  final router = GoRouter(
    initialLocation: '/$locale/livraison/demande',
    routes: [
      GoRoute(
        path: '/$locale/livraison/demande',
        builder: (context, state) => DeliveryRequestFlowScreen(locale: locale),
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

Future<void> tapEnsuringVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

/// Amène le formulaire jusqu'à l'étape 2 (adresses), catégorie + description
/// déjà remplies — commun à tous les tests ci-dessous.
Future<void> _reachAddressStep(WidgetTester tester, String locale) async {
  await tapEnsuringVisible(tester, find.text(AppStrings.t('cat_furniture', locale)).first);
  await tester.pump();
  await tester.ensureVisible(find.byType(TextField).first);
  await tester.enterText(find.byType(TextField).first, 'Canapé 3 places');
  await tester.pump();
  await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', locale)));
  await tester.pumpAndSettle();
}

/// Depuis l'étape adresses (déjà atteinte), remplit pickup+dropoff via de
/// vraies sélections de suggestion, puis avance jusqu'au véhicule et au
/// devis (comme le ferait un client réel).
Future<void> _fillAddressesAndReachQuote(
  WidgetTester tester,
  String locale, {
  String pickupQuery = '123 rue Test, Montréal',
  String dropoffQuery = '456 rue Cible, Laval',
}) async {
  await typeAndSelectAddress(tester, 0, pickupQuery);
  await typeAndSelectAddress(tester, 1, dropoffQuery);
  await tester.pump();
  await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', locale)));
  await tester.pumpAndSettle();

  await tapEnsuringVisible(tester, find.text(AppStrings.t(VehicleCategory.cargoVan.key, locale)));
  await tester.pump();
  await tapEnsuringVisible(tester, find.text(AppStrings.t('common_next', locale)));
  await tester.pumpAndSettle();
}

void main() {
  late _CapturingMissionRepository fakeRepo;
  late FirebaseAuthProvider auth;
  late FakeAddressAutocompleteProvider fakeAddressProvider;

  setUp(() {
    fakeRepo = _CapturingMissionRepository();
    BackendLocator.missionRepositoryOverride = fakeRepo;
    fakeAddressProvider = FakeAddressAutocompleteProvider();
    AddressBackendLocator.autocompleteProviderOverride = fakeAddressProvider;
    auth = FirebaseAuthProvider(backendConfigured: false)
      ..debugForceSignedIn = true
      ..debugForceUid = 'customer_test_001'
      ..debugForceDisplayName = 'Client Test';
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
    AddressBackendLocator.autocompleteProviderOverride = null;
  });

  group('1) Lat/Lng ABSENTS de l\'UI', () {
    testWidgets(
      'aucun champ "Latitude"/"Longitude" ni texte technique GPS visible sur '
      'le formulaire de livraison, quelle que soit l\'étape atteinte',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        // Aucun libellé lat/lng, ni FR ni EN, ni le texte technique retiré.
        expect(find.textContaining('Latitude'), findsNothing);
        expect(find.textContaining('Longitude'), findsNothing);
        expect(find.textContaining('latitude'), findsNothing);
        expect(find.textContaining('longitude'), findsNothing);
        expect(find.textContaining('Coordonnées GPS'), findsNothing);
        expect(find.textContaining('GPS approximatives'), findsNothing);

        // Exactement 4 TextField à cette étape : pickup, dropoff (dans
        // AddressAutocompleteField), contact, accès — jamais 10.
        expect(find.byType(TextField), findsNWidgets(4));
        expect(find.byType(AddressAutocompleteField), findsNWidgets(2));

        // Le message de guidage remplace bien l'ancienne note GPS.
        expect(find.text(AppStrings.t('delivery_address_guidance', 'fr')), findsWidgets);
      },
    );
  });

  group('2) Sélection valide -> coordonnées sauvegardées', () {
    testWidgets(
      'sélectionner une suggestion pickup et dropoff permet d\'avancer et '
      'produit des MissionAddress avec lat/lng réels (jamais 1,2 placeholder)',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');
        await _fillAddressesAndReachQuote(tester, 'fr');

        // Devis affiché -> la validation d'étape 2 (canProceed) a bien
        // laissé passer, preuve que les deux adresses sont résolues.
        expect(find.text(AppStrings.t('delivery_quote_total', 'fr')), findsOneWidget);

        await tapEnsuringVisible(
          tester,
          find.widgetWithText(ElevatedButton, AppStrings.t('delivery_confirm_and_create', 'fr')),
        );
        await tester.pumpAndSettle();

        final request = fakeRepo.lastCreateRequest;
        expect(request, isNotNull);
        final pickup = request!.stops.first.address;
        final dropoff = request.stops.last.address;

        expect(pickup.lat, isNot(1));
        expect(pickup.lng, isNot(2));
        expect(dropoff.lat, isNot(1));
        expect(dropoff.lng, isNot(2));
        expect(pickup.placeId, isNotNull);
        expect(pickup.formattedAddress, isNotNull);
        expect(dropoff.placeId, isNotNull);
        expect(dropoff.formattedAddress, isNotNull);
      },
    );
  });

  group('3) Ville/code postal auto-extraits', () {
    testWidgets(
      'après sélection d\'une suggestion, city/postalCode sont remplis '
      'automatiquement dans MissionAddress sans jamais être redemandés au client',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        // Aucun champ "ville"/"code postal" visible à cette étape — la seule
        // saisie du client est le texte d'adresse libre.
        expect(find.textContaining(AppStrings.t('delivery_pickup_address', 'fr')), findsWidgets);
        expect(find.byType(TextField), findsNWidgets(4)); // pickup, dropoff, contact, accès

        await _fillAddressesAndReachQuote(tester, 'fr');
        await tapEnsuringVisible(
          tester,
          find.widgetWithText(ElevatedButton, AppStrings.t('delivery_confirm_and_create', 'fr')),
        );
        await tester.pumpAndSettle();

        final request = fakeRepo.lastCreateRequest!;
        // Le fake provider renseigne city='FakeVille' / postalCode='H0H 0H0'
        // pour TOUTE adresse résolue -> preuve que ces champs sont bien
        // auto-extraits de ResolvedAddress, jamais tapés par le client.
        expect(request.stops.first.address.city, 'FakeVille');
        expect(request.stops.first.address.postalCode, 'H0H 0H0');
        expect(request.stops.last.address.city, 'FakeVille');
        expect(request.stops.last.address.postalCode, 'H0H 0H0');
      },
    );
  });

  group('4) Indépendance pickup / dropoff', () {
    testWidgets(
      'deux adresses différentes -> deux ResolvedAddress DIFFÉRENTES, jamais '
      'l\'une n\'écrase les coordonnées de l\'autre',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');
        await _fillAddressesAndReachQuote(
          tester,
          'fr',
          pickupQuery: '111 avenue Alpha, Terrebonne',
          dropoffQuery: '999 boulevard Omega, Granby',
        );

        await tapEnsuringVisible(
          tester,
          find.widgetWithText(ElevatedButton, AppStrings.t('delivery_confirm_and_create', 'fr')),
        );
        await tester.pumpAndSettle();

        final request = fakeRepo.lastCreateRequest!;
        final pickup = request.stops.first.address;
        final dropoff = request.stops.last.address;

        expect(pickup.placeId, isNot(dropoff.placeId));
        expect(pickup.lat, isNot(dropoff.lat));
        expect(pickup.lng, isNot(dropoff.lng));
        expect(pickup.formattedAddress, isNot(dropoff.formattedAddress));
      },
    );
  });

  group('5) Édition après sélection invalide les coordonnées', () {
    testWidgets(
      'modifier le texte du champ pickup APRÈS avoir sélectionné une '
      'suggestion réinvalide l\'adresse -> impossible d\'avancer à l\'étape suivante',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        await typeAndSelectAddress(tester, 0, '123 rue Test, Montréal');
        await typeAndSelectAddress(tester, 1, '456 rue Cible, Laval');
        await tester.pump();

        // Les deux adresses sont résolues -> "Suivant" doit être actif.
        final nextButtonBefore = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, AppStrings.t('common_next', 'fr')),
        );
        expect(nextButtonBefore.onPressed, isNotNull);

        // Le client modifie manuellement le texte pickup APRÈS la
        // sélection (ex: correction d'une faute de frappe) -> doit
        // invalider immédiatement l'ancienne résolution.
        final pickupField = find.descendant(
          of: find.byType(AddressAutocompleteField).first,
          matching: find.byType(TextField),
        );
        await tester.enterText(pickupField, '123 rue Test, Montréal MODIFIÉ');
        await tester.pump();

        // "Suivant" doit redevenir DÉSACTIVÉ : l'adresse modifiée n'est plus
        // considérée comme résolue tant qu'une nouvelle suggestion n'est pas
        // sélectionnée.
        final nextButtonAfter = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, AppStrings.t('common_next', 'fr')),
        );
        expect(nextButtonAfter.onPressed, isNull);
      },
    );
  });

  group('6) Adresse non résolue -> mission refusée (fail closed)', () {
    testWidgets(
      'si aucune suggestion n\'a jamais été sélectionnée pour le dropoff, '
      'impossible de dépasser l\'étape adresses (canProceed reste faux)',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        // Seul le pickup est résolu ; le dropoff reste du texte libre non
        // sélectionné dans les suggestions.
        await typeAndSelectAddress(tester, 0, '123 rue Test, Montréal');
        final dropoffField = find.descendant(
          of: find.byType(AddressAutocompleteField).at(1),
          matching: find.byType(TextField),
        );
        await tester.enterText(dropoffField, '456 rue Cible, Laval');
        await tester.pump(); // pas de sélection de suggestion -> jamais résolu.

        final nextButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, AppStrings.t('common_next', 'fr')),
        );
        expect(nextButton.onPressed, isNull);

        // Aucune mission n'a pu être créée dans cet état.
        expect(fakeRepo.createMissionCallCount, 0);
      },
    );
  });

  group('7) Fournisseur cartographique indisponible', () {
    testWidgets(
      'recherche : provider indisponible -> message générique traduit affiché, '
      'jamais de crash ni de texte technique brut',
      (tester) async {
        fakeAddressProvider.searchUnavailable = true;

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        final pickupField = find.descendant(
          of: find.byType(AddressAutocompleteField).first,
          matching: find.byType(TextField),
        );
        await tester.enterText(pickupField, '123 rue Test, Montréal');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.t('delivery_address_provider_unavailable', 'fr')), findsOneWidget);
        expect(find.textContaining('AddressProviderUnavailableException'), findsNothing);
        expect(find.textContaining('fake:'), findsNothing);
      },
    );

    testWidgets(
      'résolution : provider indisponible après affichage des suggestions -> '
      'message générique affiché, aucune coordonnée fictive générée',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        final pickupField = find.descendant(
          of: find.byType(AddressAutocompleteField).first,
          matching: find.byType(TextField),
        );
        await tester.enterText(pickupField, '123 rue Test, Montréal');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        // Les suggestions sont bien apparues, MAIS le fournisseur devient
        // indisponible juste avant que le client ne sélectionne.
        fakeAddressProvider.resolveUnavailable = true;
        final suggestionTile = find
            .descendant(of: find.byType(AddressAutocompleteField).first, matching: find.byType(ListTile))
            .first;
        await tester.tap(suggestionTile);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.t('delivery_address_provider_unavailable', 'fr')), findsOneWidget);

        // "Suivant" doit rester désactivé : aucune résolution n'a eu lieu.
        final nextButton = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, AppStrings.t('common_next', 'fr')),
        );
        expect(nextButton.onPressed, isNull);
      },
    );

    testWidgets(
      'aucune suggestion trouvée -> message dédié affiché (pas confondu avec '
      'le message "fournisseur indisponible")',
      (tester) async {
        fakeAddressProvider.emptySuggestions = true;

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');

        final pickupField = find.descendant(
          of: find.byType(AddressAutocompleteField).first,
          matching: find.byType(TextField),
        );
        await tester.enterText(pickupField, 'adresse totalement inexistante xyz');
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.t('delivery_address_no_suggestions', 'fr')), findsOneWidget);
        expect(find.text(AppStrings.t('delivery_address_provider_unavailable', 'fr')), findsNothing);
      },
    );
  });

  group('8) FR/EN/ES', () {
    testWidgets(
      'le libellé de guidage et les labels d\'adresse sont bien traduits '
      'dans les trois langues supportées',
      (tester) async {
        for (final locale in ['fr', 'en', 'es']) {
          await tester.pumpWidget(_buildTestApp(
            FirebaseAuthProvider(backendConfigured: false)
              ..debugForceSignedIn = true
              ..debugForceUid = 'customer_test_001'
              ..debugForceDisplayName = 'Client Test',
            locale: locale,
          ));
          await tester.pumpAndSettle();
          await _reachAddressStep(tester, locale);

          expect(tester.takeException(), isNull, reason: 'locale=$locale');
          expect(
            find.text(AppStrings.t('delivery_pickup_address', locale)),
            findsWidgets,
            reason: 'locale=$locale',
          );
          expect(
            find.text(AppStrings.t('delivery_dropoff_address', locale)),
            findsWidgets,
            reason: 'locale=$locale',
          );
          expect(
            find.text(AppStrings.t('delivery_address_guidance', locale)),
            findsWidgets,
            reason: 'locale=$locale',
          );

          // Jamais une clé i18n brute affichée (ex: la clé elle-même au lieu
          // de sa traduction).
          expect(find.textContaining('delivery_address_guidance'), findsNothing, reason: 'locale=$locale');
        }
      },
    );

    test('les 3 langues (fr/en/es) sont toutes non vides pour les nouvelles clés i18n', () {
      const newKeys = [
        'delivery_address_guidance',
        'delivery_address_no_suggestions',
        'delivery_address_provider_unavailable',
        'delivery_address_invalid_selection',
      ];
      for (final key in newKeys) {
        for (final locale in ['fr', 'en', 'es']) {
          final value = AppStrings.t(key, locale);
          expect(value, isNotEmpty, reason: '$key/$locale');
          expect(value, isNot(key), reason: '$key/$locale ne doit jamais renvoyer la clé brute');
        }
      }
    });
  });

  group('9) Compatibilité lat/lng historique', () {
    testWidgets(
      'le flux ACTUEL produit des MissionAddress avec lat/lng numériques '
      'valides, dans le même format que le format historique (line1/city/'
      'postalCode/lat/lng), consommables sans changement par un lecteur '
      'historique qui ignore formattedAddress/placeId',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');
        await _fillAddressesAndReachQuote(tester, 'fr');
        await tapEnsuringVisible(
          tester,
          find.widgetWithText(ElevatedButton, AppStrings.t('delivery_confirm_and_create', 'fr')),
        );
        await tester.pumpAndSettle();

        final request = fakeRepo.lastCreateRequest!;
        for (final stop in request.stops) {
          final json = stop.address.toJson();
          // Format historique intact : ces 5 clés existaient déjà avant
          // cette évolution et restent au même type.
          expect(json['line1'], isA<String>());
          expect(json['city'], isA<String>());
          expect(json['postal_code'], isA<String>());
          expect(json['lat'], isA<double>());
          expect(json['lng'], isA<double>());
          expect(json['lat'], isNot(0));
          expect(json['lng'], isNot(0));
        }
      },
    );
  });

  group('10) Aucune régression du flux devis', () {
    testWidgets(
      'requestQuote() est bien appelé une seule fois après résolution des '
      'deux adresses, et le devis (montant réel du repository) s\'affiche '
      'normalement, exactement comme avant cette évolution',
      (tester) async {
        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');
        await _fillAddressesAndReachQuote(tester, 'fr');

        expect(fakeRepo.requestQuoteCallCount, 1);
        expect(find.text(AppStrings.t('delivery_quote_total', 'fr')), findsOneWidget);
        expect(find.textContaining('99.00'), findsOneWidget);
      },
    );

    testWidgets(
      'un échec de création de mission (ex: réseau) après adresses résolues '
      'affiche toujours le message générique existant, comportement inchangé',
      (tester) async {
        fakeRepo.createError = Exception('SocketException: réseau indisponible (test)');

        await tester.pumpWidget(_buildTestApp(auth));
        await tester.pumpAndSettle();
        await _reachAddressStep(tester, 'fr');
        await _fillAddressesAndReachQuote(tester, 'fr');

        await tapEnsuringVisible(
          tester,
          find.widgetWithText(ElevatedButton, AppStrings.t('delivery_confirm_and_create', 'fr')),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(AppStrings.t('delivery_mission_error', 'fr')), findsOneWidget);
        expect(find.textContaining('SocketException'), findsNothing);
      },
    );
  });
}
