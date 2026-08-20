// ---------------------------------------------------------------------------
// Tests widget — MissionFinanceSection (Bloc J point 13)
//
// Le backend n'étant pas configuré en environnement de test
// (`BackendBootstrap.status.isConfigured == false`), `BackendLocator.
// financeRepository` retourne `NotConfiguredFinanceRepository`, dont tous
// les streams `watch*` émettent immédiatement `null`/liste vide. Ce test
// vérifie donc le comportement de la section dans son état "aucune donnée"
// (états vides), qui est exactement l'état attendu pour une ancienne
// mission n'ayant aucune donnée Phase 6 (directive Bloc J point 10) — la
// section ne doit JAMAIS planter dans ce cas.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/screens/customer/mission_finance_section.dart';
import 'package:movik_connect/l10n/app_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

void main() {
  testWidgets(
    'affiche la section sans planter quand aucune donnée financière n\'existe (backend non configuré)',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          MissionFinanceSection(
            missionId: 'mission_test_001',
            t: (key) => AppStrings.t(key, 'fr'),
          ),
        ),
      );

      // Premier frame : état de chargement.
      await tester.pump();

      // Laisse les 4 StreamBuilder imbriqués (Stream.value()) se résoudre
      // entièrement (chacun ajoute un micro-task supplémentaire).
      await tester.pumpAndSettle();

      // Le titre de la section doit être présent.
      expect(
        find.text(AppStrings.t('finance_section_title', 'fr')),
        findsOneWidget,
      );
      // Aucun paiement connu -> message "aucun paiement" affiché au moins
      // une fois (résumé ET paiement retombent tous deux sur ce message
      // quand FinancialSnapshot/PaymentInfo sont null).
      expect(
        find.text(AppStrings.t('finance_payment_none', 'fr')),
        findsWidgets,
      );
      // Aucun remboursement.
      expect(
        find.text(AppStrings.t('finance_refund_none', 'fr')),
        findsOneWidget,
      );
      // Historique vide.
      expect(
        find.text(AppStrings.t('finance_history_empty', 'fr')),
        findsOneWidget,
      );

      // Aucune exception ne doit avoir été levée pendant tout le rendu.
      expect(tester.takeException(), isNull);
    },
  );
}
