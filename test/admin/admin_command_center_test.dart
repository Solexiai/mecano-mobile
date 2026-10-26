// Centre de commande (2026-10-26): one place, one question per tab.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/admin_command_center_screen.dart';
import 'package:movik_connect/services/booking/item_types.dart';

Map<String, dynamic> _types() => {
  'configured': true,
  'photoIntakeEnabled': false,
  'vehicles': ['pickup_truck', 'cargo_van', 'cube_truck'],
  'types': [
    for (final t in itemTypes)
      {'category': t.id, 'vehicles': ['pickup_truck'], 'saved': true},
  ],
};

Widget _app(String tab) => MaterialApp(
  home: AdminCommandCenterScreen(
    initialTab: tab,
    itemTypesApi: (_) async => _types(),
    pricingTab: const Center(child: Text('PRICING TAB')),
  ),
);

void main() {
  testWidgets('home: five tiles and the same rule everywhere', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_app('accueil'));
    await t.pumpAndSettle();
    for (final id in ['quoi', 'combien', 'service', 'partage', 'conditions']) {
      expect(find.byKey(ValueKey('cc-tile-$id')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('cc-rule')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('cc-tile-combien')));
    await t.pumpAndSettle();
    expect(find.text('PRICING TAB'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('"Quoi ?" is the item types grid', (t) async {
    t.view.physicalSize = const Size(1280, 3000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_app('quoi'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('item-types-table')), findsOneWidget);
    expect(find.text('Divan / sofa / sectionnel'), findsOneWidget);
  });

  testWidgets('phone width: tabs scroll, tiles stack, nothing overflows', (t) async {
    t.view.physicalSize = const Size(375, 812);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_app('accueil'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('cc-tile-quoi')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('tab ids in the URL', () {
    expect(commandCenterTabs, ['accueil', 'quoi', 'combien', 'service', 'partage', 'conditions']);
  });
}
