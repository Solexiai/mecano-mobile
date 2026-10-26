// Centre de commande > Conditions spéciales (2026-10-26).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/conditions_panel.dart';

final _now = DateTime(2026, 12, 3, 8, 0);

Map<String, dynamic> _get({bool surcharge = false, bool pause = false}) => {
  'saved': surcharge || pause,
  'surchargeInForce': surcharge,
  'conditions': {
    'surcharge': {
      'active': surcharge,
      'reason': 'snow',
      'mode': 'percentage',
      'value': surcharge ? 0.2 : 0,
      'starts_at_ms': surcharge ? _now.millisecondsSinceEpoch : 0,
      'ends_at_ms': surcharge ? _now.add(const Duration(hours: 6)).millisecondsSinceEpoch : 0,
    },
    'pause': {'active': pause, 'message': pause ? 'Verglas.' : ''},
  },
};

Future<List<Map<String, dynamic>>> _pump(WidgetTester t, Map<String, dynamic> state) async {
  t.view.physicalSize = const Size(1200, 2400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final calls = <Map<String, dynamic>>[];
  await t.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ConditionsPanel(
        clock: () => _now,
        api: (data) async {
          calls.add(data);
          return data['action'] == 'get'
              ? state
              : {'success': true, 'surchargeInForce': ((data['conditions'] as Map)['surcharge'] as Map)['active']};
        },
      ),
    ),
  ));
  await t.pumpAndSettle();
  return calls;
}

void main() {
  testWidgets('activate a storm supplement: reason, %, period; the customer preview', (t) async {
    final calls = await _pump(t, _get());
    expect(find.text('Aucun supplément en vigueur.'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('conditions-value-0')), '10');
    await t.pump();
    expect(find.textContaining('« Comprend : supplément tempête de neige » (+10 %)'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('conditions-activate')));
    await t.pumpAndSettle();
    final s = (calls.last['conditions'] as Map)['surcharge'] as Map;
    expect(s['active'], true);
    expect(s['reason'], 'snow');
    expect(s['value'], closeTo(0.10, 1e-9));
    expect(s['starts_at_ms'], _now.millisecondsSinceEpoch);
    expect(s['ends_at_ms'], _now.add(const Duration(hours: 12)).millisecondsSinceEpoch);
    expect(find.text('En vigueur jusqu’au 3/12 à 20 h 00.'), findsOneWidget);
    expect(find.byKey(const ValueKey('conditions-stop')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('pausing keeps the supplement period; a message is required', (t) async {
    final calls = await _pump(t, _get(surcharge: true));
    expect(find.text('En vigueur jusqu’au 3/12 à 14 h 00.'), findsOneWidget);
    final pause = find.byKey(const ValueKey('conditions-pause-start'));
    expect(t.widget<FilledButton>(pause).onPressed, isNull);
    await t.enterText(find.byKey(const ValueKey('conditions-pause-message-0')), 'Verglas, retour demain.');
    await t.pump();
    await t.tap(pause);
    await t.pumpAndSettle();
    final c = calls.last['conditions'] as Map;
    expect(c['pause'], {'active': true, 'message': 'Verglas, retour demain.'});
    expect((c['surcharge'] as Map)['active'], true);
    expect((c['surcharge'] as Map)['ends_at_ms'], _now.add(const Duration(hours: 6)).millisecondsSinceEpoch);
    expect(find.byKey(const ValueKey('conditions-resume')), findsOneWidget);
  });

  testWidgets('phone width, large text: no overflow', (t) async {
    t.view.physicalSize = const Size(360, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(size: Size(360, 1600), textScaler: TextScaler.linear(2)),
        child: Scaffold(body: ConditionsPanel(clock: () => _now, api: (_) async => _get(surcharge: true, pause: true))),
      ),
    ));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    await t.scrollUntilVisible(find.byKey(const ValueKey('conditions-resume')), 300,
        scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const ValueKey('conditions-resume')), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
