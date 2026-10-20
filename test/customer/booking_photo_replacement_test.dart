import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  testWidgets(
    'remove and replace first photo preserves other slots and item data',
    (tester) async {
      final draft = testDraft(quote: true);
      draft.data['intake_mode'] = 'photo_assisted';
      final item = draft.items.single as Map;
      final prefix = 'booking_photos/booking_test/${draft.id}/test-item';
      item['photos'] = ['$prefix/0.jpg', '$prefix/1.jpg', '$prefix/2.jpg'];
      final originalLabel = item['label'];
      final storage = MemoryBookingStorage(draft);
      final api = TestBookingApi();
      final slots = <int>[];
      await pumpBooking(
        tester,
        storage: storage,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async =>
            File('assets/home/brand_logo.png').readAsBytesSync(),
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async {
              slots.add(slot);
              return '$prefix/$slot.jpg';
            },
      );
      final remove = find.byKey(ValueKey('photo-remove-$prefix/0.jpg'));
      await tester.ensureVisible(remove);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(storage.saved!.items.single['photos'], [
        '$prefix/1.jpg',
        '$prefix/2.jpg',
      ]);
      expect(storage.saved!.items.single['label'], originalLabel);
      expect(storage.saved!.quote, isNull);
      final add = find.byKey(const ValueKey('photo-add-test-item'));
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(slots, [0]);
      expect(storage.saved!.items.single['photos'], [
        '$prefix/1.jpg',
        '$prefix/2.jpg',
        '$prefix/0.jpg',
      ]);
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(tester.takeException(), isNull);
      await disposeBooking(tester);
    },
  );
}
