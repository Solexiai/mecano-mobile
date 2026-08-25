// ---------------------------------------------------------------------------
// critical_screens_viewport_test.dart — Phase 7, Bloc J (RESPONSIVE/VIEWPORTS).
//
// J-0 (matrice courte, cf. docs/PHASE7_QA_MATRIX.md pour le détail complet) :
//   J-1/J-2 : AUCUN test existant ne vérifiait automatiquement l'absence
//             d'overflow sur plusieurs largeurs de téléphone pour les
//             écrans critiques Auth/Provider — GAP comblé ici. BUG-007
//             (`provider_dashboard_shell_status_gate_test.dart`) prouve déjà
//             le comportement fonctionnel du Switch online/offline à la
//             taille de test par défaut (800x600) mais SANS varier la
//             largeur — ce fichier ajoute la variation de largeur (320 à
//             480px) sur ce même écran pour prouver la non-régression du
//             correctif BUG-007 lui-même, SANS dupliquer la logique métier
//             déjà testée (statut chauffeur pending_review/suspended).
//   J-3 : AUCUN test existant ne vérifiait l'absence d'overflow FR/EN/ES sur
//         un écran critique — GAP comblé (AuthScreen, textes de longueur
//         variable selon la langue).
//   J-4 : AUCUN test existant ne vérifiait l'accessibilité du CTA sous
//         contrainte d'espace vertical réduit (clavier virtuel) sur un
//         formulaire critique — GAP comblé (AuthScreen, formulaire
//         inscription complet : nom + courriel + mot de passe + CTA).
//   J-5 : AUCUN test existant ne vérifiait un dialog/modal à largeur étroite
//         — GAP comblé (SafetyScreen, dialog de signalement : TextField +
//         2 boutons d'action).
//   J-6 : web/desktop (>=900px) déjà couvert par
//         `test/finance/admin_finance_ui_test.dart` (NavigationRail
//         1200x900) — référencé, non dupliqué ici.
//
// RÈGLE OVERFLOW (respectée strictement) : aucun `tester.takeException()`
// n'est masqué ou ignoré ; aucune largeur de viewport n'est élargie
// artificiellement pour faire "passer" un test — toutes les largeurs
// choisies (320/360/390/430/480px) correspondent à des téléphones réels
// (iPhone SE, iPhone standard, Pixel, iPhone Pro Max, limite `isNarrowPhone`).
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
import 'package:movik_connect/screens/auth/auth_screen.dart';
import 'package:movik_connect/screens/dashboard/provider/provider_dashboard_shell.dart';
import 'package:movik_connect/screens/info/safety_screen.dart';

// ---------------------------------------------------------------------------
// Fakes réutilisés (mêmes patterns que provider_dashboard_shell_status_gate_
// test.dart, Bloc F) — pas de nouveau seam créé.
// ---------------------------------------------------------------------------

const _driverId = 'driver_viewport_test_001';

DriverProfileV2 _buildApprovedProfile() {
  return DriverProfileV2(
    uid: _driverId,
    fullName: 'Chauffeur Viewport Test',
    city: 'Montréal',
    status: DriverStatus.approved,
    serviceRadiusKm: 25,
    acceptedVehicleCategories: const [VehicleCategory.cargoVan],
    acceptedItemCategoryKeys: const ['cat_furniture'],
    createdAt: DateTime(2024, 1, 1),
    onlineStatus: DriverOnlineStatus.offline,
  );
}

class _FakeDriverRepository implements DriverRepository {
  final DriverProfileV2 profile;
  _FakeDriverRepository(this.profile);

  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) => Stream.value(profile);

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

FirebaseAuthProvider _signedInDriver() {
  return FirebaseAuthProvider(backendConfigured: false)
    ..debugForceSignedIn = true
    ..debugForceUid = _driverId
    ..debugForceDisplayName = 'Chauffeur Viewport Test';
}

Widget _wrapProviderDashboard(FirebaseAuthProvider auth) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/fr/provider/dashboard',
        routes: [
          GoRoute(
            path: '/fr/provider/dashboard',
            builder: (c, s) => const ProviderDashboardShell(),
          ),
          GoRoute(
            path: '/fr/connexion',
            builder: (c, s) => const Scaffold(body: Text('AUTH_SCREEN')),
          ),
        ],
      ),
    ),
  );
}

Widget _wrapAuthScreen({String locale = 'fr'}) {
  final auth = FirebaseAuthProvider(backendConfigured: false);
  final localeProvider = LocaleProvider();
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>.value(value: localeProvider),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/$locale/connexion',
        routes: [
          GoRoute(
            path: '/$locale/connexion',
            builder: (c, s) => AuthScreen(locale: locale),
          ),
        ],
      ),
    ),
  );
}

Widget _wrapSafetyScreen({String locale = 'fr'}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>(
        create: (_) => FirebaseAuthProvider(backendConfigured: false),
      ),
    ],
    child: MaterialApp.router(
      routerConfig: GoRouter(
        initialLocation: '/$locale/securite',
        routes: [
          GoRoute(
            path: '/$locale/securite',
            builder: (c, s) => SafetyScreen(locale: locale),
          ),
        ],
      ),
    ),
  );
}

void _setViewport(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    BackendLocator.driverRepositoryOverride = null;
  });

  group('J-1/J-2 — viewports & régression BUG-007 (ProviderDashboardShell)', () {
    // Largeurs réelles de téléphones : iPhone SE (320), Android compact
    // (360), iPhone standard (390), Android large (430), limite
    // isNarrowPhone (480).
    for (final width in [320.0, 360.0, 390.0, 430.0, 480.0]) {
      testWidgets(
        'J-2 : ProviderDashboardShell (AppBar corrigée BUG-007) — aucun '
        'overflow à ${width.toInt()}px de large, Switch toujours visible '
        'et fonctionnel',
        (tester) async {
          _setViewport(tester, width, 800);

          final fakeRepo = _FakeDriverRepository(_buildApprovedProfile());
          BackendLocator.driverRepositoryOverride = fakeRepo;

          await tester.pumpWidget(_wrapProviderDashboard(_signedInDriver()));
          await tester.pumpAndSettle();

          // RÈGLE OVERFLOW : jamais masqué — si un RenderFlex overflow ou
          // toute autre exception de layout survient, le test échoue.
          expect(tester.takeException(), isNull);

          // Action essentielle (BUG-007 : jamais masquée, quelle que soit
          // la largeur) : le Switch online/offline reste visible et actif.
          final switchFinder = find.byType(Switch);
          expect(switchFinder, findsOneWidget);
          expect(tester.widget<Switch>(switchFinder).onChanged, isNotNull);
        },
      );
    }

    testWidgets(
      'J-1 : ProviderDashboardShell — grande largeur (600px, phablette) sans '
      'overflow, libellés texte décoratifs réapparaissent (isNarrowPhone == false)',
      (tester) async {
        _setViewport(tester, 600, 900);

        final fakeRepo = _FakeDriverRepository(_buildApprovedProfile());
        BackendLocator.driverRepositoryOverride = fakeRepo;

        await tester.pumpWidget(_wrapProviderDashboard(_signedInDriver()));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Espace fournisseur'), findsOneWidget);
      },
    );
  });

  group('J-3 — effet FR/EN/ES sur écran critique (AuthScreen)', () {
    for (final locale in ['fr', 'en', 'es']) {
      testWidgets(
        'J-3 : AuthScreen ($locale) — aucun overflow à 320px (largeur '
        'minimale, texte le plus contraignant)',
        (tester) async {
          _setViewport(tester, 320, 800);

          await tester.pumpWidget(_wrapAuthScreen(locale: locale));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(
            find.text(AppStrings.t('auth_welcome', locale)),
            findsOneWidget,
          );
          expect(
            find.text(AppStrings.t('auth_choose_role', locale)),
            findsOneWidget,
          );
        },
      );
    }
  });

  group('J-4 — clavier/formulaires (AuthScreen, inscription)', () {
    testWidgets(
      'J-4 : formulaire inscription complet (nom + courriel + mot de passe) '
      'reste scrollable et le CTA "Créer mon compte" reste accessible sous '
      'espace vertical réduit (clavier virtuel simulé, hauteur 320px)',
      (tester) async {
        // Hauteur réduite pour simuler un clavier virtuel occupant une
        // grande partie de l'écran (ex: iPhone SE, clavier ouvert) — plus
        // contraignant qu'une simple variation de viewInsets, et prouve
        // directement que le contenu reste atteignable par scroll.
        _setViewport(tester, 375, 320);

        await tester.pumpWidget(_wrapAuthScreen(locale: 'fr'));
        await tester.pumpAndSettle();

        // Bascule en mode "Créer un compte" pour afficher tous les champs
        // (nom, courriel, mot de passe) + le CTA final.
        await tester.ensureVisible(find.text('Créer un compte'));
        await tester.tap(find.text('Créer un compte'));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Les 3 champs doivent tous pouvoir être atteints par scroll, sans
        // exception (ensureVisible échoue si le widget est hors de
        // l'arbre ou si le scroll ne peut pas l'amener à l'écran).
        for (final finder in [
          find.byType(TextField).at(0),
          find.byType(TextField).at(1),
          find.byType(TextField).at(2),
        ]) {
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        // Le CTA final doit rester atteignable par scroll (pas caché sous
        // le clavier simulé sans possibilité de scroll).
        final ctaFinder = find.text('Créer mon compte');
        await tester.ensureVisible(ctaFinder);
        await tester.pumpAndSettle();
        expect(ctaFinder, findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('J-5 — modals/dialogs (SafetyScreen, dialog de signalement)', () {
    testWidgets(
      'J-5 : dialog "Signaler un problème" à largeur étroite (320px) — '
      'contenu visible, champ de texte et boutons accessibles, aucun overflow',
      (tester) async {
        _setViewport(tester, 320, 700);

        await tester.pumpWidget(_wrapSafetyScreen(locale: 'fr'));
        await tester.pumpAndSettle();

        await tester.ensureVisible(find.text('Signaler un problème').first);
        await tester.tap(find.text('Signaler un problème').first);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);

        // Le dialog est bien affiché (titre + champ de texte + 2 boutons
        // d'action) et tous ses éléments sont accessibles sans overflow.
        expect(find.byType(AlertDialog), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('Annuler'), findsOneWidget);
        expect(find.text('Envoyer'), findsOneWidget);

        // Le bouton "Annuler" doit rester actionnable (ferme le dialog
        // sans exception), preuve qu'aucune action n'est cachée hors zone
        // tactile même à largeur étroite.
        await tester.tap(find.text('Annuler'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
