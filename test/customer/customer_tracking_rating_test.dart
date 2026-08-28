// ---------------------------------------------------------------------------
// customer_tracking_rating_test.dart — Phase 7, Bloc AB (AB-10).
//
// GAP PRODUIT RÉEL confirmé pendant AB-10 : le requirement produit initial
// de Movi-k ("après une livraison terminée, le client peut évaluer le
// chauffeur de 1 à 5 étoiles avec commentaire optionnel") n'avait AUCUNE
// implémentation (ni Cloud Function, ni repository, ni UI Flutter) malgré
// une Security Rule `ratings/{ratingId}` déjà correctement conçue depuis
// Phase 2/3 (commit 3af089f) — voir `firestore.rules` + investigation
// exhaustive (grep) de `functions/src`, `lib/`.
//
// Ce test prouve, via le seam `BackendLocator.ratingRepositoryOverride`
// (même pattern que `missionRepositoryOverride` dans
// `customer_tracking_cross_customer_test.dart`) :
//   1. Une mission `completed` avec chauffeur assigné affiche désormais un
//      formulaire de notation (5 étoiles + commentaire optionnel).
//   2. Tenter d'envoyer sans sélectionner d'étoile affiche une erreur
//      claire, N'APPELLE JAMAIS le repository (aucune écriture invalide).
//   3. Sélectionner des étoiles + envoyer appelle bien
//      `submitDriverRating()` avec le missionId/customerId/stars/comment
//      corrects, puis affiche un état de remerciement.
//   4. Une mission déjà notée (le repository renvoie une `MissionRating`
//      existante) affiche l'état "déjà noté" en LECTURE SEULE, sans
//      formulaire ni possibilité de renvoyer (pas de double rating
//      incohérent).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/backend/models/mission_rating.dart';
import 'package:movik_connect/backend/repositories/mission_repository.dart';
import 'package:movik_connect/backend/repositories/rating_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';

const _customerId = 'customer_ab10';
const _missionId = 'mission_ab10_completed';

DeliveryMission _completedMission() {
  return DeliveryMission(
    id: _missionId,
    customerId: _customerId,
    customerDisplayName: 'Client AB-10',
    itemCategoryKey: 'cat_furniture',
    description: 'Colis test AB-10',
    requiredVehicleCategory: VehicleCategory.cargoVan,
    status: MissionStatus.completed,
    driverId: 'driver_ab10',
    driverDisplayName: 'Chauffeur AB-10',
    pricingVersion: 'TEST',
    createdAt: DateTime(2026, 1, 1),
    completedAt: DateTime(2026, 1, 1, 12, 0),
    driverOfferAmount: 30,
    customerTotal: 45,
  );
}

class _FakeMissionRepositoryWatchOnly implements MissionRepository {
  final DeliveryMission mission;
  const _FakeMissionRepositoryWatchOnly(this.mission);

  @override
  Stream<DeliveryMission?> watchMission(String missionId) =>
      Stream.value(mission);

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

/// Fake `RatingRepository` — enregistre les appels et permet de simuler
/// "déjà noté" / "pas encore noté" / échec d'écriture.
class _FakeRatingRepository implements RatingRepository {
  MissionRating? existingRating;
  bool throwOnSubmit = false;

  int submitCallCount = 0;
  String? lastMissionId;
  String? lastCustomerId;
  int? lastStars;
  String? lastComment;

  @override
  Future<MissionRating?> getMyRatingForMission({
    required String missionId,
    required String customerId,
  }) async {
    return existingRating;
  }

  @override
  Future<void> submitDriverRating({
    required String missionId,
    required String customerId,
    required int stars,
    String? comment,
  }) async {
    submitCallCount++;
    lastMissionId = missionId;
    lastCustomerId = customerId;
    lastStars = stars;
    lastComment = comment;
    if (throwOnSubmit) {
      throw Exception('simulated backend failure');
    }
    existingRating = MissionRating(
      id: '${missionId}_customer',
      missionId: missionId,
      raterId: customerId,
      raterRole: 'customer',
      stars: stars,
      comment: comment,
    );
  }
}

Widget _wrap(FirebaseAuthProvider auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider.value(value: auth),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/fr/livraison/suivi/$_missionId',
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

// L'écran est un `SingleChildScrollView` : le formulaire de notation (en
// bas de la vue "mission complétée", après la timeline/adresses) n'est pas
// forcément visible dans la fenêtre de test (taille par défaut 800x600)
// tant qu'on n'a pas fait défiler jusqu'à lui — même convention que
// `customer/delivery_request_flow_double_submit_test.dart`.
Future<void> tapEnsuringVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
}

void main() {
  late _FakeRatingRepository fakeRatingRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    fakeRatingRepo = _FakeRatingRepository();
    BackendLocator.missionRepositoryOverride =
        _FakeMissionRepositoryWatchOnly(_completedMission());
    BackendLocator.ratingRepositoryOverride = fakeRatingRepo;
  });

  tearDown(() {
    BackendLocator.missionRepositoryOverride = null;
    BackendLocator.ratingRepositoryOverride = null;
  });

  FirebaseAuthProvider _authAsCustomer() =>
      FirebaseAuthProvider(backendConfigured: false)
        ..debugForceSignedIn = true
        ..debugForceUid = _customerId;

  testWidgets(
    'AB-10 : mission completed sans notation existante affiche le formulaire de notation (5 étoiles + commentaire)',
    (tester) async {
      await tester.pumpWidget(_wrap(_authAsCustomer()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings.t('customer_tracking_rate_driver_title', 'fr')),
        findsOneWidget,
      );
      expect(
        find.text(
          AppStrings.t('customer_tracking_rate_driver_submit', 'fr'),
        ),
        findsOneWidget,
      );
      // 5 boutons étoile (icônes star_border par défaut, aucune sélection).
      expect(find.byIcon(Icons.star_border), findsWidgets);
    },
  );

  testWidgets(
    'AB-10 : envoyer sans sélectionner d\'étoile affiche une erreur claire et n\'appelle JAMAIS le repository',
    (tester) async {
      await tester.pumpWidget(_wrap(_authAsCustomer()));
      await tester.pumpAndSettle();

      final submitButton = find.text(
        AppStrings.t('customer_tracking_rate_driver_submit', 'fr'),
      );
      await tapEnsuringVisible(tester, submitButton);
      await tester.pumpAndSettle();

      expect(
        find.text(
          AppStrings.t(
            'customer_tracking_rate_driver_select_stars_error',
            'fr',
          ),
        ),
        findsOneWidget,
      );
      expect(fakeRatingRepo.submitCallCount, 0);
    },
  );

  testWidgets(
    'AB-10 : sélectionner 4 étoiles + commentaire + envoyer appelle submitDriverRating avec les bonnes valeurs, puis affiche le remerciement',
    (tester) async {
      await tester.pumpWidget(_wrap(_authAsCustomer()));
      await tester.pumpAndSettle();

      // Tap sur la 4e étoile (index 3 parmi les 5 boutons star_border).
      final starButtons = find.byIcon(Icons.star_border);
      await tapEnsuringVisible(tester, starButtons.at(3));
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(
        find.byType(TextField),
        'Super chauffeur, très ponctuel !',
      );
      await tester.pump();

      final submitButton = find.text(
        AppStrings.t('customer_tracking_rate_driver_submit', 'fr'),
      );
      await tapEnsuringVisible(tester, submitButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(fakeRatingRepo.submitCallCount, 1);
      expect(fakeRatingRepo.lastMissionId, _missionId);
      expect(fakeRatingRepo.lastCustomerId, _customerId);
      expect(fakeRatingRepo.lastStars, 4);
      expect(fakeRatingRepo.lastComment, 'Super chauffeur, très ponctuel !');

      // État de remerciement affiché, formulaire disparu.
      expect(
        find.text(
          AppStrings.t('customer_tracking_rate_driver_thanks_title', 'fr'),
        ),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.t('customer_tracking_rate_driver_submit', 'fr')),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AB-10 : mission déjà notée affiche l\'état "déjà noté" en lecture seule, jamais le formulaire',
    (tester) async {
      fakeRatingRepo.existingRating = const MissionRating(
        id: '${_missionId}_customer',
        missionId: _missionId,
        raterId: _customerId,
        raterRole: 'customer',
        stars: 5,
        comment: 'Parfait',
      );

      await tester.pumpWidget(_wrap(_authAsCustomer()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(
          AppStrings.t('customer_tracking_rate_driver_thanks_title', 'fr'),
        ),
        findsOneWidget,
      );
      expect(find.text('Parfait'), findsOneWidget);
      // Aucun formulaire / bouton d'envoi -> aucun double rating possible.
      expect(
        find.text(AppStrings.t('customer_tracking_rate_driver_submit', 'fr')),
        findsNothing,
      );
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets(
    'AB-10 : échec d\'écriture (réseau/permission) affiche un message clair, jamais un faux succès',
    (tester) async {
      fakeRatingRepo.throwOnSubmit = true;

      await tester.pumpWidget(_wrap(_authAsCustomer()));
      await tester.pumpAndSettle();

      final starButtons = find.byIcon(Icons.star_border);
      await tapEnsuringVisible(tester, starButtons.first);
      await tester.pumpAndSettle();

      final submitButton = find.text(
        AppStrings.t('customer_tracking_rate_driver_submit', 'fr'),
      );
      await tapEnsuringVisible(tester, submitButton);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
        find.text(AppStrings.t('customer_tracking_rate_driver_error', 'fr')),
        findsOneWidget,
      );
      // Jamais de faux succès : pas de message de remerciement affiché.
      expect(
        find.text(
          AppStrings.t('customer_tracking_rate_driver_thanks_title', 'fr'),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'AB-10 : ne plante jamais, quelle que soit la locale (fr/en/es)',
    (tester) async {
      for (final locale in ['fr', 'en', 'es']) {
        BackendLocator.missionRepositoryOverride =
            _FakeMissionRepositoryWatchOnly(_completedMission());
        BackendLocator.ratingRepositoryOverride = _FakeRatingRepository();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LocaleProvider()),
              ChangeNotifierProvider.value(value: _authAsCustomer()),
            ],
            child: Consumer<LocaleProvider>(
              builder: (context, localeProvider, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (localeProvider.locale != locale) {
                    localeProvider.setLocale(locale);
                  }
                });
                return MaterialApp(
                  home: const CustomerTrackingScreen(missionId: _missionId),
                );
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: 'locale=$locale');
      }
    },
  );
}
