// ---------------------------------------------------------------------------
// provider_dashboard_shell_status_gate_test.dart — Phase 7, Bloc F (gap F-2).
//
// Objectif : prouver qu'un chauffeur `pending_review` (non approuvé) ou
// `suspended` NE PEUT PAS passer en ligne depuis `ProviderDashboardShell`,
// et que le backend reste l'autorité finale (défense en profondeur
// client + serveur, jamais un simple "hide UI").
//
// Chaîne de défense COMPLÈTE (documentée ici pour référence, Bloc F) :
//   1. CLIENT (ce test) : `ProviderDashboardShell` désactive le `Switch`
//      online/offline dès que `profile.status.canGoOnline == false`
//      (`DriverStatusX.canGoOnline` ne retourne `true` que pour
//      `DriverStatus.approved`) — `onChanged: null` -> aucun tap possible.
//   2. SERVEUR (firestore.rules, ligne ~155) : même si le client contournait
//      le check ci-dessus, la règle `driver_profiles.update` n'autorise un
//      changement de `online_status` PAR LE CHAUFFEUR LUI-MÊME que si
//      `resource.data.status == 'approved'` -> PERMISSION_DENIED sinon.
//   3. SERVEUR (Cloud Function `acceptDelivery`, ligne ~85) : même si un
//      chauffeur non approuvé se déclarait malgré tout `online` (bug/faille
//      contournant 1 et 2), `acceptDelivery()` vérifie explicitement
//      `driver.status !== DriverStatuses.APPROVED` et lève
//      `permission-denied` — DÉJÀ testé et vert côté Cloud Functions :
//      `functions/test/integration/acceptDeliveryConcurrency.test.ts`,
//      cas "un chauffeur au statut 'pending_review' (non approuvé) ne peut
//      PAS accepter" et "un chauffeur suspendu ne peut PAS accepter".
//
// Ce fichier ne duplique PAS les tests Cloud Functions (2 et 3 ci-dessus,
// déjà verts) — il ferme uniquement le gap client (1), qui n'avait aucune
// couverture widget-test dédiée pour `ProviderDashboardShell` avant Bloc F.
// `provider_jobs_tab_test.dart` couvre déjà le rendu du refus backend
// ('unknown_error'/'delivery_already_assigned'/exception réseau) sur
// `acceptMission()` — référencé ici plutôt que dupliqué.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/provider/provider_dashboard_shell.dart';

const _driverId = 'driver_gate_test_001';

DriverProfileV2 _buildProfile({
  required DriverStatus status,
  DriverOnlineStatus onlineStatus = DriverOnlineStatus.offline,
}) {
  return DriverProfileV2(
    uid: _driverId,
    fullName: 'Chauffeur Test Gate',
    city: 'Montréal',
    status: status,
    serviceRadiusKm: 25,
    acceptedVehicleCategories: const [VehicleCategory.cargoVan],
    acceptedItemCategoryKeys: const ['cat_furniture'],
    createdAt: DateTime(2024, 1, 1),
    onlineStatus: onlineStatus,
    suspensionReason: status == DriverStatus.suspended ? 'Test F-2' : null,
    suspendedAt: status == DriverStatus.suspended ? DateTime(2024, 6, 1) : null,
  );
}

/// Fake `DriverRepository` minimal : seules `watchDriverProfile` et
/// `setDriverOnlineStatus` sont réellement exercées par
/// `ProviderDashboardShell` ; toute autre méthode lève explicitement
/// (jamais un faux succès silencieux si un chemin de test l'atteint par
/// erreur).
class _FakeDriverRepository implements DriverRepository {
  final DriverProfileV2 profile;
  int setDriverOnlineStatusCallCount = 0;
  int watchDriverProfileCallCount = 0;

  /// Si positionné, `setDriverOnlineStatus()` lève cette exception au lieu
  /// de réussir — simule le refus Security Rules / Cloud Function côté
  /// serveur (défense de niveau 2/3 ci-dessus) pour un appel qui, en
  /// pratique, ne devrait jamais être déclenchable depuis l'UI puisque le
  /// `Switch` est désactivé.
  Object? setDriverOnlineStatusError;

  _FakeDriverRepository(this.profile);

  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) {
    watchDriverProfileCallCount++;
    return Stream.value(profile);
  }

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) async {
    setDriverOnlineStatusCallCount++;
    final err = setDriverOnlineStatusError;
    if (err != null) throw err;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget _wrap(FirebaseAuthProvider auth, {String locale = 'fr'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider()..setLocale(locale),
      ),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/$locale/provider/dashboard',
        routes: [
          GoRoute(
            path: '/$locale/provider/dashboard',
            builder: (c, s) => const ProviderDashboardShell(),
          ),
          GoRoute(
            path: '/$locale/connexion',
            builder: (c, s) => const Scaffold(body: Text('AUTH_SCREEN')),
          ),
        ],
      ),
    ),
  );
}

FirebaseAuthProvider _signedInDriver() {
  return FirebaseAuthProvider(backendConfigured: false)
    ..debugForceSignedIn = true
    ..debugForceUid = _driverId
    ..debugForceDisplayName = 'Chauffeur Test Gate';
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.driverRepositoryOverride = null;
  });

  testWidgets(
    'F-2 : chauffeur pending_review (non approuvé) -> Switch désactivé (onChanged null), impossible de passer online',
    (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _buildProfile(status: DriverStatus.pendingReview),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_wrap(_signedInDriver()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
      expect(switchWidget.onChanged, isNull);

      // Même un "tap" direct sur le Switch désactivé ne doit déclencher
      // aucun appel repository (Flutter n'invoque jamais onChanged==null).
      await tester.tap(switchFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    },
  );

  testWidgets(
    'F-2 : chauffeur suspended -> Switch désactivé (onChanged null), impossible de passer online',
    (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _buildProfile(status: DriverStatus.suspended),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_wrap(_signedInDriver()));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isFalse);
      expect(switchWidget.onChanged, isNull);

      await tester.tap(switchFinder, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(fakeRepo.setDriverOnlineStatusCallCount, 0);
    },
  );

  testWidgets(
    'F-2 (régression) : chauffeur approved -> Switch actif, setDriverOnlineStatus appelé normalement',
    (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _buildProfile(status: DriverStatus.approved),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_wrap(_signedInDriver()));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.onChanged, isNotNull);

      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      expect(fakeRepo.setDriverOnlineStatusCallCount, 1);
    },
  );

  testWidgets(
    'Bloc M (gap performance corrigé) : watchDriverProfile() n\'est appelé '
    'qu\'une seule fois même après plusieurs bascules online/offline '
    '(stream mémoïsé par driverId, pas recréé à chaque setState)',
    (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _buildProfile(status: DriverStatus.approved),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_wrap(_signedInDriver()));
      await tester.pumpAndSettle();

      // Un seul appel à `watchDriverProfile()` au premier build.
      expect(fakeRepo.watchDriverProfileCallCount, 1);

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();
      await tester.tap(switchFinder, warnIfMissed: false);
      await tester.pumpAndSettle();

      // Avant le correctif Bloc M, chaque `setState()` de
      // `_toggleAvailability` recréait le Stream (nouvel appel à
      // `watchDriverProfile()` à chaque rebuild). Après correctif, un seul
      // appel reste enregistré pour toute la durée de vie du widget.
      expect(fakeRepo.watchDriverProfileCallCount, 1);
    },
  );

  testWidgets(
    'F-2 (défense niveau 2, cas défensif) : si le Switch était malgré tout '
    'contourné, le backend (simulé ici) refuse -> pas de crash, pas de faux succès UI',
    (tester) async {
      // Ce scénario ne devrait jamais se produire en pratique (le Switch
      // est désactivé côté UI pour un statut non-approved), mais prouve
      // que même un appel direct à setDriverOnlineStatus() échoue proprement
      // si jamais la garde UI était contournée — cohérent avec
      // firestore.rules (PERMISSION_DENIED) documenté en en-tête.
      final fakeRepo = _FakeDriverRepository(
        _buildProfile(status: DriverStatus.approved),
      )..setDriverOnlineStatusError = Exception('PERMISSION_DENIED (simulated)');
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_wrap(_signedInDriver()));
      await tester.pumpAndSettle();

      final switchFinder = find.byType(Switch);
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      // Aucun crash non capturé : ProviderDashboardShell._toggleAvailability
      // capture l'exception dans un try/catch et affiche un SnackBar.
      expect(tester.takeException(), isNull);
    },
  );

  // Phase 7, Bloc AB (AB-4, gap AB-4-B) — GAP RÉEL corrigé : le titre
  // "Espace fournisseur" et les libellés "Disponible"/"Hors ligne" de
  // l'AppBar étaient codés en dur en français, donc affichés tels quels
  // même en EN/ES (mélange de langue visible dans le tableau de bord
  // chauffeur — viole AB-7). Vérifie ici que la locale EN ne montre plus
  // AUCUN de ces 3 textes français.
  testWidgets(
    'Phase 7, Bloc AB (AB-4, gap AB-4-B) -> locale EN : aucun texte français codé en dur '
    "(titre \"Espace fournisseur\", libellés \"Disponible\"/\"Hors ligne\")",
    (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _buildProfile(status: DriverStatus.approved),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(_wrap(_signedInDriver(), locale: 'en'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('Espace fournisseur'), findsNothing);
      expect(find.text('Disponible'), findsNothing);
      expect(find.text('Hors ligne'), findsNothing);

      // Le titre traduit et le libellé "hors ligne" (offline par défaut)
      // doivent être visibles à la place.
      expect(find.text(AppStrings.t('nav_provider_space', 'en')), findsOneWidget);
      expect(
        find.text(AppStrings.t('driver_status_offline_label_short', 'en')),
        findsOneWidget,
      );
    },
  );
}
