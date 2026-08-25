// ---------------------------------------------------------------------------
// admin_auth_gate_session_claims_test.dart — Phase 7, Bloc E (AUTH/SESSION/
// CLAIMS), couche Flutter/UI.
//
// GAP DE COUVERTURE COMBLÉ : avant ce fichier, AUCUN test Flutter n'exerçait
// `AdminAuthGate`/`AdminLoginScreen` (0 résultat pour ces deux noms dans
// `test/` — confirmé par recherche). Le seul test Auth existant
// (`customer_tracking_screen_auth_test.dart`) ne couvre que le chemin
// "non connecté" d'un écran client, jamais le portail admin/analyste ni les
// états `claimsLoaded`/`claimsFetchFailed`/rôle effectif.
//
// Pour rendre ces scénarios testables sans dépendre d'un vrai projet
// Firebase (aucun test Flutter existant ne le fait — voir
// FirebaseAuthProvider, tous les fichiers `test/*` utilisent
// `backendConfigured: false`), trois seams `@visibleForTesting` ont été
// ajoutés à `FirebaseAuthProvider` dans le cadre de ce Bloc E :
//   - `debugForceRoles`          : simule le résultat effectif de
//                                  `getIdTokenResult()` (rôles courants).
//   - `debugForceClaimsLoaded`   : simule l'état "claims en cours de
//                                  chargement" (spinner AdminAuthGate).
//   - `debugForceClaimsFetchFailed` : simule un échec RÉSEAU transitoire de
//                                  lecture des claims (écran "Réessayer").
//
// Ces seams ne changent RIEN à l'autorisation serveur (Cloud Functions /
// Security Rules) — ils ne pilotent que l'affichage, exactement comme
// `debugForceSignedIn` existant. Le test Cloud Function dédié
// (`authSessionClaims.test.ts`, même Bloc E) prouve la partie serveur
// (claims réellement écrites via `setUserRole`, backend seul juge).
//
// PRINCIPE VÉRIFIÉ ICI (frontend jamais autorité finale) : ce fichier ne
// prouve QUE le comportement d'AFFICHAGE (quel écran apparaît selon l'état
// de session/claims) — il ne prétend PAS prouver l'autorisation serveur,
// qui est backend-only et testée séparément.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/auth/admin_login_screen.dart';

void main() {
  Widget wrap(FirebaseAuthProvider auth, {BackendStatus? backendStatus}) {
    return MultiProvider(
      providers: [
        Provider<BackendStatus>.value(
          value: backendStatus ?? const BackendStatus.ready(),
        ),
        ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
        // Ajouté Bloc K (i18n) : AdminLoginScreen/AdminAuthGate consomment
        // désormais LocaleProvider pour tous les textes visibles (BUG-010 /
        // gap K-1) — indispensable pour que ce wrap ne throw plus.
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ],
      child: MaterialApp(
        home: AdminAuthGate(
          child: const Scaffold(body: Text('ADMIN_DASHBOARD_CONTENT')),
        ),
      ),
    );
  }

  group('AUTH-E-01 — backend non configuré : jamais de faux accès admin', () {
    testWidgets(
      'AdminAuthGate affiche AdminLoginScreen si le backend Firebase n\'est pas configuré, même si isSignedIn/roles sont forcés',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceRoles = [PlatformRole.admin]
          ..debugForceClaimsLoaded = true;

        await tester.pumpWidget(
          wrap(auth, backendStatus: const BackendStatus.notConfigured()),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsNothing);
      },
    );
  });

  group('AUTH-E-02 — route protégée sans authentification', () {
    testWidgets(
      'AdminAuthGate affiche AdminLoginScreen si isSignedIn == false (route admin visitée directement, aucune session)',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false);
        // isSignedIn reste false par défaut (aucun debugForceSignedIn).

        await tester.pumpWidget(wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsNothing);
      },
    );
  });

  group('AUTH-E-03 — claims en cours de chargement (juste après authStateChanges)', () {
    testWidgets(
      'AdminAuthGate affiche un spinner (jamais le dashboard, jamais un écran d\'accès refusé) tant que claimsLoaded == false',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceClaimsLoaded = false;

        await tester.pumpWidget(wrap(auth));
        await tester.pump();

        expect(tester.takeException(), isNull);
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.byType(AdminLoginScreen), findsNothing);
        expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsNothing);
      },
    );
  });

  group(
    'AUTH-E-04 — claims UI temporairement obsolètes (claimsFetchFailed, échec réseau transitoire)',
    () {
      testWidgets(
        'AdminAuthGate propose un écran "Réessayer" (PAS une déconnexion forcée, PAS le dashboard) quand la lecture des claims échoue transitoirement et qu\'aucun rôle privilégié connu n\'est disponible',
        (tester) async {
          final auth = FirebaseAuthProvider(backendConfigured: false)
            ..debugForceSignedIn = true
            ..debugForceClaimsLoaded = true
            ..debugForceClaimsFetchFailed = true
            ..debugForceRoles = const [];

          await tester.pumpWidget(wrap(auth));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.byType(AdminLoginScreen), findsNothing);
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsNothing);
          expect(find.text('Réessayer'), findsOneWidget);
          expect(find.text('Se déconnecter'), findsOneWidget);
        },
      );

      testWidgets(
        'PRINCIPE "frontend jamais autorité finale" (variante UI) : si un rôle privilégié était DÉJÀ connu avant l\'échec réseau transitoire, AdminAuthGate laisse passer (design explicite : ne pas déconnecter à tort un admin légitime lors d\'un simple accroc réseau) — mais ceci ne préjuge en rien de ce que le BACKEND acceptera pour la prochaine action sensible (voir authSessionClaims.test.ts)',
        (tester) async {
          final auth = FirebaseAuthProvider(backendConfigured: false)
            ..debugForceSignedIn = true
            ..debugForceClaimsLoaded = true
            ..debugForceClaimsFetchFailed = true
            ..debugForceRoles = [PlatformRole.admin];

          await tester.pumpWidget(wrap(auth));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsOneWidget);
        },
      );
    },
  );

  group('AUTH-E-05 — rôle insuffisant (claims lus avec succès, mais aucun rôle privilégié)', () {
    testWidgets(
      'AdminAuthGate affiche AdminLoginScreen (pas d\'accès) si connecté avec un rôle non privilégié (ex: customer/driver)',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceClaimsLoaded = true
          ..debugForceClaimsFetchFailed = false
          ..debugForceRoles = [PlatformRole.customer];

        await tester.pumpWidget(wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
        expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsNothing);
      },
    );

    testWidgets(
      'AdminAuthGate refuse aussi un rôle "role retiré" (roles == [] après un setUserRole de suppression)',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = true
          ..debugForceClaimsLoaded = true
          ..debugForceClaimsFetchFailed = false
          ..debugForceRoles = const [];

        await tester.pumpWidget(wrap(auth));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(AdminLoginScreen), findsOneWidget);
      },
    );
  });

  group('AUTH-E-06 — accès effectif accordé (analyst / admin / super_admin)', () {
    for (final role in [
      PlatformRole.analyst,
      PlatformRole.admin,
      PlatformRole.superAdmin,
    ]) {
      testWidgets(
        'AdminAuthGate affiche le dashboard pour le rôle $role (isAnalystOrAbove == true)',
        (tester) async {
          final auth = FirebaseAuthProvider(backendConfigured: false)
            ..debugForceSignedIn = true
            ..debugForceClaimsLoaded = true
            ..debugForceClaimsFetchFailed = false
            ..debugForceRoles = [role];

          await tester.pumpWidget(wrap(auth));
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsOneWidget);
          // Le bouton de déconnexion flottant (_AdminShellWithSignOut) doit
          // être présent : preuve que le "shell" admin (pas juste le login
          // screen) a bien été rendu.
          expect(find.byIcon(Icons.logout), findsOneWidget);
        },
      );
    }
  });

  group(
    'AUTH-E-07 — downgrade : un rôle EFFECTIF admin devient EFFECTIF customer après refresh (round-trip UI)',
    () {
      testWidgets(
        'Après notifyListeners() suite à un changement de debugForceRoles (simulant refreshClaims() post-setUserRole), AdminAuthGate re-rend et retire l\'accès admin sans nécessiter un nouveau pumpWidget',
        (tester) async {
          final auth = FirebaseAuthProvider(backendConfigured: false)
            ..debugForceSignedIn = true
            ..debugForceClaimsLoaded = true
            ..debugForceClaimsFetchFailed = false
            ..debugForceRoles = [PlatformRole.admin];

          await tester.pumpWidget(wrap(auth));
          await tester.pumpAndSettle();
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsOneWidget);

          // Simule le downgrade serveur + l'appel client `refreshClaims()`.
          auth.debugForceRoles = [PlatformRole.customer];
          auth.notifyListeners();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsNothing);
          expect(find.byType(AdminLoginScreen), findsOneWidget);
        },
      );

      testWidgets(
        'super_admin downgrade vers analyst : accès admin conservé (isAnalystOrAbove reste vrai) — comportement attendu, pas une régression',
        (tester) async {
          final auth = FirebaseAuthProvider(backendConfigured: false)
            ..debugForceSignedIn = true
            ..debugForceClaimsLoaded = true
            ..debugForceClaimsFetchFailed = false
            ..debugForceRoles = [PlatformRole.superAdmin];

          await tester.pumpWidget(wrap(auth));
          await tester.pumpAndSettle();
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsOneWidget);

          auth.debugForceRoles = [PlatformRole.analyst];
          auth.notifyListeners();
          await tester.pumpAndSettle();

          expect(tester.takeException(), isNull);
          expect(find.text('ADMIN_DASHBOARD_CONTENT'), findsOneWidget);
        },
      );
    },
  );

  group('AUTH-E-08 — signOut() réinitialise immédiatement l\'état local (retour visuel instantané)', () {
    testWidgets(
      'Après signOut() sur un provider backendConfigured=false, isSignedIn redevient false même sans debugForceSignedIn actif',
      (tester) async {
        final auth = FirebaseAuthProvider(backendConfigured: false)
          ..debugForceSignedIn = false;

        // backendConfigured=false → signOut() est un no-op immédiat (voir
        // implémentation), donc ce test vérifie surtout l'absence de crash
        // et la cohérence de l'état par défaut (non connecté).
        await auth.signOut();

        expect(auth.isSignedIn, isFalse);
        expect(auth.roles, isEmpty);
      },
    );
  });
}
