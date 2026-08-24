// ---------------------------------------------------------------------------
// Phase 7, Bloc C, ACTION 1 — BUG-003, occurrence DriverOnboarding.
//
// BUG-003 (déjà corrigé sur DeliveryRequestFlowScreen, Bloc B) : `canProceed
// (step)` lisait `.text` de `TextEditingController`s branchés sur des
// `TextField` SANS `onChanged` déclenchant un `setState()` parent -> le
// bouton "Suivant" pouvait rester figé désactivé selon l'ordre de saisie.
//
// Root-cause CONFIRMÉ identique sur `DriverOnboardingScreen`, étape 0
// (Profil) : `canProceed(0)` lit `_nameController.text` /
// `_emailController.text` / `_passwordController.text`, et les 3 `TextField`
// correspondants n'avaient AUCUN `onChanged`. Test de diagnostic initial :
// FAIL (bouton "Suivant" resté `onPressed == null` malgré une saisie
// complète et valide des 3 champs, sans aucune autre action `setState`
// intercalée).
//
// CORRECTIF appliqué (identique au pattern BUG-003 du Bloc B) : ajout de
// `onChanged: (_) => setState(() {})` sur les 3 `TextField` concernés
// (nom, email, password). Aucun nouveau BUG-004 créé — même root-cause,
// documenté comme "BUG-003 — occurrence DriverOnboarding" dans
// PHASE7_BUG_REPORT.md.
//
// Ce fichier est désormais le test anti-régression permanent pour cette
// occurrence : DOIT rester PASS.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/driver/driver_onboarding_screen.dart';

Widget _buildTestApp(FirebaseAuthProvider auth) {
  final router = GoRouter(
    initialLocation: '/fr/devenir-chauffeur/inscription',
    routes: [
      GoRoute(
        path: '/fr/devenir-chauffeur/inscription',
        builder: (context, state) =>
            const DriverOnboardingScreen(locale: 'fr'),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>.value(value: auth),
      Provider<BackendStatus>.value(
        value: const BackendStatus.notConfigured(),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  late FirebaseAuthProvider auth;

  setUp(() {
    auth = FirebaseAuthProvider(backendConfigured: false);
  });

  Future<void> enterTextEnsuringVisible(
    WidgetTester tester,
    Finder finder,
    String text,
  ) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.enterText(finder, text);
    await tester.pump();
  }

  testWidgets(
    'BUG-003 (occurrence DriverOnboarding) — étape 0 (Profil) : saisir '
    'nom+email+password sans autre setState active "Suivant"',
    (WidgetTester tester) async {
      await tester.pumpWidget(_buildTestApp(auth));
      await tester.pumpAndSettle();

      // Les TextField de l'étape 0, dans l'ordre déclaré par
      // DriverOnboardingScreen : nom, email, password, phone, city.
      final nameField = find.byType(TextField).at(0);
      final emailField = find.byType(TextField).at(1);
      final passwordField = find.byType(TextField).at(2);

      await enterTextEnsuringVisible(tester, nameField, 'Jean Tremblay');
      await enterTextEnsuringVisible(
        tester,
        emailField,
        'jean.tremblay@example.com',
      );
      await enterTextEnsuringVisible(tester, passwordField, 'motdepasse123');

      final nextButtonFinder = find.widgetWithText(ElevatedButton, 'Suivant');
      expect(nextButtonFinder, findsOneWidget);
      await tester.ensureVisible(nextButtonFinder);
      await tester.pumpAndSettle();

      final nextButton = tester.widget<ElevatedButton>(nextButtonFinder);

      // Test anti-régression BUG-003 (occurrence DriverOnboarding) : le
      // bouton doit être actif après saisie complète et valide des 3
      // champs, sans dépendre d'un setState externe (chip/slider).
      expect(
        nextButton.onPressed,
        isNotNull,
        reason:
            'Régression BUG-003 (occurrence DriverOnboarding) : les '
            "TextField de l'étape 0 ne déclenchent plus de rebuild parent, "
            'canProceed(0) reste figé sur son évaluation initiale (false).',
      );
    },
  );
}
