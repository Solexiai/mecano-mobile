// Types d'objets et véhicules (2026-10-26): the admin checks, saves, and a
// type with no vehicle is marked "non offert".
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/admin_item_types_screen.dart';
import 'package:movik_connect/services/booking/item_types.dart';

void main() {
  Map<String, dynamic> state({bool savedAll = false}) => {
    'configured': true,
    'photoIntakeEnabled': true,
    'vehicles': ['pickup_truck', 'cargo_van', 'cube_truck'],
    'types': [
      for (final t in itemTypes)
        {
          'category': t.id,
          'vehicles': t.id == 'materials'
              ? ['pickup_truck', 'cube_truck']
              : ['pickup_truck', 'cargo_van', 'cube_truck'],
          'saved': savedAll || t.id == 'sofa',
        },
    ],
  };

  testWidgets('every type is listed; new ones are pre-checked, then saved', (
    t,
  ) async {
    t.view.physicalSize = const Size(1200, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    final calls = <Map<String, dynamic>>[];
    await t.pumpWidget(
      MaterialApp(
        home: AdminItemTypesScreen(
          api: (data) async {
            calls.add(data);
            return data['action'] == 'get'
                ? state()
                : {'success': true, 'version': 'admin-2026-10-26'};
          },
        ),
      ),
    );
    await t.pumpAndSettle();
    for (final type in itemTypes) {
      expect(find.text(type.fr), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('item-types-unsaved')), findsOneWidget);
    final vanMaterials = t.widget<Checkbox>(
      find.byKey(const ValueKey('item-type-materials-cargo_van')),
    );
    expect(vanMaterials.value, isFalse);

    // Tires: no vehicle at all -> "non offert" once saved.
    for (final v in ['pickup_truck', 'cargo_van', 'cube_truck']) {
      await t.tap(find.byKey(ValueKey('item-type-tires-$v')));
      await t.pump();
    }
    await t.tap(find.byKey(const ValueKey('item-types-save')));
    await t.pumpAndSettle();
    final saved = calls.last;
    expect(saved['action'], 'save');
    final mapping = saved['mapping'] as Map;
    expect(mapping.length, itemTypes.length);
    expect(mapping['tires'], isEmpty);
    expect(mapping['materials'], ['pickup_truck', 'cube_truck']);
    expect(mapping['bed'], ['pickup_truck', 'cargo_van', 'cube_truck']);
    expect(find.byKey(const ValueKey('item-types-saved')), findsOneWidget);
    expect(find.byKey(const ValueKey('item-type-off-tires')), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('nothing changed and all saved: the button waits', (t) async {
    t.view.physicalSize = const Size(1200, 4000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        home: AdminItemTypesScreen(api: (_) async => state(savedAll: true)),
      ),
    );
    await t.pumpAndSettle();
    final save = t.widget<FilledButton>(
      find.byKey(const ValueKey('item-types-save')),
    );
    expect(save.onPressed, isNull);
  });

  test('client and server share the same item type ids', () {
    expect(itemTypes.map((t) => t.id).toList(), [
      'sofa', 'armchair', 'bed', 'dresser', 'desk', 'chairs', 'table',
      'tv_stand', 'tv', 'fridge', 'freezer', 'washer', 'stove', 'tires',
      'yard_equipment', 'patio', 'sport', 'boxes', 'materials', 'other',
    ]);
  });
}
