import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

class PhotoFlowApi extends TestBookingApi {
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    final result = await super.call(name, data);
    if (name == 'reviewDeliveryLoad') {
      return {
        ...result,
        'compatible_categories': ['cargo_van', 'pickup_truck'],
      };
    }
    return result;
  }
}

void main() {
  final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
  testWidgets(
    'photo to simulated quote keeps unknowns, category and server price',
    (tester) async {
      final draft = testDraft();
      draft.items.clear();
      final storage = MemoryBookingStorage(draft);
      final api = PhotoFlowApi();
      api.quote['booking'] = {
        'vehicle_assessment': 'driver_photo_review',
        'load': {
          'items': [],
          'pickup': {},
          'dropoff': {},
          'handlers': 1,
          'equipment': [],
        },
      };
      final uploads = <String>[];
      await pumpBooking(
        tester,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async {
              uploads.add('$uid/$draftId/$itemId/$slot');
              return 'booking_photos/$uid/$draftId/$itemId/$slot.jpg';
            },
      );
      await tapBooking(tester, 'Commencer par une photo');
      expect(uploads.length, 1);
      expect(storage.saved!.items.length, 1);
      final id = storage.saved!.items.first['id'];
      final category = find.byKey(ValueKey('photo-category-$id'));
      await tester.ensureVisible(category);
      await tester.tap(category);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Divan / sofa / sectionnel').last);
      await tester.pumpAndSettle();
      await tapBooking(tester, 'Dimensions et précautions (facultatif)');
      final label = find.byKey(ValueKey('photo-label-$id'));
      await tester.ensureVisible(label);
      await tester.enterText(label, 'Canapé fictif');
      await tester.pumpAndSettle();
      final confirm = find.byKey(ValueKey('photo-confirm-$id'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      await tapBooking(tester, 'Voir mon prix');
      final index = api.calls.lastIndexOf('calculateDeliveryQuote');
      expect(index, greaterThanOrEqualTo(0));
      final booking = api.payloads[index]['booking'] as Map;
      expect(booking['intake_mode'], 'photo_assisted');
      final item = (booking['items'] as List).single as Map;
      expect(item['category'], 'sofa');
      expect(item['identification_confirmed'], true);
      for (final field in ['length', 'width', 'height', 'weight']) {
        expect(item[field], isNull);
      }
      expect(item['photos'], hasLength(1));
      expect(api.payloads[index]['requestedVehicleCategory'], isNull);
      expect(storage.saved!.quote!['customerTotal'], 123.45);
      expect(find.text('Autre catégorie compatible'), findsNothing);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(tester.takeException(), isNull);
      await disposeBooking(tester);
    },
  );
  testWidgets('cancelled photo picker adds no fake photo or estimate', (
    tester,
  ) async {
    final draft = testDraft();
    draft.items.clear();
    final storage = MemoryBookingStorage(draft);
    await pumpBooking(
      tester,
      storage: storage,
      api: TestBookingApi(),
      photoIntakeEnabled: true,
      photoUploader:
          ({
            required uid,
            required draftId,
            required itemId,
            required slot,
          }) async => null,
    );
    await tapBooking(tester, 'Commencer par une photo');
    expect(storage.saved!.items, isEmpty);
    await disposeBooking(tester);
  });
  testWidgets(
    'late upload after widget disposal never mutates persisted draft',
    (tester) async {
      final pending = Completer<String?>();
      final draft = testDraft();
      draft.items.clear();
      final storage = MemoryBookingStorage(draft);
      await pumpBooking(
        tester,
        storage: storage,
        api: TestBookingApi(),
        photoIntakeEnabled: true,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) => pending.future,
      );
      final button = find.text('Commencer par une photo');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pumpWidget(const SizedBox());
      pending.complete('late-fake-path');
      await tester.pumpAndSettle();
      expect(storage.saved!.items.single['photos'], isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('photo rollout is hidden by default', (tester) async {
    await pumpBooking(
      tester,
      storage: MemoryBookingStorage(testDraft()),
      api: TestBookingApi(),
    );
    expect(find.text('Commencer par une photo'), findsNothing);
    await disposeBooking(tester);
  });
}
