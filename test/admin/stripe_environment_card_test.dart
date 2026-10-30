// Passage au vrai argent (2026-10-30): the « Paiements Stripe » card.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/stripe_environment_card.dart';

Map<String, dynamic> _status({String env = 'live', List<Map<String, dynamic>> stale = const [], List<Map<String, dynamic>> open = const []}) => {
  'configured': true, 'environment': env, 'stale_drivers': stale, 'open_payments_other_environment': open,
};

Future<List<Map<String, dynamic>>> _pump(WidgetTester t, Map<String, dynamic> Function(int call) status) async {
  t.view.physicalSize = const Size(1000, 1200);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final calls = <Map<String, dynamic>>[];
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ListView(children: [
        StripeEnvironmentCard(api: (data) async {
          calls.add(data);
          return data['action'] == 'get' ? status(calls.length) : {'success': true, 'archived': 1};
        }),
      ]),
    ),
  ));
  await t.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('test mode: orange badge, nothing to archive', (t) async {
    await _pump(t, (_) => _status(env: 'test'));
    expect(find.text('MODE TEST'), findsOneWidget);
    expect(find.text('Tous les comptes de versement des chauffeurs sont du mode actuel.'), findsOneWidget);
    expect(find.byKey(const ValueKey('stripe-archive')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('live: stale driver and open test payment shown; archive asks, calls, refreshes', (t) async {
    final calls = await _pump(t, (n) => n == 1
        ? _status(stale: [{'uid': 'u1', 'name': 'Daniel T.', 'environment': 'test'}],
            open: [{'payment_id': 'p1', 'mission_id': 'm1', 'status': 'authorized', 'environment': 'test'}])
        : _status());
    expect(find.text('VRAI ARGENT'), findsOneWidget);
    expect(find.textContaining('1 chauffeur(s) ont un compte de versement de l’autre mode : Daniel T.'), findsOneWidget);
    expect(find.textContaining('1 paiement(s) de l’autre mode encore ouvert(s)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('stripe-archive')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const ValueKey('stripe-archive-confirm')));
    await t.pumpAndSettle();
    expect(calls.map((c) => c['action']).toList(), ['get', 'archive_stale_driver_accounts', 'get']);
    expect(find.byKey(const ValueKey('stripe-archive-done')), findsOneWidget);
    expect(find.byKey(const ValueKey('stripe-archive')), findsNothing);
    expect(t.takeException(), isNull);
  });

  testWidgets('read-only admin sees the state without the button', (t) async {
    t.view.physicalSize = const Size(360, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 1400), textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: ListView(children: [
            StripeEnvironmentCard(canEdit: false, api: (_) async => _status(stale: [{'uid': 'u1', 'name': null, 'environment': 'test'}])),
          ]),
        ),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('stripe-archive')), findsNothing);
    expect(find.textContaining('u1'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
