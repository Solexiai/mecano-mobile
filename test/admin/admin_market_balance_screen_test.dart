import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:movik_connect/providers/locale_provider.dart';
import 'package:movik_connect/screens/dashboard/admin/balance/admin_market_balance_screen.dart';

Map<String, dynamic> _city(
  String key,
  String label,
  String verdict, {
  int requests = 0,
  int accepted = 0,
  int noDriver = 0,
  double? rate,
  int approved = 0,
  double? jobs,
}) => {
  'key': key,
  'label': label,
  'verdict': verdict,
  'reasons': <String>[],
  'requests': requests,
  'accepted': accepted,
  'noDriver': noDriver,
  'pending': 0,
  'acceptanceRate': rate,
  'medianAcceptMinutes': 14,
  'completed': accepted,
  'activeDrivers': 1,
  'approvedDrivers': approved,
  'onlineDriversNow': 1,
  'jobsPerDriverPerWeek': jobs,
  'availableHours': null,
  'offers': {'sent': 5, 'accepted': 3, 'declined': 2, 'expired': 0},
  'declineReasons': {'too_far': 2},
  'quotesNotBooked': 4,
};

Map<String, dynamic> _report() => {
  'availabilityMeasured': false,
  'truncated': false,
  'thresholds': {'minAcceptanceRate': 0.85, 'minJobsPerDriverPerWeek': 2},
  'total': _city(
    '_total',
    'Toutes les villes',
    'drivers_short',
    requests: 9,
    accepted: 6,
    noDriver: 3,
    rate: 0.667,
    approved: 4,
    jobs: 1.5,
  ),
  'cities': [
    _city(
      'granby',
      'Granby',
      'drivers_short',
      requests: 8,
      accepted: 5,
      noDriver: 3,
      rate: 0.625,
      approved: 1,
      jobs: 5,
    ),
    _city(
      'bromont',
      'Bromont',
      'customers_short',
      requests: 1,
      accepted: 1,
      rate: 1,
      approved: 3,
      jobs: 0.3,
    ),
  ],
};

Future<void> _pump(
  WidgetTester tester,
  MarketBalanceLoader loader, {
  DateTime? now,
}) async {
  SharedPreferences.setMockInitialValues({});
  final locales = LocaleProvider();
  await locales.setLocale('fr');
  await tester.binding.setSurfaceSize(const Size(1200, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    ChangeNotifierProvider<LocaleProvider>.value(
      value: locales,
      child: MaterialApp(
        home: AdminMarketBalanceScreen(
          loader: loader,
          clock: () => now ?? DateTime(2026, 11, 11, 15),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  test('la semaine commence le lundi à 0 h', () {
    expect(startOfWeek(DateTime(2026, 11, 11, 15)), DateTime(2026, 11, 9));
    expect(startOfWeek(DateTime(2026, 11, 9)), DateTime(2026, 11, 9));
    expect(startOfWeek(DateTime(2026, 11, 15, 23)), DateTime(2026, 11, 9));
  });

  testWidgets('affiche chaque ville avec son verdict et quoi faire', (
    tester,
  ) async {
    final calls = <(DateTime, DateTime)>[];
    await _pump(tester, (from, to) async {
      calls.add((from, to));
      return _report();
    });
    expect(calls.single, (DateTime(2026, 11, 9), DateTime(2026, 11, 16)));
    expect(find.text('Semaine du 9 nov. au 15 nov. 2026'), findsOneWidget);
    expect(find.text('Granby'), findsOneWidget);
    expect(find.text('Bromont'), findsOneWidget);
    expect(find.text('Il manque des chauffeurs'), findsNWidgets(2));
    expect(find.text('Il manque des clients'), findsOneWidget);
    expect(
      find.text('À faire : recruter des chauffeurs dans ce secteur.'),
      findsNWidgets(2),
    );
    expect(
      find.text('À faire : de la pub pour attirer des clients.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('8 demande(s) · 5 prise(s) (63 %)'),
      findsOneWidget,
    );
    expect(find.textContaining('Raisons de refus : trop loin 2'), findsWidgets);
    expect(find.textContaining('heures en ligne'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('change de semaine, sans aller dans le futur', (tester) async {
    final calls = <DateTime>[];
    await _pump(tester, (from, to) async {
      calls.add(from);
      return _report();
    });
    final next = find.widgetWithIcon(IconButton, Icons.chevron_right);
    expect(tester.widget<IconButton>(next).onPressed, isNull);
    await tester.tap(find.widgetWithIcon(IconButton, Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(calls.last, DateTime(2026, 11, 2));
    expect(tester.widget<IconButton>(next).onPressed, isNotNull);
  });

  testWidgets('une erreur propose de réessayer', (tester) async {
    var fail = true;
    await _pump(tester, (from, to) async {
      if (fail) throw StateError('SIMULATED');
      return _report();
    });
    expect(
      find.text('Impossible de charger l’équilibre. Réessayez.'),
      findsOneWidget,
    );
    fail = false;
    await tester.tap(find.text('Réessayer'));
    await tester.pumpAndSettle();
    expect(find.text('Granby'), findsOneWidget);
  });
}
