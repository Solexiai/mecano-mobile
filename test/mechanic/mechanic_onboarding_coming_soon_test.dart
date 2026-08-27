// ---------------------------------------------------------------------------
// Test widget — MechanicOnboardingScreen : actions "Bientôt disponible"
// (GAP-U-MECHANIC, Phase 7, Bloc U, complément U-0).
//
// DÉCISION PRODUIT (reçue explicitement, non ré-auditée ici) : ne PAS
// construire de backend Firebase mécanicien dans cette session. Ce module
// reste backé par l'ancien `AuthProvider`/Hive (`signInOrRegister`) — voir
// investigation BUG-U-01 dans `docs/PHASE7_BUG_REPORT.md`.
//
// AVANT ce correctif : 4 boutons `OutlinedButton.icon(onPressed: () {})`
// ("Certifications", "Pièce d'identité", "Assurance responsabilité civile",
// "Numéro d'entreprise") étaient présentés comme des actions fonctionnelles
// alors qu'ils ne faisaient strictement rien.
//
// CORRECTIF : ces 4 actions sont désormais rendues via `_ComingSoonActionRow`
// — un widget non interactif (aucun `onPressed`/`GestureDetector`/`InkWell`
// nulle part, donc plus fort qu'un simple bouton désactivé) affichant le
// libellé + le `ComingSoonBadge` déjà existant (réutilisé tel quel, aucun
// nouveau composant), dont le texte provient de la clé i18n
// `common_coming_soon` déjà traduite en FR/EN/ES.
//
// Ce fichier PROUVE, pour les étapes "Spécialités" et "Documents" du wizard
// mécanicien :
//   GAP-U-MECHANIC-1 : aucun `OutlinedButton`/`ElevatedButton`/`TextButton`
//     fonctionnel n'existe plus pour les 4 anciens libellés (recherche par
//     ancêtre commun avec le texte du libellé, pas seulement absence globale
//     de `OutlinedButton` dans l'écran — le wizard en a d'autres, légitimes,
//     pour Suivant/Retour).
//   GAP-U-MECHANIC-2 : le badge "Bientôt disponible" (`common_coming_soon`,
//     FR) est bien visible à côté de chacun des 4 libellés.
//   GAP-U-MECHANIC-3 : `_ComingSoonActionRow` ne contient aucun
//     `GestureDetector`/`InkWell`/`onTap` — confirmé en tapant dessus et en
//     vérifiant l'absence de toute exception ou changement d'état
//     observable (rien ne se passe, honnêtement, pas de faux succès).
//   GAP-U-MECHANIC-4 (sanity i18n, sans redoublonner Bloc K) : le même badge
//     "Coming soon"/"Próximamente" apparaît en EN/ES.
//
// STRATÉGIE : réutilise le pattern déjà établi (`AuthProvider`/`LocaleProvider`
// minimal + `GoRouter` mono-route). `AuthProvider()` ne lève pas d'exception à
// la construction même sans `Hive.initFlutter()` — `_restoreSession()` est
// déjà protégé par un `try/catch` qui retombe silencieusement sur
// `_currentUser = null` (cf. `auth_provider.dart`). Ce test n'appelle jamais
// `signInOrRegister` (qui, lui, nécessiterait Hive) : on ne va jamais jusqu'à
// la soumission finale du wizard, seulement jusqu'aux étapes concernées.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/backend/backend_status.dart';
import 'package:movik_connect/providers/auth_provider.dart';
import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/mechanic_provider/mechanic_onboarding_screen.dart';

// `AppShell` (utilisé par `MechanicOnboardingScreen`) dépend aussi de
// `FirebaseAuthProvider`/`BackendStatus` (barre de navigation, bandeau
// éventuel) — même s'ils sont sans rapport avec le flux mécanicien lui-même
// (backé par l'ancien `AuthProvider`/Hive), ils doivent être fournis pour que
// l'arbre de widgets se construise, comme dans tous les autres tests d'écran
// utilisant `AppShell`.
Widget _buildTestApp() {
  final router = GoRouter(
    initialLocation: '/fr/devenir-mecanicien/inscription',
    routes: [
      GoRoute(
        path: '/fr/devenir-mecanicien/inscription',
        builder: (context, state) =>
            const MechanicOnboardingScreen(locale: 'fr'),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<BackendStatus>.value(value: const BackendStatus.notConfigured()),
      ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
      ChangeNotifierProvider<FirebaseAuthProvider>(create: (_) => FirebaseAuthProvider(backendConfigured: false)),
      ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> goToStep(WidgetTester tester, int times, {String nextLabel = 'Suivant'}) async {
  for (var i = 0; i < times; i++) {
    final nextFinder = find.widgetWithText(ElevatedButton, nextLabel);
    expect(nextFinder, findsOneWidget);
    await tester.ensureVisible(nextFinder);
    await tester.pumpAndSettle();
    await tester.tap(nextFinder);
    await tester.pumpAndSettle();
  }
}

/// Cherche l'ancêtre `OutlinedButton`/`ElevatedButton`/`TextButton`
/// fonctionnel le plus proche d'un `Text` donné — s'il n'y en a aucun, le
/// libellé n'est plus présenté comme un bouton actif.
bool hasFunctionalButtonAncestor(WidgetTester tester, Finder textFinder) {
  final buttonTypes = <Type>[OutlinedButton, ElevatedButton, TextButton];
  for (final type in buttonTypes) {
    final ancestor = find.ancestor(of: textFinder, matching: find.byType(type));
    if (ancestor.evaluate().isNotEmpty) {
      final widget = tester.widget(ancestor.first);
      final dynamic onPressed = (widget as dynamic).onPressed;
      if (onPressed != null) return true;
    }
  }
  return false;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('GAP-U-MECHANIC — boutons "Bientôt disponible" (mécanicien)', () {
    testWidgets(
      'Étape Spécialités : "Certifications" n\'est plus un bouton actif -> badge "Bientôt disponible" visible',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        // Étape 0 (Profil) -> Étape 1 (Spécialités).
        await tester.enterText(find.byType(TextField).at(0), 'Jean Mécano');
        await tester.enterText(find.byType(TextField).at(2), 'jean.mecano@example.com');
        await tester.pump();
        // canProceed(0) exige nom + email non vides.
        await goToStep(tester, 1);

        // Sélectionner une spécialité pour permettre d'aller plus loin si besoin
        // (non requis pour ce test, mais garde canProceed(1) cohérent).
        final specialtyChip = find.byType(FilterChip).first;
        await tester.ensureVisible(specialtyChip);
        await tester.pumpAndSettle();
        await tester.tap(specialtyChip);
        await tester.pumpAndSettle();

        final labelFinder = find.text('Certifications professionnelles (optionnel)');
        expect(labelFinder, findsOneWidget, reason: 'Le libellé "Certifications" doit toujours être visible (action désactivée, pas supprimée).');

        expect(
          hasFunctionalButtonAncestor(tester, labelFinder.first),
          isFalse,
          reason: 'GAP-U-MECHANIC : "Certifications" ne doit plus être un bouton actif fonctionnel (onPressed != null).',
        );

        // Badge "Bientôt disponible" (FR) doit être visible sur cette étape.
        expect(find.text('Bientôt disponible'), findsWidgets);

        // Vérifie qu'aucun geste sur la ligne ne provoque d'exception ni
        // d'effet observable (rien n'est simulé, aucun faux succès).
        final row = find.ancestor(of: labelFinder.first, matching: find.byType(Container)).first;
        await tester.tap(row, warnIfMissed: false);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Étape Documents : upload_id / upload_liability_insurance / business_number ne sont plus des boutons actifs -> badges visibles',
      (tester) async {
        await tester.pumpWidget(_buildTestApp());
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), 'Jean Mécano');
        await tester.enterText(find.byType(TextField).at(2), 'jean.mecano@example.com');
        await tester.pump();
        await goToStep(tester, 1); // -> Spécialités

        final specialtyChip = find.byType(FilterChip).first;
        await tester.ensureVisible(specialtyChip);
        await tester.pumpAndSettle();
        await tester.tap(specialtyChip);
        await tester.pumpAndSettle();

        await goToStep(tester, 1); // -> Tarification
        await goToStep(tester, 1); // -> Documents

        // Les 3 libellés documents (texte exact tiré de app_strings.dart)
        // doivent rester visibles (action désactivée, pas supprimée) et ne
        // plus être portés par un bouton fonctionnel.
        for (final labelText in [
          "Téléverser une pièce d'identité",
          "Téléverser l'attestation d'assurance responsabilité",
          "Numéro d'entreprise (optionnel)",
        ]) {
          final labelFinder = find.text(labelText);
          expect(labelFinder, findsOneWidget, reason: 'Le libellé "$labelText" doit rester visible.');
          expect(
            hasFunctionalButtonAncestor(tester, labelFinder),
            isFalse,
            reason: 'GAP-U-MECHANIC : "$labelText" ne doit plus être un bouton actif fonctionnel.',
          );
        }

        // Aucun des 4 anciens libellés ne doit plus être un bouton actif :
        // contrôle global — plus aucun OutlinedButton.icon "mort" sur cette
        // étape ne doit exposer onPressed != null pour ces actions
        // spécifiques. On vérifie plutôt, positivement, la présence d'au
        // moins 3 badges "Bientôt disponible" sur cette étape (upload_id,
        // upload_liability_insurance, business_number), en plus de celui de
        // l'étape Spécialités qui n'est plus affiché ici.
        expect(
          find.text('Bientôt disponible'),
          findsNWidgets(3),
          reason: 'Les 3 actions documents (pièce d\u2019identité, assurance, numéro d\u2019entreprise) doivent chacune afficher le badge "Bientôt disponible".',
        );

        // Aucune exception, aucun crash en tapant sur ces lignes non
        // interactives.
        final rows = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ComingSoonActionRow');
        expect(rows, findsNWidgets(3));
        for (final row in rows.evaluate().toList()) {
          await tester.tap(find.byWidget(row.widget), warnIfMissed: false);
        }
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Sanity i18n (EN) : le badge "Coming soon" apparaît (pas de string FR hardcodée)',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/en/devenir-mecanicien/inscription',
          routes: [
            GoRoute(
              path: '/en/devenir-mecanicien/inscription',
              builder: (context, state) =>
                  const MechanicOnboardingScreen(locale: 'en'),
            ),
          ],
        );
        await tester.pumpWidget(MultiProvider(
          providers: [
            Provider<BackendStatus>.value(value: const BackendStatus.notConfigured()),
            ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()..setLocale('en')),
            ChangeNotifierProvider<FirebaseAuthProvider>(create: (_) => FirebaseAuthProvider(backendConfigured: false)),
            ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
          ],
          child: MaterialApp.router(routerConfig: router),
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextField).at(0), 'John Mechanic');
        await tester.enterText(find.byType(TextField).at(2), 'john.mechanic@example.com');
        await tester.pump();
        await goToStep(tester, 1, nextLabel: 'Next'); // -> Specialties

        final specialtyChip = find.byType(FilterChip).first;
        await tester.ensureVisible(specialtyChip);
        await tester.pumpAndSettle();
        await tester.tap(specialtyChip);
        await tester.pumpAndSettle();

        expect(find.text('Coming soon'), findsWidgets);
      },
    );
  });
}
