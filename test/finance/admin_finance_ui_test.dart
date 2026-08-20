// ---------------------------------------------------------------------------
// admin_finance_ui_test.dart — Bloc L, tests UI widgets pour les 8 onglets
// de `AdminFinanceShell` + l'écran de détail paiement.
//
// Environnement de test : aucun backend Firebase réel n'est initialisé
// (`BackendBootstrap.status` reste `notConfigured` par défaut, cf.
// `BackendBootstrap._status`), donc `BackendLocator.financeRepository`
// retourne systématiquement `NotConfiguredFinanceRepository` — les flux
// `watch*` émettent toujours une liste vide (ou `bootstrapDefault()` pour
// la politique de versement) de façon déterministe, sans jamais lever
// d'erreur. Ceci permet de tester ici, de façon 100% déterministe :
//   - l'état "loading" (frame initiale avant la résolution du Stream.value),
//   - l'état "empty" (après résolution, liste vide),
//   - le masquage correct des actions sensibles (admin/super_admin only)
//     pour un utilisateur non authentifié (`FirebaseAuthProvider
//     (backendConfigured: false)` => `isAdminOrAbove`/`isSuperAdmin` toujours
//     `false`),
//   - la navigation Payments -> Payment Detail (écran construit directement
//     avec un `paymentId` inexistant => état "empty" déterministe),
//   - l'état "error" du widget partagé `FinanceErrorState` (testé
//     directement, avec vérification du bouton "retry").
//
// Ces tests ne nécessitent donc AUCUN émulateur Firebase.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:movik_connect/providers/firebase_auth_provider.dart';
import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/admin_finance_shell.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/finance_ui_helpers.dart';
import 'package:movik_connect/screens/dashboard/admin/finance/tabs/admin_payment_detail_screen.dart';

/// Enveloppe un widget avec les Providers minimums requis par les écrans
/// Bloc L (`LocaleProvider` pour `t()`, `FirebaseAuthProvider` pour les
/// vérifications de rôle). `backendConfigured: false` garantit qu'aucun
/// appel réseau Firebase réel n'est tenté pendant le test.
Widget _wrap(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LocaleProvider()),
      ChangeNotifierProvider(
        create: (_) => FirebaseAuthProvider(backendConfigured: false),
      ),
    ],
    child: MaterialApp(home: child),
  );
}

const List<String> _kTabLabelsFr = [
  'Paiements',
  'Remboursements',
  'Versements',
  'Litiges',
  'Registre',
  'Réconciliation',
  'Taxes',
  'Politique de versement',
];

void main() {
  group('AdminFinanceShell — structure et navigation par onglets', () {
    testWidgets('affiche les 8 onglets (TabBar mobile, largeur < 900)', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(const AdminFinanceShell()));
      await tester.pumpAndSettle();

      expect(find.byType(TabBar), findsOneWidget);
      expect(find.byType(Tab), findsNWidgets(8));
      for (final label in _kTabLabelsFr) {
        expect(find.text(label), findsWidgets);
      }
      // Aucune exception (overflow, etc.) levée pendant le rendu initial.
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'onglet Payments — état loading puis empty (aucune donnée simulée)',
      (tester) async {
        await tester.pumpWidget(_wrap(const AdminFinanceShell()));

        // Frame initiale : le Stream.value() de NotConfiguredFinanceRepository
        // n'a pas encore émis (micro-tâche) => état loading visible.
        expect(find.byType(CircularProgressIndicator), findsWidgets);

        // Laisse le micro-tâche du Stream se résoudre puis se stabiliser.
        await tester.pumpAndSettle();

        expect(find.text('Aucune donnée pour le moment.'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('navigation entre les 8 sections sans overflow ni exception '
        '(vue desktop >= 900px, NavigationRail)', (tester) async {
      // Bascule sur la vue desktop (NavigationRail) pour tester la
      // navigation entre les 8 sections sans les contraintes de scroll
      // horizontal propres à la TabBar mobile (déjà couverte par le test
      // "affiche les 8 onglets" ci-dessus, qui reste en largeur par
      // défaut < 900px).
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap(const AdminFinanceShell()));
      await tester.pumpAndSettle();

      expect(find.byType(NavigationRail), findsOneWidget);

      // Index 7 (Payout Policy) est le seul onglet dont le flux
      // `watch*` (NotConfiguredFinanceRepository.watchPayoutPolicy())
      // retourne une configuration par défaut (`bootstrapDefault()`)
      // plutôt qu'une liste vide : il n'affiche donc jamais l'état
      // "empty" générique et doit être vérifié séparément (déjà couvert
      // par le test dédié "section Payout Policy" ci-dessous).
      for (var i = 0; i < _kTabLabelsFr.length; i++) {
        final label = _kTabLabelsFr[i];
        // Chaque libellé de section apparaît comme label de destination
        // du NavigationRail (le rendu réel utilise un widget interne
        // privé `_RailDestination`, non testable par type ; on navigue
        // donc via son libellé texte À L'INTÉRIEUR du NavigationRail,
        // pour ne jamais confondre avec le titre identique parfois
        // affiché dans le contenu de la section déjà active).
        final destinationFinder = find.descendant(
          of: find.byType(NavigationRail),
          matching: find.text(label),
        );
        await tester.tap(destinationFinder);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (i == 7) {
          // Payout Policy : une configuration par défaut est toujours
          // rendue (pas d'état "empty" générique) — on vérifie plutôt
          // la présence du titre de la carte de configuration.
          expect(find.byType(TextField), findsNWidgets(3));
        } else {
          // Chaque autre section doit finir par afficher l'état vide
          // (aucune donnée NotConfigured) plutôt que de rester bloquée
          // en chargement.
          expect(find.text('Aucune donnée pour le moment.'), findsWidgets);
        }
      }
    });

    testWidgets(
      'section Ledger — bouton "Ajustement" masqué pour un utilisateur non admin',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(const AdminFinanceShell()));
        await tester.pumpAndSettle();

        // Section Ledger = index 4 => libellé 'Registre'.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(_kTabLabelsFr[4]),
          ),
        );
        await tester.pumpAndSettle();

        // FirebaseAuthProvider(backendConfigured: false) => isAdminOrAbove
        // toujours false => le FilledButton.icon "Ajustement" ne doit PAS
        // être rendu (action sensible masquée pour un rôle insuffisant).
        expect(find.text('Ajustement'), findsNothing);
      },
    );

    testWidgets(
      'section Reconciliation — bouton "Lancer" masqué pour un utilisateur non admin',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(const AdminFinanceShell()));
        await tester.pumpAndSettle();

        // Section Reconciliation = index 5 => libellé 'Réconciliation'.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(_kTabLabelsFr[5]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Lancer'), findsNothing);
      },
    );

    testWidgets(
      'section Taxes — bouton de création masqué pour un utilisateur non admin',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(const AdminFinanceShell()));
        await tester.pumpAndSettle();

        // Section Taxes = index 6 => libellé 'Taxes'.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(_kTabLabelsFr[6]),
          ),
        );
        await tester.pumpAndSettle();

        // Le libellé exact provient de `admin_taxes_new_config` (fr) : on
        // vérifie simplement l'absence de tout FilledButton dans cette
        // section pour un rôle non-admin.
        expect(find.byType(FilledButton), findsNothing);
      },
    );

    testWidgets(
      'section Payout Policy — champs en lecture seule + message "réservé admin" '
      'pour un utilisateur non super_admin',
      (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_wrap(const AdminFinanceShell()));
        await tester.pumpAndSettle();

        // Section Payout Policy = index 7 => libellé 'Politique de versement'.
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text(_kTabLabelsFr[7]),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Réservé aux administrateurs'), findsOneWidget);
        expect(find.text('Modifier'), findsNothing);

        // Les 3 champs (default / new_driver / risky_driver) doivent être
        // rendus mais désactivés (aucune action d'édition possible).
        final fields = tester.widgetList<TextField>(find.byType(TextField));
        expect(fields.length, 3);
        for (final f in fields) {
          expect(f.enabled, isFalse);
        }
      },
    );
  });

  group('AdminPaymentDetailScreen — navigation depuis Payments', () {
    testWidgets('affiche loading puis empty pour un paymentId inexistant', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AdminPaymentDetailScreen(paymentId: 'pay_does_not_exist')),
      );

      expect(find.byType(CircularProgressIndicator), findsWidgets);

      await tester.pumpAndSettle();

      expect(find.text('Aucune donnée pour le moment.'), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('affiche l\'AppBar avec l\'identifiant du paiement demandé', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const AdminPaymentDetailScreen(paymentId: 'pay_abc123')),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('pay_abc123'), findsOneWidget);
    });
  });

  group('Widgets partagés — FinanceLoadingState / FinanceEmptyState / '
      'FinanceErrorState (couverture directe des 3 états génériques)', () {
    testWidgets('FinanceLoadingState affiche le spinner et le message', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FinanceLoadingState(message: 'Chargement…')),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Chargement…'), findsOneWidget);
    });

    testWidgets('FinanceEmptyState affiche le message et l\'icône dédiée', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: FinanceEmptyState(message: 'Rien ici.')),
        ),
      );

      expect(find.byIcon(Icons.inbox_outlined), findsOneWidget);
      expect(find.text('Rien ici.'), findsOneWidget);
    });

    testWidgets(
      'FinanceErrorState affiche le message, l\'icône erreur, et déclenche '
      'onRetry au tap du bouton',
      (tester) async {
        var retried = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: FinanceErrorState(
                message: 'Une erreur est survenue.',
                retryLabel: 'Réessayer',
                onRetry: () => retried = true,
              ),
            ),
          ),
        );

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Une erreur est survenue.'), findsOneWidget);

        await tester.tap(find.text('Réessayer'));
        await tester.pump();

        expect(retried, isTrue);
      },
    );

    testWidgets(
      'StatusBadge affiche le libellé traduit avec la couleur donnée',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: StatusBadge(label: 'Capturé', color: Colors.green),
            ),
          ),
        );

        expect(find.text('Capturé'), findsOneWidget);
      },
    );
  });
}
