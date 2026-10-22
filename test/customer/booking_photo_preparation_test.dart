import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_photo_preparation.dart';

void main() {
  final jpeg = Uint8List.fromList([255, 216, 255, 1]);
  for (final bytes in [
    jpeg,
    Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 0]),
    Uint8List.fromList([82, 73, 70, 70, 0, 0, 0, 0, 87, 69, 66, 80]),
  ]) {
    test(
      'accepted signature ${bytes.take(4)} converted to private JPEG',
      () async {
        String? observed;
        final result = await prepareBookingPhotoBytes(
          bytes,
          encode: (b, m) async {
            observed = m;
            return jpeg;
          },
        );
        expect(observed, isNotNull);
        expect(result, jpeg);
      },
    );
  }
  test(
    '20 MiB source allowed before resizing; no upload of original',
    () async {
      final b = Uint8List(maxBookingPhotoInputBytes)
        ..setRange(0, 3, [255, 216, 255]);
      var calls = 0;
      final result = await prepareBookingPhotoBytes(
        b,
        encode: (_, __) async {
          calls++;
          return jpeg;
        },
      );
      expect(calls, 1);
      expect(result.length, 4);
      expect(b.length, maxBookingPhotoInputBytes);
    },
  );
  test('over 20 MiB rejected before decoding', () async {
    final b = Uint8List(maxBookingPhotoInputBytes + 1)
      ..setRange(0, 3, [255, 216, 255]);
    var calls = 0;
    await expectLater(
      prepareBookingPhotoBytes(
        b,
        encode: (_, __) async {
          calls++;
          return jpeg;
        },
      ),
      throwsA(isA<BookingPhotoFormatException>()),
    );
    expect(calls, 0);
  });
  test('iPhone HEIC is detected and handed to the encoder as image/heic', () async {
    // ....ftypheic
    final heic = Uint8List.fromList(
      [0, 0, 0, 24, ...'ftyp'.codeUnits, ...'heic'.codeUnits, 0, 0],
    );
    expect(bookingPhotoMime(heic), 'image/heic');
    String? observed;
    final result = await prepareBookingPhotoBytes(
      heic,
      encode: (b, m) async {
        observed = m;
        return jpeg;
      },
    );
    expect(observed, 'image/heic');
    expect(result, jpeg);
  });
  test('non-image ISO-BMFF (mp4) is not treated as a photo', () {
    final mp4 = Uint8List.fromList(
      [0, 0, 0, 24, ...'ftyp'.codeUnits, ...'isom'.codeUnits, 0, 0],
    );
    expect(bookingPhotoMime(mp4), isNull);
  });
  test('unsupported SVG is not decoded', () async {
    await expectLater(
      prepareBookingPhotoBytes(Uint8List.fromList('<svg/>'.codeUnits)),
      throwsA(isA<BookingPhotoFormatException>()),
    );
  });
  test(
    'oversize encoded image refused; no weakening of server storage cap',
    () async {
      final large = Uint8List(maxBookingPhotoStoredBytes + 1)
        ..setRange(0, 3, [255, 216, 255]);
      await expectLater(
        prepareBookingPhotoBytes(jpeg, encode: (_, __) async => large),
        throwsA(isA<BookingPhotoFormatException>()),
      );
    },
  );
  test('decoder error stays neutral', () async {
    await expectLater(
      prepareBookingPhotoBytes(
        jpeg,
        encode: (_, __) async => throw StateError('private'),
      ),
      throwsA(isA<BookingPhotoFormatException>()),
    );
  });
}
