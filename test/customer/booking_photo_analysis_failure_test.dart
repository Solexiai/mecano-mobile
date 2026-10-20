import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../helpers/booking_test_harness.dart';

class UnavailablePhotoAnalysis extends TestBookingApi {
  @override
  Future<Map<String, dynamic>> call(
    String name, [
    Map<String, dynamic> data = const {},
  ]) async {
    if (name == 'analyzeBookingPhoto') {
      throw StateError('simulated analysis unavailable');
    }
    return super.call(name, data);
  }
}

void main() {
  testWidgets(
    'AI failure retains previews and permits another object and reload',
    (tester) async {
      final draft = testDraft()..items.clear();
      final storage = MemoryBookingStorage(draft);
      final api = UnavailablePhotoAnalysis();
      final bytes = File('assets/home/brand_logo.png').readAsBytesSync();
      Future<void> open() => pumpBooking(
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
            }) async => 'booking_photos/$uid/$draftId/$itemId/$slot.jpg',
      );
      await open();
      await tapBooking(tester, 'Commencer par une photo');
      expect(find.textContaining('Analyse indisponible.'), findsOneWidget);
      expect(storage.saved!.items.single['photos'], hasLength(1));
      await tapBooking(tester, 'Ajouter un autre objet');
      expect(storage.saved!.items, hasLength(2));
      expect(
        storage.saved!.items.every(
          (item) => (item['photos'] as List).length == 1,
        ),
        isTrue,
      );
      expect(find.byTooltip('Retirer cette photo'), findsNWidgets(2));
      expect(api.calls, isNot(contains('createDeliveryRequest')));
      await disposeBooking(tester);
      await open();
      expect(storage.saved!.items, hasLength(2));
      expect(find.byTooltip('Retirer cette photo'), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await disposeBooking(tester);
    },
  );
}
