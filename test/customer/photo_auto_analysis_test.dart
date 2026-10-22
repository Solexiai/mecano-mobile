import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

class AutoPhotoApi extends TestBookingApi {
  int analyses = 0;
  Map<String, dynamic>? request;
  Future<Map<String, dynamic>> Function(Map<String, dynamic>)? handler;
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name != 'analyzeBookingPhoto') return super.call(name, data);
    analyses++;
    request = data;
    return handler == null ? answer(data) : handler!(data);
  }

  Map<String, dynamic> answer(Map<String, dynamic> data) => {
    'photoPath': data['photoPath'],
    'requiresConfirmation': true,
    'measurementsVerified': false,
    'quoteAuthorized': false,
    'suggestion': {
      'category': 'sofa',
      'label': 'Divan sectionnel en tissu',
      'confidence': 'high',
      'special_handling': false,
      'reason': 'ordinary',
      'size_estimate': {
        'basis': 'typical_object',
        'confidence': 'low',
        'length_cm': {'min': 220, 'max': 320},
        'width_cm': {'min': 140, 'max': 220},
        'height_cm': {'min': 70, 'max': 100},
      },
    },
  };
}

void main() {
  final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
  testWidgets(
    'upload automatically analyzes once and saves sofa category description and advisory ranges',
    (t) async {
      final draft = testDraft()..items.clear(),
          s = MemoryBookingStorage(null),
          api = AutoPhotoApi();
      s.saved = draft;
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async => 'booking_photos/$uid/$draftId/$itemId/$slot.jpg',
      );
      await tapBooking(t, 'Commencer par une photo');
      expect(api.analyses, 1);
      final item = s.saved!.items.single;
      expect(item['category'], 'sofa');
      expect(item['label'], 'Divan sectionnel en tissu');
      expect(item['identification_confirmed'], false);
      expect(item['photo_size_hint']['length_cm'], {'min': 220, 'max': 320});
      for (final f in ['weight', 'length', 'width', 'height']) {
        expect(item[f], isNull);
      }
      expect(api.request!['consent'], true);
      expect(find.text('Utiliser cette suggestion'), findsNothing);
      final label = find.byKey(ValueKey('photo-label-${item['id']}'));
      expect(label, findsOneWidget);
      await t.ensureVisible(label);
      expect(
        t
            .widget<EditableText>(
              find.descendant(of: label, matching: find.byType(EditableText)),
            )
            .controller
            .text,
        'Divan sectionnel en tissu',
      );
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'new photo starts a new analysis and never silently confirms cargo',
    (t) async {
      final s = MemoryBookingStorage(testDraft()..items.clear()),
          api = AutoPhotoApi();
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async => 'booking_photos/$uid/$draftId/$itemId/$slot.jpg',
      );
      await tapBooking(t, 'Commencer par une photo');
      final id = s.saved!.items.single['id'];
      final add = find.byKey(ValueKey('photo-add-$id'));
      await t.ensureVisible(add);
      await t.tap(add);
      await t.pumpAndSettle();
      expect(api.analyses, 2);
      expect(api.request!['photoPath'], endsWith('/1.jpg'));
      expect(s.saved!.items.single['photos'], hasLength(2));
      expect(s.saved!.items.single['identification_confirmed'], false);
      await disposeBooking(t);
    },
  );
  testWidgets('cancelled upload never calls AI', (t) async {
    final s = MemoryBookingStorage(testDraft()..items.clear()),
        api = AutoPhotoApi();
    await pumpBooking(
      t,
      storage: s,
      api: api,
      photoIntakeEnabled: true,
      photoUploader:
          ({
            required uid,
            required draftId,
            required itemId,
            required slot,
          }) async => null,
    );
    await tapBooking(t, 'Commencer par une photo');
    expect(api.analyses, 0);
    expect(s.saved!.items, isEmpty);
    await disposeBooking(t);
  });
  testWidgets(
    'automatic failure preserves photo and explicit retry autofills without another upload',
    (t) async {
      final s = MemoryBookingStorage(testDraft()..items.clear()),
          api = AutoPhotoApi();
      api.handler = (_) async => throw StateError('private provider details');
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async => 'booking_photos/$uid/$draftId/$itemId/$slot.jpg',
      );
      await tapBooking(t, 'Commencer par une photo');
      expect(api.analyses, 1);
      expect(s.saved!.items.single['photos'], hasLength(1));
      expect(find.textContaining('Analyse indisponible.'), findsOneWidget);
      expect(find.textContaining('private provider details'), findsNothing);
      api.handler = null;
      await tapBooking(t, 'Analyser la photo');
      expect(api.analyses, 2);
      expect(s.saved!.items.single['category'], 'sofa');
      expect(find.textContaining('Analyse indisponible.'), findsNothing);
      await disposeBooking(t);
    },
  );
  testWidgets(
    'manual edit while automatic analysis is pending rejects late AI output',
    (t) async {
      final s = MemoryBookingStorage(testDraft()..items.clear()),
          api = AutoPhotoApi(),
          pending = Completer<Map<String, dynamic>>();
      api.handler = (_) => pending.future;
      await pumpBooking(
        t,
        storage: s,
        api: api,
        photoIntakeEnabled: true,
        photoLoader: (_) async => bytes,
        photoUploader:
            ({
              required uid,
              required draftId,
              required itemId,
              required slot,
            }) async => 'booking_photos/$uid/$draftId/$itemId/$slot.jpg',
      );
      final start = find.byKey(const ValueKey('photo-new-object'));
      await t.ensureVisible(start);
      await t.tap(start);
      await t.pump(const Duration(milliseconds: 800));
      await t.pump(const Duration(milliseconds: 800));
      expect(api.analyses, 1);
      final id = s.saved!.items.single['id'];
      final label = find.byKey(ValueKey('photo-label-$id'));
      await t.ensureVisible(label);
      await t.enterText(label, 'Description corrigée par le client');
      await t.pump();
      pending.complete(api.answer(api.request!));
      await t.pumpAndSettle();
      expect(
        s.saved!.items.single['label'],
        'Description corrigée par le client',
      );
      expect(s.saved!.items.single['category'], 'other');
      expect(t.takeException(), isNull);
      await disposeBooking(t);
    },
  );
}
