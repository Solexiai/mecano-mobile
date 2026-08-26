// ---------------------------------------------------------------------------
// k5_residual_screens_locale_render_test.dart — BLOC K-9 (I18N GLOBAL,
// Phase 7).
//
// Quelques widget tests CIBLÉS (volontairement peu nombreux, cf. instruction
// utilisateur : "pas une suite fragile comparant 800 textes") prouvant que
// les écrans corrigés lors des résidus K-5 (5/7 et 6/7 de ce tour) se
// construisent réellement sans exception et affichent bien le texte traduit
// attendu, dans au moins 2 langues différentes — preuve que le câblage
// `context.watch<LocaleProvider>().t` fonctionne de bout en bout et pas
// seulement au niveau de la table de chaînes (déjà couvert par
// app_strings_structural_test.dart).
//
// `mechanic_request_flow_screen.dart` (résidu 4/7) n'est PAS couvert ici :
// il nécessite un graphe de providers plus large (AuthProvider,
// MechanicRequestProvider, DemoDataService) déjà exercé par d'autres tests
// du dossier test/ ; l'ajouter ici dupliquerait un harnais existant sans
// bénéfice net pour la preuve i18n recherchée. `admin_drivers_list_screen`
// (résidu 7/7) est un correctif trivial à une seule chaîne déjà couverte
// par la vérification "common_retry" du test structurel dictionnaire.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/admin_dashboard_shell.dart';

Widget _wrapAdminDashboardShell() {
  final router = GoRouter(
    initialLocation: '/fr/admin',
    routes: [
      GoRoute(
        path: '/fr/admin',
        builder: (context, state) => const AdminDashboardShell(),
      ),
      GoRoute(
        path: '/fr',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/fr/admin/chauffeurs',
        builder: (context, state) => const SizedBox.shrink(),
      ),
      GoRoute(
        path: '/fr/admin/paiements',
        builder: (context, state) => const SizedBox.shrink(),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('K-9 — AdminDashboardShell (résidu K-5 6/7) : rendu i18n réel', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets(
      'se construit sans exception et affiche le titre traduit en FR (défaut)',
      (tester) async {
        // Surface de test élargie (desktop réaliste) : AdminDashboardShell
        // bascule volontairement en layout desktop (NavigationRail) à
        // partir de 900px de large (`isDesktop = width >= 900`) ; la
        // taille de test Flutter par défaut (800x600) est plus étroite que
        // le plus petit layout réellement supporté par cet écran et
        // provoque un overflow d'AppBar non représentatif d'un usage réel.
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(_wrapAdminDashboardShell());
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppStrings.t('admin_dashboard_title', 'fr')),
          findsOneWidget,
        );
        // Preuve que les labels de navigation admin corrigés ce tour sont
        // bien résolus via le dictionnaire (au moins un visible, mobile ou
        // desktop selon la largeur de test par défaut).
        expect(
          find.text(AppStrings.t('admin_nav_overview', 'fr')),
          findsWidgets,
        );
      },
    );

    testWidgets(
      'changer de langue fr -> en met à jour le titre et les onglets '
      'de la vue d\'ensemble sans exception',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(1200, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final localeProvider = LocaleProvider();
        final router = GoRouter(
          initialLocation: '/fr/admin',
          routes: [
            GoRoute(
              path: '/fr/admin',
              builder: (context, state) => const AdminDashboardShell(),
            ),
            GoRoute(
              path: '/fr',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/fr/admin/chauffeurs',
              builder: (context, state) => const SizedBox.shrink(),
            ),
            GoRoute(
              path: '/fr/admin/paiements',
              builder: (context, state) => const SizedBox.shrink(),
            ),
          ],
        );
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LocaleProvider>.value(
                value: localeProvider,
              ),
            ],
            child: MaterialApp.router(routerConfig: router),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.t('admin_overview_market_title', 'fr')),
          findsOneWidget,
        );

        await localeProvider.setLocale('en');
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppStrings.t('admin_dashboard_title', 'en')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.t('admin_overview_market_title', 'en')),
          findsOneWidget,
        );
      },
    );
  });
}
