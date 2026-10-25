// Accueil chauffeur (25 octobre 2026) : prochaine mission, gains de la
// semaine, missions à venir ; formats d'affichage des revenus.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/delivery_mission.dart';
import 'package:movik_connect/finance/models/transaction_ledger.dart';
import 'package:movik_connect/finance/presentation/driver_display_format.dart';
import 'package:movik_connect/finance/presentation/driver_earnings_totals.dart';
import 'package:movik_connect/models/enums.dart';
import 'package:movik_connect/widgets/driver_home_summary.dart';

DeliveryMission _mission(String id, String status, DateTime at) =>
    DeliveryMission.fromJson(id, {
      'driver_id': 'driver-1',
      'customer_id': 'customer-1',
      'description': 'Sofa',
      'created_at': at.toIso8601String(),
      'status': status,
      'driver_offer_amount': 42.5,
      'pickup_address': {'line1': '1 rue A', 'city': 'Granby'},
      'dropoff_address': {'line1': '2 rue B', 'city': 'Bromont'},
      'booking_snapshot': {
        'load': {'requested_at': at.toUtc().toIso8601String()},
      },
    });

LedgerEntry _entry(double amount, DateTime at, {String? feeKind}) =>
    LedgerEntry(
      ledgerEntryId: 'l-$amount-${at.millisecondsSinceEpoch}',
      missionId: 'm',
      type: LedgerEntryType.driverEarning,
      amount: amount,
      direction: LedgerDirection.credit,
      party: LedgerParty.driver,
      createdAt: at,
      createdBy: 'test',
      sourceEvent: 'test',
      status: LedgerEntryStatus.confirmed,
      feeKind: feeKind,
    );

void main() {
  test('formats français : montants, dates, heures', () {
    expect(driverMoney(67.5, 'fr'), '67,50 \$');
    expect(driverShortDate(DateTime(2026, 10, 23), 'fr'), '23 oct. 2026');
    expect(driverShortDate(DateTime(2026, 10, 23), 'en'), 'Oct 23, 2026');
    expect(driverClock(480, 'fr'), '8 h');
    expect(driverClock(510, 'fr'), '8 h 30');
    expect(driverClock(1020, 'en'), '17:00');
    expect(driverDayLabel(DateTime(2026, 10, 29), 'fr'), 'jeu. 29 oct.');
    expect(driverMonthYear(DateTime(2026, 11), 'fr'), 'Novembre 2026');
    // Semaine du lundi, même avec le changement d'heure du 1er novembre.
    expect(driverWeekStart(DateTime(2026, 11, 4, 15)), DateTime(2026, 11, 2));
    expect(driverWeekStart(DateTime(2026, 11, 1, 12)), DateTime(2026, 10, 26));
  });

  test('gains : semaine, mois et total', () {
    final now = DateTime(2026, 10, 25, 12); // dimanche
    final totals = DriverEarningsTotals.from([
      _entry(21.25, DateTime(2026, 10, 23)), // cette semaine
      _entry(25, DateTime(2026, 10, 19, 8)), // lundi, cette semaine
      _entry(10, DateTime(2026, 10, 18)), // semaine dernière, ce mois
      _entry(5, DateTime(2026, 9, 30)), // mois dernier
    ], now);
    expect(totals.week, 46.25);
    expect(totals.month, 56.25);
    expect(totals.total, 61.25);
  });

  test('missions à venir : attribuées seulement, la plus proche d’abord', () {
    final now = DateTime(2026, 10, 25);
    final list = upcomingDriverMissions([
      _mission('later', 'assigned', now.add(const Duration(days: 2))),
      _mission('done', 'completed', now.add(const Duration(days: 1))),
      _mission('soon', 'assigned', now.add(const Duration(days: 1))),
    ]);
    expect(list.map((m) => m.id), ['soon', 'later']);
  });

  testWidgets('accueil : prochaine mission et gains de la semaine', (t) async {
    final missions = StreamController<List<DeliveryMission>>();
    final ledger = StreamController<List<LedgerEntry>>();
    addTearDown(missions.close);
    addTearDown(ledger.close);
    t.view.physicalSize = const Size(375, 800);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);

    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DriverHomeSummary(
              driverId: 'driver-1',
              locale: 'fr',
              missions: missions.stream,
              ledger: ledger.stream,
            ),
          ),
        ),
      ),
    );
    // Nothing until data arrives: never a spinner above the requests.
    expect(find.byType(CircularProgressIndicator), findsNothing);

    final at = DateTime.now().add(const Duration(days: 1));
    missions.add([_mission('m1', 'assigned', at)]);
    ledger.add([_entry(21.25, DateTime.now())]);
    await t.pumpAndSettle();

    expect(find.text('Prochaine mission'), findsOneWidget);
    expect(find.text('Granby → Bromont'), findsOneWidget);
    expect(find.text('42,50 \$'), findsOneWidget);
    expect(find.text('21,25 \$'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('accueil : sources indisponibles = rien affiché, aucune erreur', (
    t,
  ) async {
    await t.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DriverHomeSummary(
            driverId: 'driver-1',
            locale: 'fr',
            missions: Stream.error(StateError('offline')),
            ledger: Stream.error(StateError('offline')),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Prochaine mission'), findsNothing);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(t.takeException(), isNull);
  });
}
