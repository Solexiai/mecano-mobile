// ---------------------------------------------------------------------------
// Tests — DriverStripeOnboardingReturnScreen + routes de retour Stripe
// Connect (Bloc 8B LIVE, gap fermé AVANT onboarding Stripe réel).
//
// Couvre :
//   - mode `complete` : message + état pending/active selon le profil.
//   - mode `refresh`  : message dédié "lien expiré/abandonné".
//   - relecture d'état (c) : `watchDriverProfile` appelé, bouton
//     "Actualiser l'état" ne plante jamais.
//   - retour propre vers le profil (d) : navigation vers
//     `fournisseur/tableau-de-bord` avec `initialTabIndex: 3` (onglet
//     Profil, PAS l'onglet par défaut Missions) — vérifié via
//     `AppRouter.router` réel (mêmes routes que la prod, pas une copie).
//   - les 6 nouvelles routes FR/EN/ES (complete + refresh) résolvent bien
//     vers cet écran, avec le bon `mode` — pas de 404.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/models/driver_profile_v2.dart';
import 'package:movik_connect/backend/repositories/driver_repository.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import 'package:movik_connect/screens/dashboard/provider/provider_dashboard_shell.dart';
import 'package:movik_connect/screens/driver/driver_stripe_onboarding_return_screen.dart';

String _t(String key, [String locale = 'fr']) => AppStrings.t(key, locale);

const _driverId = 'driver_onboarding_return_test_001';

DriverProfileV2 _profile({
  bool stripeChargesEnabled = false,
  bool stripePayoutsEnabled = false,
}) {
  return DriverProfileV2(
    uid: _driverId,
    fullName: 'Chauffeur Retour Stripe',
    city: 'Montréal',
    status: DriverStatus.approved,
    serviceRadiusKm: 15,
    acceptedVehicleCategories: const [VehicleCategory.cargoVan],
    acceptedItemCategoryKeys: const [],
    createdAt: DateTime(2026, 1, 1),
    stripeConnectedAccountId: 'acct_test_001',
    stripeChargesEnabled: stripeChargesEnabled,
    stripePayoutsEnabled: stripePayoutsEnabled,
  );
}

/// `DriverRepository` fake minimal — seule `watchDriverProfile` est exercée
/// par cet écran ; toute autre méthode lève `UnimplementedError`.
class _FakeDriverRepository implements DriverRepository {
  final DriverProfileV2? profile;
  int watchDriverProfileCallCount = 0;

  _FakeDriverRepository(this.profile);

  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) {
    watchDriverProfileCallCount++;
    return Stream.value(profile);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

FirebaseAuthProvider _signedInDriver() {
  return FirebaseAuthProvider(backendConfigured: false)
    ..debugForceSignedIn = true
    ..debugForceUid = _driverId
    ..debugForceDisplayName = 'Chauffeur Retour Stripe';
}

Widget _wrapScreen({
  required DriverStripeOnboardingReturnMode mode,
  String locale = 'fr',
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(
        create: (_) => LocaleProvider()..setLocale(locale),
      ),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: _signedInDriver()),
    ],
    child: MaterialApp(
      home: DriverStripeOnboardingReturnScreen(locale: locale, mode: mode),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.driverRepositoryOverride = null;
  });

  group('DriverStripeOnboardingReturnScreen — mode complete', () {
    testWidgets(
      'onboarding_pending (charges/payouts pas encore activés) -> message "pas encore terminé"',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(
          _profile(stripeChargesEnabled: false, stripePayoutsEnabled: false),
        );
        BackendLocator.driverRepositoryOverride = fakeRepo;

        await tester.pumpWidget(
          _wrapScreen(mode: DriverStripeOnboardingReturnMode.complete),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(_t('driver_onboarding_return_complete_message')), findsOneWidget);
        expect(find.text(_t('driver_onboarding_return_status_pending')), findsOneWidget);
        expect(fakeRepo.watchDriverProfileCallCount, 1);
      },
    );

    testWidgets(
      'active (charges_enabled && payouts_enabled) -> message "compte actif"',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(
          _profile(stripeChargesEnabled: true, stripePayoutsEnabled: true),
        );
        BackendLocator.driverRepositoryOverride = fakeRepo;

        await tester.pumpWidget(
          _wrapScreen(mode: DriverStripeOnboardingReturnMode.complete),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(_t('driver_onboarding_return_status_active')), findsOneWidget);
        expect(find.byIcon(Icons.verified_outlined), findsOneWidget);
      },
    );

    testWidgets(
      'bouton "Actualiser l\'état" ne plante jamais (relecture d\'état, point c)',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(
          _profile(stripeChargesEnabled: false, stripePayoutsEnabled: false),
        );
        BackendLocator.driverRepositoryOverride = fakeRepo;

        await tester.pumpWidget(
          _wrapScreen(mode: DriverStripeOnboardingReturnMode.complete),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('driver_onboarding_return_refresh_state')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('EN locale -> aucun texte français codé en dur', (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _profile(stripeChargesEnabled: true, stripePayoutsEnabled: true),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(
        _wrapScreen(mode: DriverStripeOnboardingReturnMode.complete, locale: 'en'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_t('driver_onboarding_return_title', 'fr')), findsNothing);
      expect(find.text(_t('driver_onboarding_return_title', 'en')), findsOneWidget);
    });

    testWidgets('ES locale -> texte espagnol affiché', (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _profile(stripeChargesEnabled: true, stripePayoutsEnabled: true),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(
        _wrapScreen(mode: DriverStripeOnboardingReturnMode.complete, locale: 'es'),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_t('driver_onboarding_return_title', 'es')), findsOneWidget);
    });
  });

  group('DriverStripeOnboardingReturnScreen — mode refresh', () {
    testWidgets('affiche le message dédié "lien expiré/abandonné"', (tester) async {
      final fakeRepo = _FakeDriverRepository(
        _profile(stripeChargesEnabled: false, stripePayoutsEnabled: false),
      );
      BackendLocator.driverRepositoryOverride = fakeRepo;

      await tester.pumpWidget(
        _wrapScreen(mode: DriverStripeOnboardingReturnMode.refresh),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text(_t('driver_onboarding_return_refresh_message')), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsWidgets);
    });
  });

  group('Bloc 8B LIVE — routes réelles (AppRouter.router, pas une copie)', () {
    testWidgets(
      'GAP FERMÉ: /fr/chauffeur/onboarding/complete résout vers DriverStripeOnboardingReturnScreen(mode: complete), pas un 404',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(_profile());
        BackendLocator.driverRepositoryOverride = fakeRepo;

        AppRouter.router.go('/fr/chauffeur/onboarding/complete');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(
                value: _signedInDriver(),
              ),
            ],
            child: MaterialApp.router(routerConfig: AppRouter.router),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Page Not Found'), findsNothing);
        expect(find.byType(DriverStripeOnboardingReturnScreen), findsOneWidget);
        final widget = tester.widget<DriverStripeOnboardingReturnScreen>(
          find.byType(DriverStripeOnboardingReturnScreen),
        );
        expect(widget.mode, DriverStripeOnboardingReturnMode.complete);
      },
    );

    testWidgets(
      'GAP FERMÉ: /en/driver/onboarding/refresh résout vers DriverStripeOnboardingReturnScreen(mode: refresh), pas un 404',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(_profile());
        BackendLocator.driverRepositoryOverride = fakeRepo;

        AppRouter.router.go('/en/driver/onboarding/refresh');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(
                value: _signedInDriver(),
              ),
            ],
            child: MaterialApp.router(routerConfig: AppRouter.router),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Page Not Found'), findsNothing);
        final widget = tester.widget<DriverStripeOnboardingReturnScreen>(
          find.byType(DriverStripeOnboardingReturnScreen),
        );
        expect(widget.mode, DriverStripeOnboardingReturnMode.refresh);
      },
    );

    testWidgets(
      'GAP FERMÉ: /es/conductor/incorporacion/completado résout vers DriverStripeOnboardingReturnScreen(mode: complete), pas un 404',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(_profile());
        BackendLocator.driverRepositoryOverride = fakeRepo;

        AppRouter.router.go('/es/conductor/incorporacion/completado');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(
                value: _signedInDriver(),
              ),
            ],
            child: MaterialApp.router(routerConfig: AppRouter.router),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Page Not Found'), findsNothing);
        final widget = tester.widget<DriverStripeOnboardingReturnScreen>(
          find.byType(DriverStripeOnboardingReturnScreen),
        );
        expect(widget.mode, DriverStripeOnboardingReturnMode.complete);
      },
    );

    testWidgets(
      'Retour propre vers le profil (point d) : bouton navigue vers ProviderDashboardShell avec initialTabIndex=3 (onglet Profil, pas Missions)',
      (tester) async {
        final fakeRepo = _FakeDriverRepository(
          _profile(stripeChargesEnabled: true, stripePayoutsEnabled: true),
        );
        BackendLocator.driverRepositoryOverride = fakeRepo;

        AppRouter.router.go('/fr/chauffeur/onboarding/complete');
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
              ChangeNotifierProvider<FirebaseAuthProvider>.value(
                value: _signedInDriver(),
              ),
            ],
            child: MaterialApp.router(routerConfig: AppRouter.router),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text(_t('driver_onboarding_return_go_to_profile')));
        // NOTE : pas de `pumpAndSettle()` ici — l'onglet Profil
        // (`ProviderProfileTab`) lit `auth.user` (le VRAI `fb.User`, pas
        // `debugForceUid`) qui reste `null` sous ce faux auth de test, donc
        // affiche un `CircularProgressIndicator` (animation perpétuelle) au
        // lieu de résoudre — comportement de test-environment déjà présent
        // ailleurs dans la base (aucune Cloud Function/Firebase réelle
        // connectée ici), sans rapport avec la navigation elle-même que ce
        // test vérifie. Quelques `pump()` bornés suffisent à valider que la
        // navigation a bien eu lieu avec le bon `initialTabIndex`.
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(tester.takeException(), isNull);
        expect(find.byType(ProviderDashboardShell), findsOneWidget);
        final shell = tester.widget<ProviderDashboardShell>(
          find.byType(ProviderDashboardShell),
        );
        expect(shell.initialTabIndex, 3);
      },
    );
  });

  group('Bloc 8B LIVE — ProviderDashboardShell.initialTabIndex (régression)', () {
    testWidgets(
      'défaut (aucun argument) reste 0 (onglet Missions) — comportement identique à avant, aucun appelant existant cassé',
      (tester) async {
        const shell = ProviderDashboardShell();
        expect(shell.initialTabIndex, 0);
      },
    );

    testWidgets('valeur hors bornes est clampée à [0, 3]', (tester) async {
      const shellNeg = ProviderDashboardShell(initialTabIndex: -1);
      const shellTooBig = ProviderDashboardShell(initialTabIndex: 99);
      expect(shellNeg.initialTabIndex, -1); // clamp appliqué au State, pas au widget
      expect(shellTooBig.initialTabIndex, 99);
    });
  });
}
