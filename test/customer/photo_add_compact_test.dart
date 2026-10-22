import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/widgets/photo_booking_item.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
  testWidgets(
    'cancelling repeated new photos does not accumulate empty items',
    (t) async {
      final draft = testDraft()..items.clear();
      final storage = MemoryBookingStorage(draft);
      var calls = 0;
      await pumpBooking(
        t,
        storage: storage,
        api: TestBookingApi(),
        photoIntakeEnabled: true,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async {
              calls++;
              return null;
            },
      );
      for (var i = 0; i < 3; i++) {
        await tapBooking(t, 'Commencer par une photo');
        expect(storage.saved!.items, isEmpty);
        expect(find.byType(PhotoBookingItem), findsNothing);
      }
      expect(calls, 3);
      await disposeBooking(t);
    },
  );

  testWidgets(
    'plus adds photos to the same item, another item is explicit, cap remains three',
    (t) async {
      final draft = testDraft()..items.clear();
      final storage = MemoryBookingStorage(draft);
      final uploads = <String>[];
      await pumpBooking(
        t,
        storage: storage,
        api: TestBookingApi(),
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async {
              uploads.add('$itemId/$slot');
              return 'booking_photos/$uid/$draftId/$itemId/$slot.jpg';
            },
      );
      await tapBooking(t, 'Commencer par une photo');
      final id = storage.saved!.items.single['id'];
      for (var n = 2; n <= 3; n++) {
        final plus = find.byKey(ValueKey('photo-add-$id'));
        await t.ensureVisible(plus);
        await t.tap(plus);
        await t.pumpAndSettle();
        expect(storage.saved!.items, hasLength(1));
        expect(storage.saved!.items.single['photos'], hasLength(n));
      }
      expect(find.byKey(ValueKey('photo-add-$id')), findsNothing);
      expect(uploads, ['$id/0', '$id/1', '$id/2']);
      await tapBooking(t, 'Ajouter un autre objet');
      expect(storage.saved!.items, hasLength(2));
      expect(storage.saved!.items.first['id'], id);
      expect(storage.saved!.items.first['photos'], hasLength(3));
      expect(storage.saved!.items.last['photos'], hasLength(1));
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );

  testWidgets(
    'old empty photo item remains preserved and compact when selection is cancelled',
    (t) async {
      final draft = testDraft();
      draft.data['intake_mode'] = 'photo_assisted';
      final item = Map<String, dynamic>.from(draft.items.single as Map);
      draft.items[0] = item;
      item.addAll({
        'category': 'other',
        'label': 'Autre objet',
        'quantity': 1,
        'photos': <String>[],
        'length': null,
        'width': null,
        'height': null,
        'weight': null,
        'identification_confirmed': false,
        'special_handling': false,
        'approximate': false,
        'upright': true,
      });
      final storage = MemoryBookingStorage(draft);
      await pumpBooking(
        t,
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
      final card = find.byKey(ValueKey('photo-item-${item['id']}'));
      expect(t.getSize(card).height, lessThan(150));
      await tapBooking(t, 'Ajouter un autre objet');
      expect(storage.saved!.items, hasLength(1));
      expect(storage.saved!.items.single['id'], item['id']);
      expect(storage.saved!.items.single['photos'], isEmpty);
      await disposeBooking(t);
    },
  );

  testWidgets(
    'failed upload removes only the new empty item and preserves earlier cargo',
    (t) async {
      final draft = testDraft();
      final original = Map<String, dynamic>.from(draft.items.single as Map);
      final storage = MemoryBookingStorage(draft);
      await pumpBooking(
        t,
        storage: storage,
        api: TestBookingApi(),
        photoIntakeEnabled: true,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async => throw StateError('simulated upload failure'),
      );
      await tapBooking(t, 'Commencer par une photo');
      expect(storage.saved!.items, hasLength(1));
      for (final key in original.keys) {
        expect(storage.saved!.items.single[key], original[key]);
      }
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
}
