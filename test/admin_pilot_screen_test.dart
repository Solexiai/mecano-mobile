import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/admin_pilot_screen.dart';

class FakePilot {
  bool enabled = false;
  bool published = false;
  final testers = <Map<String, dynamic>>[];
  final actions = <Map<String, dynamic>>[];
  Future<Map<String, dynamic>> call(Map<String, dynamic> data) async {
    actions.add(data);
    switch (data['action']) {
      case 'setEnabled':
        enabled = data['enabled'] as bool;
      case 'publishTrialTerms':
        published = true;
      case 'addTester':
        testers.add({'uid': 'u1', 'email': data['email']});
      case 'removeTester':
        testers.removeWhere((t) => t['uid'] == data['uid']);
    }
    return {
      'enabled': enabled,
      'testers': [...testers],
      'terms': published
          ? {'published': true, 'version': 'ESSAI-20261022-1', 'trial': true}
          : {'published': false, 'version': null, 'trial': false},
    };
  }
}

void main() {
  testWidgets('admin adds a tester, publishes trial terms and enables the pilot', (
    t,
  ) async {
    final api = FakePilot();
    await t.pumpWidget(MaterialApp(home: AdminPilotScreen(api: api.call)));
    await t.pumpAndSettle();
    expect(find.textContaining('Non publiées'), findsOneWidget);

    await t.ensureVisible(find.byKey(const ValueKey('pilot-email')));
    await t.enterText(
      find.byKey(const ValueKey('pilot-email')),
      'testeur@example.com',
    );
    await t.ensureVisible(find.byKey(const ValueKey('pilot-add')));
    await t.tap(find.byKey(const ValueKey('pilot-add')));
    await t.pumpAndSettle();
    expect(find.text('testeur@example.com'), findsOneWidget);

    await t.ensureVisible(find.byKey(const ValueKey('pilot-publish-terms')));
    await t.tap(find.byKey(const ValueKey('pilot-publish-terms')));
    await t.pumpAndSettle();
    expect(find.textContaining('ESSAI-20261022-1 (essai)'), findsOneWidget);

    await t.ensureVisible(find.byKey(const ValueKey('pilot-enabled')));
    await t.tap(find.byKey(const ValueKey('pilot-enabled')));
    await t.pumpAndSettle();
    expect(api.enabled, isTrue);
    expect(
      api.actions.map((a) => a['action']).where((a) => a != 'get'),
      ['addTester', 'publishTrialTerms', 'setEnabled'],
    );

    await t.ensureVisible(find.byTooltip('Retirer'));
    await t.tap(find.byTooltip('Retirer'));
    await t.pumpAndSettle();
    expect(find.text('testeur@example.com'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
