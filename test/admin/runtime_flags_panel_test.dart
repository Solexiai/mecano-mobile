// ADM-02 (2026-10-28) : les interrupteurs d'urgence depuis l'admin.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/runtime_flags_panel.dart';

class _Api implements RuntimeFlagsApi {
  final controller = StreamController<Map<String, bool>>.broadcast();
  final updates = <Map<String, bool>>[];
  Map<String, bool> state = {for (final k in runtimeFlagKeys) k: false};
  @override
  Stream<Map<String, bool>> watch() async* {
    yield state;
    yield* controller.stream;
  }

  @override
  Future<void> update(Map<String, bool> patch) async {
    updates.add(patch);
    state = {...state, ...patch};
    controller.add(state);
  }
}

Future<Map<String, dynamic>> _stripe(Map<String, dynamic> _) async => {
  'configured': true, 'environment': 'test', 'stale_drivers': [], 'open_payments_other_environment': [],
};

void main() {
  testWidgets('all closed banner, confirm dialog, then the function is called with one flag', (t) async {
    t.view.physicalSize = const Size(1200, 2000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final api = _Api();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: RuntimeFlagsPanel(api: api, stripeApi: _stripe))));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('flags-all-closed')), findsOneWidget);
    for (final k in runtimeFlagKeys) {
      expect(t.widget<SwitchListTile>(find.byKey(ValueKey('flag-$k'))).value, isFalse);
    }

    await t.tap(find.byKey(const ValueKey('flag-payments_enabled')));
    await t.pumpAndSettle();
    expect(find.textContaining('Ouvrir « Paiements »'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('flag-confirm-payments_enabled')));
    await t.pumpAndSettle();
    expect(api.updates, [
      {'payments_enabled': true},
    ]);
    expect(t.widget<SwitchListTile>(find.byKey(const ValueKey('flag-payments_enabled'))).value, isTrue);
    expect(find.byKey(const ValueKey('flags-all-closed')), findsNothing);

    // Fermer demande aussi confirmation ; annuler ne change rien.
    await t.tap(find.byKey(const ValueKey('flag-payments_enabled')));
    await t.pumpAndSettle();
    expect(find.textContaining('Fermer « Paiements »'), findsOneWidget);
    await t.tap(find.text('Annuler'));
    await t.pumpAndSettle();
    expect(api.updates, hasLength(1));
  });

  testWidgets('analyst: read-only switches', (t) async {
    final api = _Api();
    await t.pumpWidget(MaterialApp(home: Scaffold(body: RuntimeFlagsPanel(api: api, canEdit: false, stripeApi: _stripe))));
    await t.pumpAndSettle();
    for (final k in runtimeFlagKeys) {
      expect(t.widget<SwitchListTile>(find.byKey(ValueKey('flag-$k'))).onChanged, isNull);
    }
    expect(find.textContaining('Lecture seule'), findsOneWidget);
  });
}
