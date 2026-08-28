// ---------------------------------------------------------------------------
// Tests widget — MissionFinanceSection (Bloc J point 13 ; Phase 7, Bloc AB,
// AB-8 — BUG-AB-08-01).
//
// TEST 1 (préexistant) : backend non configuré (`NotConfiguredFinanceRepository`,
// tous les streams `watch*` émettent `null`/liste vide) -> état "aucune
// donnée". Dans ce cas `_SummarySection` prend la branche `snapshot == null`
// et n'affiche JAMAIS `_LineRow` (voir `mission_finance_section.dart`,
// `_SummarySection.build()`) — ce test ne peut donc PAS servir de preuve de
// régression pour BUG-AB-08-01 (c'est exactement l'erreur de la tentative
// précédente).
//
// TESTS 2+ (BUG-AB-08-01) : injectent un `FinancialSnapshot` RÉEL (non-null)
// via le seam `BackendLocator.financeRepositoryOverride` (même pattern que
// `ratingRepositoryOverride` dans `customer_tracking_rating_test.dart`), ce
// qui force `_SummarySection` à emprunter la branche qui rend RÉELLEMENT
// `_LineRow` (prix mission, frais, taxes, pourboire, total). Le VRAI widget
// public `MissionFinanceSection` est utilisé tel quel (aucun widget interne
// recréé artificiellement dans le test) :
//   - AB-08-01-a : viewport 320px, snapshot avec fees+tax+tip+total (donc 5
//     lignes `_LineRow` rendues), libellés FR normaux -> aucune exception,
//     aucun `RenderFlex overflow`.
//   - AB-08-01-b : viewport 320px, la fonction `t` fournie retourne un
//     libellé DÉLIBÉRÉMENT très long (bien plus long que n'importe quelle
//     traduction FR/EN/ES réelle) pour `finance_summary_mission_price`,
//     stress-test qui aurait très largement dépassé la largeur disponible
//     avant le fix (`Expanded` + `ellipsis` sur le libellé) -> toujours
//     aucune exception, aucun overflow (le libellé est simplement tronqué
//     visuellement, la valeur monétaire reste entièrement visible).
//   - AB-08-01-c : mêmes conditions que (a) mais viewport 360px, pour
//     couvrir la seconde largeur réelle citée dans le rapport de bug.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/backend/backend_locator.dart';
import 'package:movik_connect/backend/repositories/finance_repository.dart';
import 'package:movik_connect/finance/models/financial_snapshot.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/customer/mission_finance_section.dart';
import 'package:movik_connect/l10n/app_strings.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

/// Fake `FinanceRepository` — ne surcharge QUE `watchFinancialSnapshot` (le
/// seul flux dont ce test a besoin) ; les 3 autres flux consommés par
/// `MissionFinanceSection` (paiement, remboursements, solde) retombent sur
/// le même comportement "vide" que `NotConfiguredFinanceRepository`, ce qui
/// est un état parfaitement valide en pratique (ex: mission dont le
/// snapshot financier est déjà figé mais dont le paiement n'a pas encore
/// été capturé).
class _FakeFinanceRepositoryWithSnapshot extends NotConfiguredFinanceRepository {
  final FinancialSnapshot snapshot;
  const _FakeFinanceRepositoryWithSnapshot(this.snapshot);

  @override
  Future<FinancialSnapshot?> getFinancialSnapshot(String missionId) async =>
      snapshot;

  @override
  Stream<FinancialSnapshot?> watchFinancialSnapshot(String missionId) =>
      Stream.value(snapshot);
}

/// Fixture `FinancialSnapshot` NON NULLE avec assez de données pour que
/// `_SummarySection` rende RÉELLEMENT 5 `_LineRow` (prix mission, frais,
/// taxes, pourboire, total) — tous les montants "fees/tax/tip" sont
/// délibérément non-nuls pour exercer toutes les lignes conditionnelles.
FinancialSnapshot _buildSnapshot({String missionId = 'mission_ab08_01'}) {
  return FinancialSnapshot(
    snapshotId: 'snap_ab08_01',
    missionId: missionId,
    customerId: 'customer_ab08_01',
    driverId: 'driver_ab08_01',
    pricingVersion: 'TEST-AB08',
    missionBaseValue: 128.75,
    driverGrossEarnings: 100.0,
    driverOfferAmount: 95.0,
    commissionRate: 0.20,
    commissionProgram: CommissionProgramType.standard,
    minimumPlatformCommission: 5.0,
    maximumEffectiveCommissionRate: 0.30,
    platformCommissionAmount: 25.75,
    customerServiceFee: 6.5,
    customerFees: 3.25,
    customerDiscount: 0,
    customerTax: 14.02,
    driverBonus: 0,
    tipAmount: 8.0,
    driverNetMissionEarnings: 103.0,
    driverTotalPayout: 103.0,
    paymentProcessingCost: 2.1,
    insuranceCost: 0,
    // total = 128.75 + (6.5+3.25-0) + 14.02 + 8.0
    customerTotal: 160.52,
    platformGrossRevenue: 25.75,
    contributionMargin: 23.65,
    createdAt: DateTime(2026, 1, 1, 10, 0),
    confirmedAt: DateTime(2026, 1, 1, 10, 5),
    status: 'confirmed',
  );
}

Future<void> _setViewport(WidgetTester tester, double width, double height) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  tearDown(() {
    // Seam de test (Phase 7) — jamais laissé positionné hors d'un test.
    BackendLocator.financeRepositoryOverride = null;
  });

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

  group('BUG-AB-08-01 (P2) — régression permanente _LineRow / RenderFlex overflow', () {
    testWidgets(
      'AB-08-01-a : viewport 320px, FinancialSnapshot NON NULL (5 lignes _LineRow réellement rendues), FR -> aucun overflow',
      (WidgetTester tester) async {
        await _setViewport(tester, 320, 1200);

        final snapshot = _buildSnapshot();
        BackendLocator.financeRepositoryOverride =
            _FakeFinanceRepositoryWithSnapshot(snapshot);

        await tester.pumpWidget(
          _wrap(
            MissionFinanceSection(
              missionId: snapshot.missionId,
              t: (key) => AppStrings.t(key, 'fr'),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Preuve que _SummarySection a bien emprunté la branche
        // "snapshot != null" et que _LineRow a RÉELLEMENT été traversé (pas
        // juste "aucune exception" par accident) : le libellé "Total" et son
        // montant formaté doivent être visibles à l'écran.
        expect(
          find.text(AppStrings.t('finance_summary_mission_price', 'fr')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.t('finance_summary_fees', 'fr')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.t('finance_summary_taxes', 'fr')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.t('finance_summary_tip', 'fr')),
          findsOneWidget,
        );
        expect(
          find.text(AppStrings.t('finance_summary_total', 'fr')),
          findsOneWidget,
        );
        expect(find.text(formatMajorAmount(snapshot.customerTotal)), findsOneWidget);

        // LE test de régression BUG-AB-08-01 : aucune exception Flutter,
        // donc aucun `RenderFlex overflowed` levé par _LineRow à 320px.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AB-08-01-b : viewport 320px, libellé délibérément très long injecté via `t` -> label tronqué (ellipsis), valeur toujours visible, aucun overflow',
      (WidgetTester tester) async {
        await _setViewport(tester, 320, 1200);

        final snapshot = _buildSnapshot(missionId: 'mission_ab08_01_long');
        BackendLocator.financeRepositoryOverride =
            _FakeFinanceRepositoryWithSnapshot(snapshot);

        const longLabel =
            'Prix de base de la mission incluant tous les frais de manutention et de transport spécialisé';

        String tWithLongLabel(String key) {
          if (key == 'finance_summary_mission_price') return longLabel;
          return AppStrings.t(key, 'fr');
        }

        await tester.pumpWidget(
          _wrap(
            MissionFinanceSection(
              missionId: snapshot.missionId,
              t: tWithLongLabel,
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        // Le montant de la ligne "prix mission" reste entièrement visible et
        // NON tronqué (c'est la garantie du fix : seul le libellé peut
        // s'abréger, jamais le montant).
        expect(
          find.text(formatMajorAmount(snapshot.missionBaseValue)),
          findsOneWidget,
        );

        // Le libellé (délibérément trop long pour 320px) est bien rendu par
        // un `Text` avec `overflow: TextOverflow.ellipsis` (preuve directe
        // que la branche corrigée de `_LineRow` est active), et non par un
        // `Text` non contraint qui provoquerait l'overflow historique.
        final longLabelTextWidgets = tester.widgetList<Text>(
          find.text(longLabel),
        );
        expect(longLabelTextWidgets, isNotEmpty);
        for (final textWidget in longLabelTextWidgets) {
          expect(textWidget.overflow, TextOverflow.ellipsis);
        }

        // Preuve finale de non-régression : même avec un libellé
        // volontairement extrême, aucune exception `RenderFlex overflowed`
        // n'est levée par le framework.
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'AB-08-01-c : viewport 360px, FinancialSnapshot NON NULL, EN -> aucun overflow (seconde largeur réelle du rapport de bug)',
      (WidgetTester tester) async {
        await _setViewport(tester, 360, 1200);

        final snapshot = _buildSnapshot(missionId: 'mission_ab08_01_360');
        BackendLocator.financeRepositoryOverride =
            _FakeFinanceRepositoryWithSnapshot(snapshot);

        await tester.pumpWidget(
          _wrap(
            MissionFinanceSection(
              missionId: snapshot.missionId,
              t: (key) => AppStrings.t(key, 'en'),
            ),
          ),
        );
        await tester.pump();
        await tester.pumpAndSettle();

        expect(
          find.text(AppStrings.t('finance_summary_total', 'en')),
          findsOneWidget,
        );
        expect(find.text(formatMajorAmount(snapshot.customerTotal)), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
