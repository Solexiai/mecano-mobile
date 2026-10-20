import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_photo_preparation.dart';
import '../helpers/booking_test_harness.dart';

void main() {
  final jpeg = Uint8List.fromList([255, 216, 255, 1]);
  Matcher failure(BookingPhotoFailure reason) =>
      isA<BookingPhotoFormatException>().having(
        (e) => e.reason,
        'reason',
        reason,
      );

  test('input size and unsupported format have distinct reasons', () async {
    await expectLater(
      prepareBookingPhotoBytes(Uint8List(maxBookingPhotoInputBytes + 1)),
      throwsA(failure(BookingPhotoFailure.inputTooLarge)),
    );
    await expectLater(
      prepareBookingPhotoBytes(Uint8List.fromList('<svg/>'.codeUnits)),
      throwsA(failure(BookingPhotoFailure.unsupportedFormat)),
    );
  });

  test('decoder failure is not reported as an unsupported format', () async {
    await expectLater(
      prepareBookingPhotoBytes(
        jpeg,
        encode: (_, __) async => throw StateError('private'),
      ),
      throwsA(failure(BookingPhotoFailure.processingFailed)),
    );
    await expectLater(
      prepareBookingPhotoBytes(jpeg, encode: (_, __) async => Uint8List(0)),
      throwsA(failure(BookingPhotoFailure.processingFailed)),
    );
  });

  test('encoded output limit remains enforced with its own reason', () async {
    await expectLater(
      prepareBookingPhotoBytes(
        jpeg,
        encode: (_, __) async => Uint8List(maxBookingPhotoStoredBytes + 1),
      ),
      throwsA(failure(BookingPhotoFailure.outputTooLarge)),
    );
  });

  final cases = {
    BookingPhotoFailure.unsupportedFormat:
        'Ce format de photo n’est pas pris en charge.',
    BookingPhotoFailure.inputTooLarge: 'Cette photo dépasse 20 Mo.',
    BookingPhotoFailure.processingFailed:
        'Le navigateur n’a pas pu préparer cette photo.',
    BookingPhotoFailure.outputTooLarge:
        'Cette photo reste trop volumineuse après préparation.',
  };
  for (final entry in cases.entries) {
    testWidgets(
      'photo error ${entry.key.name} preserves request and permits retry',
      (tester) async {
        final draft = testDraft()..items.clear();
        final originalPickup = draft.data['pickup'];
        final storage = MemoryBookingStorage(draft);
        final api = TestBookingApi();
        var attempts = 0;
        await pumpBooking(
          tester,
          storage: storage,
          api: api,
          photoIntakeEnabled: true,
          photoUploader:
              ({
                required uid,
                required draftId,
                required itemId,
                required slot,
              }) async {
                attempts++;
                throw BookingPhotoFormatException(entry.key);
              },
        );
        for (var i = 0; i < 2; i++) {
          await tapBooking(tester, 'Commencer par une photo');
          expect(find.textContaining(entry.value), findsOneWidget);
        }
        expect(attempts, 2);
        expect(storage.saved!.data['pickup'], originalPickup);
        expect(storage.saved!.items, isEmpty);
        expect(api.calls, isNot(contains('analyzeBookingPhoto')));
        expect(api.calls, isNot(contains('createDeliveryRequest')));
        expect(tester.takeException(), isNull);
        await disposeBooking(tester);
      },
    );
  }
}
