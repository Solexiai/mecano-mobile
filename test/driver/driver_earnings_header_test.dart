// Onglet Revenus « style Uber » (phase 2, 2026-11-06) : total de la
// semaine, livraisons payées, graphique lundi → dimanche. Affichage
// seulement, à partir des écritures confirmées.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/transaction_ledger.dart';
import 'package:movik_connect/finance/presentation/driver_earnings_totals.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/screens/dashboard/provider/widgets/driver_earnings_header.dart';

LedgerEntry _entry(
  double amount,
  DateTime at, {
  String missionId = 'm',
  LedgerEntryType type = LedgerEntryType.driverEarning,
  LedgerDirection direction = LedgerDirection.credit,
  LedgerEntryStatus status = LedgerEntryStatus.confirmed,
}) => LedgerEntry(
  ledgerEntryId: 'l-$amount-${at.millisecondsSinceEpoch}-$missionId',
  missionId: missionId,
  type: type,
  amount: amount,
  direction: direction,
  party: LedgerParty.driver,
  createdAt: at,
  createdBy: 'test',
  sourceEvent: 'test',
  status: status,
);

String _t(String key) => AppStrings.t(key, 'fr');

void main() {
  test('semaine par jour et livraisons payées distinctes', () {
    final now = DateTime(2026, 11, 6, 12); // vendredi
    final totals = DriverEarningsTotals.from([
      _entry(38, DateTime(2026, 11, 2, 9), missionId: 'a'), // lundi
      _entry(52, DateTime(2026, 11, 4, 11), missionId: 'b'), // mercredi
      _entry(10, DateTime(2026, 11, 4, 12), missionId: 'b'), // même mission
      _entry(
        4,
        DateTime(2026, 11, 4, 13),
        missionId: 'b',
        type: LedgerEntryType.payoutProcessingFee,
        direction: LedgerDirection.debit,
      ),
      _entry(20, DateTime(2026, 10, 30), missionId: 'z'), // semaine dernière
      _entry(
        99,
        DateTime(2026, 11, 5),
        missionId: 'p',
        status: LedgerEntryStatus.pending,
      ),
    ], now);
    expect(totals.week, 96);
    expect(totals.weekByDay, [38, 0, 58, 0, 0, 0, 0]);
    expect(totals.weekDeliveries, 2);
    expect(totals.pending, 99);
  });

  testWidgets('en-tête : total, sous-titre et sept barres', (tester) async {
    final totals = DriverEarningsTotals.from([
      _entry(38, DateTime(2026, 11, 2, 9), missionId: 'a'),
      _entry(52, DateTime(2026, 11, 4, 11), missionId: 'b'),
    ], DateTime(2026, 11, 6, 12));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverEarningsHeader(
            totals: totals,
            t: _t,
            locale: 'fr',
            now: () => DateTime(2026, 11, 6, 12),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('90,00 \$'), findsOneWidget);
    expect(find.text('Cette semaine · 2 livraisons payées'), findsOneWidget);
    for (var i = 0; i < 7; i++) {
      expect(find.byKey(ValueKey('driver-earnings-day-$i')), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('semaine vide : aucune erreur, sous-titre « aucune »', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverEarningsHeader(
            totals: DriverEarningsTotals.from(const [], DateTime(2026, 11, 6)),
            t: _t,
            locale: 'fr',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text(_t('earnings_week_deliveries_none')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
