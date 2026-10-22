@TestOn('browser')
library;

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/booking/booking_photo_preparation.dart';

void main() {
  test(
    'real browser converts valid PNG to JPEG without mocked encoder',
    () async {
      final png = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
      );
      final result = await prepareBookingPhotoBytes(Uint8List.fromList(png));
      expect(bookingPhotoMime(result), 'image/jpeg');
      expect(result.length, lessThan(maxBookingPhotoStoredBytes));
    },
  );
}
