// ---------------------------------------------------------------------------
// customer_tracking_screen_auth_test.dart — Phase 7, Bloc B (MIS-C-07).
//
// AVANT ce correctif : `CustomerTrackingScreen` ne vérifiait jamais
// `FirebaseAuthProvider.isSignedIn` avant de lancer `watchMission()`. Un
// accès non authentifié (lien direct copié/partagé, session expirée côté
// client sans redirection) provoquait une erreur de permission Firestore
// silencieusement transformée en message générique "erreur réseau"
// (`driver_active_mission_network_error`) — pas un crash, mais un message
// trompeur incohérent avec CustomerDashboardShell/ProviderDashboardShell/
// DriverActiveMissionScreen qui gèrent déjà ce cas explicitement.
//
// APRÈS : une garde explicite affiche un message clair
// (`tracking_locked_message`) + un bouton de connexion, AVANT même de tenter
// `watchMission()` — aucune fuite de données (firestore.rules refusait déjà
// la lecture, voir securityRules.test.ts, 196/196 verts), pure cohérence UX.
//
// Ce test ne nécessite aucun émulateur Firebase (même pattern que
// `test/finance/finance_i18n_test.dart` — `FirebaseAuthProvider(backendConfigured: false)`
// donne un provider où `isSignedIn == false` sans jamais toucher au réseau).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/customer/customer_tracking_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(
          create: (_) => FirebaseAuthProvider(backendConfigured: false),
        ),
      ],
      child: MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/fr/livraison/suivi/some-mission-id',
          routes: [
            GoRoute(
              path: '/fr/livraison/suivi/:missionId',
              builder: (c, s) => CustomerTrackingScreen(
                missionId: s.pathParameters['missionId']!,
              ),
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

  testWidgets(
    'MIS-C-07 : utilisateur NON authentifié voit le message de connexion, jamais le StreamBuilder Firestore ni de crash',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);

      // Le message dédié doit être visible (pas le message générique
      // "erreur réseau" qui apparaîtrait si watchMission() était appelé
      // sans garde et échouait par permission Firestore).
      expect(
        find.text(AppStrings.t('tracking_locked_message', 'fr')),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.t('driver_active_mission_network_error', 'fr')),
        findsNothing,
      );

      // Un bouton de connexion doit permettre de rejoindre l'écran d'auth.
      final signInButton = find.text(
        AppStrings.t('delivery_sign_in_button', 'fr'),
      );
      expect(signInButton, findsOneWidget);

      await tester.tap(signInButton);
      await tester.pumpAndSettle();

      expect(find.text('AUTH_SCREEN'), findsOneWidget);
    },
  );

  testWidgets(
    'MIS-C-07 : ne plante jamais, quelle que soit la locale (fr/en/es)',
    (tester) async {
      for (final locale in ['fr', 'en', 'es']) {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider(create: (_) => LocaleProvider()),
              ChangeNotifierProvider(
                create: (_) => FirebaseAuthProvider(backendConfigured: false),
              ),
            ],
            child: Consumer<LocaleProvider>(
              builder: (context, localeProvider, _) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (localeProvider.locale != locale) {
                    localeProvider.setLocale(locale);
                  }
                });
                return MaterialApp(
                  home: const CustomerTrackingScreen(
                    missionId: 'some-mission-id',
                  ),
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
