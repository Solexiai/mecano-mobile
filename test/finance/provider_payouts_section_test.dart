// ---------------------------------------------------------------------------
// Tests widget — ProviderPayoutsSection / ProviderPayoutsContent (Bloc K
// point 12 "Widget/UI").
//
// `ProviderPayoutsSection` lit directement `BackendLocator.financeRepository`
// (qui retourne `NotConfiguredFinanceRepository` en environnement de test,
// donc toujours des listes vides) — ce test couvre d'abord cet état "vide"
// bout-en-bout via le widget public complet, PUIS utilise le widget de
// contenu pur `ProviderPayoutsContent` (aucune dépendance Firestore) avec des
// fixtures `DriverPayoutInfo`/`FinancialSnapshot` fabriquées localement pour
// couvrir explicitement chaque état requis par la directive :
//   - payout pending/held
//   - payout paid
//   - payout failed
//   - payout reversed
//   - empty state (missions + payouts)
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/finance/models/driver_payout_info.dart';
import 'package:movik_connect/finance/models/financial_snapshot.dart';
import 'package:movik_connect/screens/dashboard/provider/tabs/provider_payouts_section.dart';

String _t(String key) => AppStrings.t(key, 'fr');

Widget _wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(body: SingleChildScrollView(child: child)),
  );
}

DriverPayoutInfo _payout({
  required String id,
  required PayoutStatus status,
  int amountMinor = 4500,
  String? failureReason,
  String? reversalReason,
  DateTime? paidAt,
}) {
  final now = DateTime(2026, 8, 20);
  return DriverPayoutInfo(
    payoutId: id,
    driverId: 'driver_test_001',
    financialSnapshotIds: const ['mission_test_001'],
    amountMinor: amountMinor,
    currency: 'CAD',
    status: status,
    payoutHoldPeriodHours: 72,
    payoutEligibleAt: DateTime(2026, 8, 24),
    createdAt: now,
    paidAt: paidAt,
    failureReason: failureReason,
    reversalReason: reversalReason,
  );
}

FinancialSnapshot _snapshot() {
  return FinancialSnapshot.fromJson({
    'snapshot_id': 'snapshot_test_001',
    'mission_id': 'mission_test_001',
    'driver_id': 'driver_test_001',
    'customer_id': 'customer_test_001',
    'pricing_version': 'v1',
    'driver_offer_amount': 40.0,
    'driver_bonus': 5.0,
    'tip_amount': 3.0,
    'driver_net_mission_earnings': 48.0,
    'created_at': DateTime(2026, 8, 20).toIso8601String(),
    'status': 'confirmed',
  });
}

void main() {
  group('ProviderPayoutsSection — état vide (backend non configuré)', () {
    testWidgets(
      'affiche les sections avec les états vides sans planter (aucune donnée)',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          _wrap(ProviderPayoutsSection(driverId: 'driver_test_001', t: _t)),
        );

        await tester.pump();
        await tester.pumpAndSettle();

        expect(find.text(_t('payout_summary_title')), findsOneWidget);
        expect(find.text(_t('payout_missions_empty')), findsOneWidget);
        expect(find.text(_t('payout_list_empty')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });

  group('ProviderPayoutsContent — états requis (Bloc K point 12)', () {
    testWidgets('empty state : aucune mission, aucun versement', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ProviderPayoutsContent(t: _t, snapshots: const [], payouts: const []),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_t('payout_missions_empty')), findsOneWidget);
      expect(find.text(_t('payout_list_empty')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'payout pending : affiche le statut "En attente" et le message de retenue',
      (tester) async {
        final payout = _payout(id: 'p_pending', status: PayoutStatus.pending);
        await tester.pumpWidget(
          _wrap(
            ProviderPayoutsContent(
              t: _t,
              snapshots: [_snapshot()],
              payouts: [payout],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_t('payout_status_pending')), findsOneWidget);
        expect(find.textContaining(_t('payout_held_message')), findsOneWidget);
        // Date d'éligibilité affichée directement (jamais recalculée).
        expect(find.textContaining(_t('payout_eligible_at')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('payout held : affiche le statut "En période de retenue"', (
      tester,
    ) async {
      final payout = _payout(id: 'p_held', status: PayoutStatus.held);
      await tester.pumpWidget(
        _wrap(
          ProviderPayoutsContent(t: _t, snapshots: const [], payouts: [payout]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text(_t('payout_status_held')), findsOneWidget);
      expect(find.textContaining(_t('payout_held_message')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'payout paid : affiche le statut "Payé" et la date de paiement',
      (tester) async {
        final payout = _payout(
          id: 'p_paid',
          status: PayoutStatus.paid,
          paidAt: DateTime(2026, 8, 25),
        );
        await tester.pumpWidget(
          _wrap(
            ProviderPayoutsContent(
              t: _t,
              snapshots: const [],
              payouts: [payout],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_t('payout_status_paid')), findsOneWidget);
        expect(find.textContaining(_t('payout_paid_at')), findsOneWidget);
        // Pas de bandeau de retenue pour un payout terminal.
        expect(find.textContaining(_t('payout_held_message')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'payout failed : affiche un message générique reformulé, jamais la raison brute serveur',
      (tester) async {
        final payout = _payout(
          id: 'p_failed',
          status: PayoutStatus.failed,
          failureReason: 'stripe_error_code_insufficient_funds_raw_9999',
        );
        await tester.pumpWidget(
          _wrap(
            ProviderPayoutsContent(
              t: _t,
              snapshots: const [],
              payouts: [payout],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_t('payout_status_failed')), findsOneWidget);
        expect(
          find.textContaining(_t('payout_failed_message')),
          findsOneWidget,
        );
        // Le code technique brut ne doit JAMAIS apparaître dans l'UI.
        expect(find.textContaining('stripe_error_code'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'payout reversed : affiche le message de reversal + la raison autorisée si présente',
      (tester) async {
        final payout = _payout(
          id: 'p_reversed',
          status: PayoutStatus.reversed,
          reversalReason: 'Litige client résolu en faveur du client',
        );
        await tester.pumpWidget(
          _wrap(
            ProviderPayoutsContent(
              t: _t,
              snapshots: const [],
              payouts: [payout],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_t('payout_status_reversed')), findsOneWidget);
        expect(
          find.textContaining(_t('payout_reversed_message')),
          findsOneWidget,
        );
        expect(
          find.textContaining('Litige client résolu en faveur du client'),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'mission avec pourboire : le pourboire est affiché distinctement',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ProviderPayoutsContent(
              t: _t,
              snapshots: [_snapshot()],
              payouts: const [],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(_t('payout_mission_tip')), findsOneWidget);
        expect(find.text(_t('payout_mission_net')), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
