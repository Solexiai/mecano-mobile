// Bloc F (Phase 7) — ROUTING / DEEP LINKS — "ROUTES INVALIDES" checklist.
//
// Empirically verifies that `AppRouter.router` (the real, global GoRouter
// singleton used by the app) has no `errorBuilder`/`onUnknownRoute` defined,
// yet still handles every category of malformed/unknown/nonexistent-resource
// route gracefully:
//   - genuinely unmatched paths fall through to GoRouter's built-in
//     `MaterialErrorScreen` default (title "Page Not Found" + Home button),
//     since this app renders via `MaterialApp.router` (isMaterialApp == true).
//   - paths that DO match a route, but reference a missing/invalid/foreign
//     resource id, are handled by each destination screen's OWN pre-existing
//     null-check / role-gate / default-case logic.
//
// In every scenario below: no blank screen, no unhandled exception, no
// redirect loop, no permission leak.
//
// IMPORTANT (test harness note): the full `main.dart` provider tree cannot be
// used inside `flutter test` because `DeliveryProvider`/`AuthProvider`/
// `ReviewProvider` transitively call `StorageService.init()` ->
// `Hive.initFlutter()`, which hangs indefinitely under the flutter_test VM
// (no `path_provider` platform channel mock configured in this project).
// Router-level tests must therefore use the SAME restricted provider set as
// `driver_active_mission_status_gaps_test.dart` /
// `customer_tracking_screen_auth_test.dart`: only `BackendStatus`,
// `LocaleProvider`, and `FirebaseAuthProvider` — never the full app tree.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/router/app_router.dart';
import 'package:movik_connect/screens/auth/admin_login_screen.dart';

Widget _wrap(FirebaseAuthProvider auth, {BackendStatus? backendStatus}) {
  return MultiProvider(
    providers: [
      Provider<BackendStatus>.value(
        value: backendStatus ?? const BackendStatus.notConfigured(),
      ),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
    ],
    child: MaterialApp.router(routerConfig: AppRouter.router),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Bloc F — routes invalides / paramètres invalides', () {
    testWidgets(
      'ROUTE-F-01: route totalement inconnue -> fallback GoRouter par défaut (Page Not Found), pas décran blanc, pas exception',
      (tester) async {
        AppRouter.router.go('/fr/route-qui-nexiste-pas');
        final auth = FirebaseAuthProvider(backendConfigured: false);
        await tester.pumpWidget(_wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Page Not Found'), findsOneWidget);
        expect(find.text('Home'), findsOneWidget);
      },
    );

    testWidgets(
      'ROUTE-F-02: paramètre missionId manquant (trailing slash) sur /livraison/suivi/ -> fallback propre, pas décran blanc',
      (tester) async {
        AppRouter.router.go('/fr/livraison/suivi/');
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = 'customer_x';
        await tester.pumpWidget(_wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // The empty required :missionId segment does not match the
        // parameterized route -> GoRouter's default error screen renders.
        expect(find.text('Page Not Found'), findsOneWidget);
      },
    );

    testWidgets(
      'ROUTE-F-03: /admin/chauffeurs/ (trailing slash, connecté sans rôle privilégié) -> AdminAuthGate redirige vers AdminLoginScreen, aucune fuite de la liste chauffeurs',
      (tester) async {
        AppRouter.router.go('/fr/admin/chauffeurs/');
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceRoles = <PlatformRole>[];
        await tester.pumpWidget(_wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        // Role gate correctly denies access -> AdminLoginScreen, not the
        // drivers list (no permission leak).
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.text('Administration Movi-K'), findsOneWidget);
      },
    );

    testWidgets(
      'ROUTE-F-04: /legal/:type malformé (type inconnu) -> LegalScreen retombe sur son cas "default" (politique de confidentialité), pas décran blanc',
      (tester) async {
        AppRouter.router.go('/fr/legal/does-not-exist-type');
        final auth = FirebaseAuthProvider(backendConfigured: false);
        await tester.pumpWidget(_wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Politique de confidentialité'), findsWidgets);
      },
    );

    testWidgets(
      'ROUTE-F-05: mission chauffeur inexistante (/provider/mission/:id) -> message "introuvable", pas décran blanc',
      (tester) async {
        AppRouter.router.go('/fr/provider/mission/does-not-exist');
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = 'driver_x';
        await tester.pumpWidget(_wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppStrings.t('driver_active_mission_not_found', 'fr')),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'ROUTE-F-06: mission client inexistante (/livraison/suivi/:id) -> message "introuvable", pas décran blanc',
      (tester) async {
        AppRouter.router.go('/fr/livraison/suivi/does-not-exist-mission');
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceUid = 'customer_x';
        await tester.pumpWidget(_wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AppStrings.t('driver_active_mission_not_found', 'fr')),
          findsOneWidget,
        );
      },
    );
  });
}
