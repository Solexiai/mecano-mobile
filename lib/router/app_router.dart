import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/home/home_screen.dart';
import '../screens/delivery/delivery_landing_screen.dart';
import '../screens/delivery/delivery_request_flow_screen.dart';
import '../screens/mechanic/mechanic_landing_screen.dart';
import '../screens/mechanic/mechanic_request_flow_screen.dart';
import '../screens/driver/driver_landing_screen.dart';
import '../screens/driver/driver_onboarding_screen.dart';
import '../screens/driver/driver_status_screen.dart';
import '../screens/driver/driver_stripe_onboarding_return_screen.dart';
import '../screens/driver/driver_active_mission_screen.dart';
import '../screens/customer/customer_tracking_screen.dart';
import '../screens/mechanic_provider/mechanic_provider_landing_screen.dart';
import '../screens/mechanic_provider/mechanic_onboarding_screen.dart';
import '../screens/auth/auth_screen.dart';
import '../screens/auth/admin_login_screen.dart';
import '../screens/info/pricing_screen.dart';
import '../screens/info/how_it_works_screen.dart';
import '../screens/info/safety_screen.dart';
import '../screens/info/faq_screen.dart';
import '../screens/info/about_screen.dart';
import '../screens/info/contact_screen.dart';
import '../screens/info/blog_screen.dart';
import '../screens/legal/legal_screen.dart';
import '../screens/dashboard/customer/customer_dashboard_shell.dart';
import '../screens/dashboard/provider/provider_dashboard_shell.dart';
import '../screens/dashboard/admin/admin_dashboard_shell.dart';
import '../screens/dashboard/admin/drivers/admin_drivers_list_screen.dart';
import '../screens/dashboard/admin/drivers/admin_driver_detail_screen.dart';
import '../screens/dashboard/admin/finance/admin_finance_shell.dart';

/// Bloc 8B LIVE — lit un `initialTabIndex` optionnel passé via
/// `GoRouterState.extra` (ex. depuis `DriverStripeOnboardingReturnScreen`,
/// qui navigue avec `extra: {'initialTabIndex': 3}` pour rouvrir
/// directement l'onglet Profil, où vit `ProviderStripeConnectSection`,
/// plutôt que l'onglet par défaut). Défaut `0` si absent/invalide —
/// comportement identique à avant pour tout appelant qui ne le fournit pas
/// (ex. navigation directe vers `/fournisseur/tableau-de-bord` depuis un
/// lien favori, sans `extra`).
int _extraInitialTabIndex(Object? extra) {
  if (extra is Map && extra['initialTabIndex'] is int) {
    return extra['initialTabIndex'] as int;
  }
  return 0;
}

/// Locale-prefixed routing (/fr, /en, /es) as required for SEO-friendly
/// multilingual URLs. The locale segment is informational for routing;
/// actual UI text uses LocaleProvider state (kept in sync on route change).
class AppRouter {
  AppRouter._();

  static const supportedLocales = ['fr', 'en', 'es'];

  static final GoRouter router = GoRouter(
    initialLocation: '/fr',
    routes: [
      GoRoute(path: '/', redirect: (context, state) => '/fr'),
      ...supportedLocales.map(
        (loc) => GoRoute(
          path: '/$loc',
          builder: (context, state) => HomeScreen(locale: loc),
          routes: [
            GoRoute(
              path: 'livraison',
              builder: (c, s) => DeliveryLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'delivery',
              builder: (c, s) => DeliveryLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'entrega',
              builder: (c, s) => DeliveryLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'livraison/demande',
              builder: (c, s) => DeliveryRequestFlowScreen(locale: loc),
            ),
            GoRoute(
              path: 'delivery/request',
              builder: (c, s) => DeliveryRequestFlowScreen(locale: loc),
            ),
            GoRoute(
              path: 'entrega/solicitud',
              builder: (c, s) => DeliveryRequestFlowScreen(locale: loc),
            ),

            GoRoute(
              path: 'mecanique-mobile',
              builder: (c, s) => MechanicLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'mobile-mechanic',
              builder: (c, s) => MechanicLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'mecanico-movil',
              builder: (c, s) => MechanicLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'mecanique-mobile/demande',
              builder: (c, s) => MechanicRequestFlowScreen(locale: loc),
            ),
            GoRoute(
              path: 'mobile-mechanic/request',
              builder: (c, s) => MechanicRequestFlowScreen(locale: loc),
            ),
            GoRoute(
              path: 'mecanico-movil/solicitud',
              builder: (c, s) => MechanicRequestFlowScreen(locale: loc),
            ),

            GoRoute(
              path: 'devenir-chauffeur',
              builder: (c, s) => DriverLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'become-driver',
              builder: (c, s) => DriverLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'convertirse-conductor',
              builder: (c, s) => DriverLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'devenir-chauffeur/inscription',
              builder: (c, s) => DriverOnboardingScreen(locale: loc),
            ),
            GoRoute(
              path: 'become-driver/onboarding',
              builder: (c, s) => DriverOnboardingScreen(locale: loc),
            ),
            GoRoute(
              path: 'devenir-chauffeur/statut',
              builder: (c, s) => DriverStatusScreen(locale: loc),
            ),
            GoRoute(
              path: 'become-driver/status',
              builder: (c, s) => DriverStatusScreen(locale: loc),
            ),
            GoRoute(
              path: 'convertirse-conductor/estado',
              builder: (c, s) => DriverStatusScreen(locale: loc),
            ),

            GoRoute(
              path: 'devenir-mecanicien',
              builder: (c, s) => MechanicProviderLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'become-mechanic',
              builder: (c, s) => MechanicProviderLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'convertirse-mecanico',
              builder: (c, s) => MechanicProviderLandingScreen(locale: loc),
            ),
            GoRoute(
              path: 'devenir-mecanicien/inscription',
              builder: (c, s) => MechanicOnboardingScreen(locale: loc),
            ),
            GoRoute(
              path: 'become-mechanic/onboarding',
              builder: (c, s) => MechanicOnboardingScreen(locale: loc),
            ),

            GoRoute(
              path: 'connexion',
              builder: (c, s) => AuthScreen(locale: loc),
            ),
            GoRoute(
              path: 'sign-in',
              builder: (c, s) => AuthScreen(locale: loc),
            ),
            GoRoute(
              path: 'iniciar-sesion',
              builder: (c, s) => AuthScreen(locale: loc),
            ),

            GoRoute(
              path: 'tarifs',
              builder: (c, s) => PricingScreen(locale: loc),
            ),
            GoRoute(
              path: 'pricing',
              builder: (c, s) => PricingScreen(locale: loc),
            ),
            GoRoute(
              path: 'precios',
              builder: (c, s) => PricingScreen(locale: loc),
            ),

            GoRoute(
              path: 'comment-ca-marche',
              builder: (c, s) => HowItWorksScreen(locale: loc),
            ),
            GoRoute(
              path: 'how-it-works',
              builder: (c, s) => HowItWorksScreen(locale: loc),
            ),
            GoRoute(
              path: 'como-funciona',
              builder: (c, s) => HowItWorksScreen(locale: loc),
            ),

            GoRoute(
              path: 'securite',
              builder: (c, s) => SafetyScreen(locale: loc),
            ),
            GoRoute(
              path: 'safety',
              builder: (c, s) => SafetyScreen(locale: loc),
            ),
            GoRoute(
              path: 'seguridad',
              builder: (c, s) => SafetyScreen(locale: loc),
            ),

            GoRoute(
              path: 'faq',
              builder: (c, s) => FaqScreen(locale: loc),
            ),
            GoRoute(
              path: 'a-propos',
              builder: (c, s) => AboutScreen(locale: loc),
            ),
            GoRoute(
              path: 'about',
              builder: (c, s) => AboutScreen(locale: loc),
            ),
            GoRoute(
              path: 'acerca-de',
              builder: (c, s) => AboutScreen(locale: loc),
            ),
            GoRoute(
              path: 'contact',
              builder: (c, s) => ContactScreen(locale: loc),
            ),
            GoRoute(
              path: 'contacto',
              builder: (c, s) => ContactScreen(locale: loc),
            ),
            GoRoute(
              path: 'blogue',
              builder: (c, s) => BlogScreen(locale: loc),
            ),
            GoRoute(
              path: 'blog',
              builder: (c, s) => BlogScreen(locale: loc),
            ),

            GoRoute(
              path: 'legal/:type',
              builder: (c, s) =>
                  LegalScreen(locale: loc, type: s.pathParameters['type']!),
            ),

            GoRoute(
              path: 'tableau-de-bord',
              builder: (c, s) => const CustomerDashboardShell(),
            ),
            GoRoute(
              path: 'dashboard',
              builder: (c, s) => const CustomerDashboardShell(),
            ),
            GoRoute(
              path: 'panel',
              builder: (c, s) => const CustomerDashboardShell(),
            ),

            // Suivi GPS temps réel du chauffeur (Phase 5) — route dédiée
            // côté client, paramétrée par missionId, symétrique de
            // `fournisseur/mission/:missionId` côté chauffeur.
            GoRoute(
              path: 'livraison/suivi/:missionId',
              builder: (c, s) => CustomerTrackingScreen(
                missionId: s.pathParameters['missionId']!,
              ),
            ),
            GoRoute(
              path: 'delivery/track/:missionId',
              builder: (c, s) => CustomerTrackingScreen(
                missionId: s.pathParameters['missionId']!,
              ),
            ),
            GoRoute(
              path: 'entrega/seguimiento/:missionId',
              builder: (c, s) => CustomerTrackingScreen(
                missionId: s.pathParameters['missionId']!,
              ),
            ),

            GoRoute(
              path: 'fournisseur/tableau-de-bord',
              builder: (c, s) => ProviderDashboardShell(
                initialTabIndex: _extraInitialTabIndex(s.extra),
              ),
            ),
            GoRoute(
              path: 'provider/dashboard',
              builder: (c, s) => ProviderDashboardShell(
                initialTabIndex: _extraInitialTabIndex(s.extra),
              ),
            ),

            // Bloc 8B LIVE (gap fermé AVANT onboarding Stripe LIVE) — routes
            // de retour Stripe Connect. Stripe redirige le navigateur du
            // chauffeur ici après l'onboarding hébergé (voir
            // `functions/src/payment/stripeProvider.ts::createDriverAccount`,
            // `return_url`/`refresh_url`, et `functions/src/lib/appConfig.ts`
            // pour le domaine public réellement branché côté Cloud Functions).
            // FR/EN/ES : mêmes chemins que le reste de l'app (préfixe
            // `/fr|/en|/es` déjà géré par `supportedLocales.map(...)`
            // ci-dessus) ; la Cloud Function utilise systématiquement le
            // préfixe `/fr` par défaut (Stripe n'a pas connaissance de la
            // langue du chauffeur), et cet écran affiche ensuite dans la
            // langue réellement active de l'app (`LocaleProvider`).
            GoRoute(
              path: 'chauffeur/onboarding/complete',
              builder: (c, s) => DriverStripeOnboardingReturnScreen(
                locale: loc,
                mode: DriverStripeOnboardingReturnMode.complete,
              ),
            ),
            GoRoute(
              path: 'driver/onboarding/complete',
              builder: (c, s) => DriverStripeOnboardingReturnScreen(
                locale: loc,
                mode: DriverStripeOnboardingReturnMode.complete,
              ),
            ),
            GoRoute(
              path: 'conductor/incorporacion/completado',
              builder: (c, s) => DriverStripeOnboardingReturnScreen(
                locale: loc,
                mode: DriverStripeOnboardingReturnMode.complete,
              ),
            ),
            GoRoute(
              path: 'chauffeur/onboarding/refresh',
              builder: (c, s) => DriverStripeOnboardingReturnScreen(
                locale: loc,
                mode: DriverStripeOnboardingReturnMode.refresh,
              ),
            ),
            GoRoute(
              path: 'driver/onboarding/refresh',
              builder: (c, s) => DriverStripeOnboardingReturnScreen(
                locale: loc,
                mode: DriverStripeOnboardingReturnMode.refresh,
              ),
            ),
            GoRoute(
              path: 'conductor/incorporacion/reintentar',
              builder: (c, s) => DriverStripeOnboardingReturnScreen(
                locale: loc,
                mode: DriverStripeOnboardingReturnMode.refresh,
              ),
            ),

            // Mission Active Chauffeur — route dédiée (paramétrée par
            // missionId), distincte du shell à onglets : une mission
            // active est un contexte de navigation ponctuel, pas un onglet
            // persistant.
            GoRoute(
              path: 'fournisseur/mission/:missionId',
              builder: (c, s) => DriverActiveMissionScreen(
                missionId: s.pathParameters['missionId']!,
              ),
            ),
            GoRoute(
              path: 'provider/mission/:missionId',
              builder: (c, s) => DriverActiveMissionScreen(
                missionId: s.pathParameters['missionId']!,
              ),
            ),

            // Portail admin — architecture forward-compatible : `/admin` est
            // le tableau de bord (résumé), et chaque domaine métier a sa
            // propre route dédiée en enfant, ex. `admin/chauffeurs`.
            // Prévu pour accueillir prochainement (sans casser cette
            // structure) : admin/missions, admin/paiements, admin/pricing,
            // admin/founding-drivers, admin/analytics.
            GoRoute(
              path: 'admin',
              builder: (c, s) =>
                  const AdminAuthGate(child: AdminDashboardShell()),
              routes: [
                GoRoute(
                  path: 'chauffeurs',
                  builder: (c, s) => const AdminAuthGate(
                    child: Scaffold(body: AdminDriversListScreen()),
                  ),
                  routes: [
                    GoRoute(
                      path: ':driverId',
                      builder: (c, s) => AdminAuthGate(
                        child: AdminDriverDetailScreen(
                          driverId: s.pathParameters['driverId']!,
                        ),
                      ),
                    ),
                  ],
                ),
                GoRoute(
                  path: 'paiements',
                  builder: (c, s) =>
                      const AdminAuthGate(child: AdminFinanceShell()),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}
