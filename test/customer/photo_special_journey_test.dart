import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/booking_load_summary.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
  Map<String, dynamic> item() => {
    'id': 'special',
    'category': 'materials',
    'label': 'Matériaux fictifs',
    'quantity': 1,
    'length': 120,
    'width': 40,
    'height': 30,
    'weight': null,
    'dimension_unit': 'cm',
    'weight_unit': 'kg',
    'approximate': true,
    'upright': true,
    'photos': <String>['booking_photos/booking_test/test-draft/special/0.jpg'],
    'identification_confirmed': true,
    'special_handling': true,
    'handling_notes': 'Garder les pièces attachées.',
  };
  testWidgets(
    'special handling details are editable and survive draft quote and confirmation',
    (t) async {
      final draft = testDraft();
      draft.data['intake_mode'] = 'photo_assisted';
      draft.items
        ..clear()
        ..add(item());
      final storage = MemoryBookingStorage(draft), api = TestBookingApi();
      api.quote['booking'] = {
        'vehicle_assessment': 'driver_photo_review',
        'load': {
          'items': [...draft.items],
          'pickup': {},
          'dropoff': {},
          'handlers': 1,
          'equipment': [],
        },
      };
      await pumpBooking(
        t,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
      );
      final notes = find.byKey(const ValueKey('photo-special-handling-notes'));
      expect(notes, findsOneWidget);
      await t.ensureVisible(notes);
      await t.enterText(notes, 'Pièces attachées, accès au sol.');
      await t.pumpAndSettle();
      expect(
        storage.saved!.items.single['handling_notes'],
        'Pièces attachées, accès au sol.',
      );
      await tapBooking(t, 'Voir mon prix');
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      await tapBooking(t, 'Continuer vers mes coordonnées');
      await tapBooking(t, 'Vérifier et confirmer');
      final acceptance = find.byKey(
        const ValueKey('booking-contract-acceptance'),
      );
      expect(acceptance, findsOneWidget);
      expect(t.widget<CheckboxListTile>(acceptance).onChanged, isNotNull);
      await t.ensureVisible(acceptance);
      await t.tap(acceptance);
      await t.pumpAndSettle();
      expect(t.widget<CheckboxListTile>(acceptance).value, isTrue);
      await tapBooking(t, 'Confirmer ma demande de livraison');
      final sent = api.payloads[api.calls.indexOf('createDeliveryRequest')];
      final sentItem =
          ((sent['booking'] as Map)['items'] as List).single as Map;
      expect(sentItem['handling_notes'], 'Pièces attachées, accès au sol.');
      expect(sentItem['weight'], isNull);
      expect(sent['quoteId'], 'test_quote');
      expect(sent.containsKey('customerTotal'), isFalse);
      expect(
        api.calls.where((x) => x == 'createDeliveryRequest'),
        hasLength(1),
      );
      expect(storage.saved!.data['missionId'], 'test_mission');
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  for (final locale in ['fr', 'en', 'es']) {
    for (final scenario in [
      (375.0, 812.0, 1.0),
      (430.0, 932.0, 1.0),
      (1440.0, 900.0, 1.0),
      (375.0, 812.0, 2.0),
    ]) {
      testWidgets('special details and driver summary $locale $scenario', (
        t,
      ) async {
        t.view.physicalSize = Size(scenario.$1, scenario.$2);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final cargo = item();
        await t.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scenario.$3)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      PhotoBookingItem(
                        item: cargo,
                        locale: locale,
                        categories: const [('materials', 'Materials')],
                        onChanged: () {},
                        onRemove: () {},
                        onAddPhoto: () {},
                        photoLoader: (_) async => bytes,
                      ),
                      BookingLoadSummary(
                        snapshot: {
                          'vehicle_assessment': 'driver_photo_review',
                          'load': {
                            'items': [cargo],
                            'pickup': {},
                            'dropoff': {},
                            'handlers': 1,
                            'equipment': [],
                          },
                        },
                        locale: locale,
                        photoLoader: (_) async => bytes,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('photo-special-handling-notes')),
          findsOneWidget,
        );
        expect(find.text('Garder les pièces attachées.'), findsWidgets);
        expect(t.takeException(), isNull);
        await t.pumpWidget(const SizedBox());
        await t.pumpAndSettle();
      });
    }
  }
}
