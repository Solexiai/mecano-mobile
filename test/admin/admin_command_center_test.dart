// Centre de commande (2026-10-26): one place, one question per tab.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/admin_command_center_screen.dart';
import 'package:movik_connect/screens/dashboard/admin/command_center/runtime_flags_panel.dart';
import 'package:movik_connect/finance/models/pricing_grid_admin.dart';
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

final _version = AdminPricingVersionInfo(id: 'v-test', raw: {
  'pricing_version': 'v-test',
  'vehicle_rules': [
    for (final c in ['pickup_truck', 'cargo_van', 'cube_truck'])
      {'category': c, 'base_fare': 20, 'rate_per_km': 1.5, 'rate_per_minute': 0.3, 'minimum_charge': 25},
  ],
  'handling_fees': {'stairs_fee': 15},
  'commission': {'standard_commission_rate': 0.2, 'minimum_platform_commission': 5},
  'customer_service_fee': {'service_fee_rate': 0.05, 'minimum_service_fee': 2},
  'item_class_fees': {'heavy': 20, 'driver_keeps_all': true},
});
final previews = <List<Map<String, dynamic>>>[];

Future<PricingPreviewResult> _preview(
  Map<String, dynamic> config,
  List<Map<String, dynamic>> scenarios,
) async {
  previews.add(scenarios);
  const amounts = PricingPreviewAmounts(
    customerTotalMinor: 7400, subtotalMinor: 6000, serviceFeeMinor: 300,
    taxMinor: 700, platformMinor: 1200, driverMinor: 5500, cardHoldMinor: 7400,
  );
  return const PricingPreviewResult(
    activeVersion: 'v-test',
    errors: [],
    rows: [PricingPreviewRow(id: 'try', current: amounts, draft: amounts)],
  );
}

class _FakeFlagsApi implements RuntimeFlagsApi {
  final updates = <Map<String, bool>>[];
  @override
  Stream<Map<String, bool>> watch() => Stream.value({for (final k in runtimeFlagKeys) k: false});
  @override
  Future<void> update(Map<String, bool> patch) async => updates.add(patch);
}

Widget _app(String tab) => MaterialApp(
  home: AdminCommandCenterScreen(
    initialTab: tab,
    runtimeFlagsApi: _FakeFlagsApi(),
    stripeEnvironmentApi: (_) async => {
      'configured': true, 'environment': 'test', 'stale_drivers': [], 'open_payments_other_environment': [],
    },
    itemTypesApi: (_) async => _types(),
    pricingTab: const Center(child: Text('PRICING TAB')),
    loadActive: () async => _version,
    preview: _preview,
  ),
);

void main() {
  testWidgets('home: six tiles and the same rule everywhere', (t) async {
    t.view.physicalSize = const Size(1280, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_app('accueil'));
    await t.pumpAndSettle();
    for (final id in ['quoi', 'combien', 'service', 'partage', 'conditions', 'interrupteurs']) {
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
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('cc-tile-quoi')),
      300,
      scrollable: find
          .ancestor(
            of: find.byKey(const ValueKey('price-simulator')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.byKey(const ValueKey('cc-tile-quoi')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('tab ids in the URL', () {
    expect(commandCenterTabs, ['accueil', 'quoi', 'combien', 'service', 'partage', 'conditions', 'interrupteurs']);
  });

  testWidgets('home simulator: who receives what, from the active grid', (t) async {
    t.view.physicalSize = const Size(1280, 1400);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    previews.clear();
    await t.pumpWidget(_app('accueil'));
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('price-simulator')), findsOneWidget);
    expect(find.textContaining('74,00'), findsOneWidget);
    expect(find.textContaining('55,00'), findsOneWidget);
    expect(previews.last.single['items'], [{'category': 'sofa', 'quantity': 1}]);
    await t.tap(find.byKey(const ValueKey('try-stairs')));
    await t.pumpAndSettle();
    expect((previews.last.single['handling'] as Map)['needsStairs'], isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('"Qui reçoit quoi ?" reads the active share and links to prices', (t) async {
    t.view.physicalSize = const Size(1280, 1600);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(_app('partage'));
    await t.pumpAndSettle();
    expect(find.text('20 %'), findsOneWidget);
    expect(find.text('100 % au chauffeur'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('share-edit')));
    await t.pumpAndSettle();
    expect(find.text('PRICING TAB'), findsOneWidget);
  });
}
