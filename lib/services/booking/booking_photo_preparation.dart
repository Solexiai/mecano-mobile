import 'dart:typed_data';
import 'booking_photo_encoder_stub.dart'
    if (dart.library.js_interop) 'booking_photo_encoder_web.dart'
    as encoder;

const maxBookingPhotoInputBytes = 20 * 1024 * 1024;
const maxBookingPhotoStoredBytes = 5 * 1024 * 1024;

class BookingPhotoFormatException implements Exception {}

typedef BookingPhotoEncoder =
    Future<Uint8List> Function(Uint8List bytes, String mimeType);
String? bookingPhotoMime(Uint8List b) {
  if (b.length >= 3 && b[0] == 255 && b[1] == 216 && b[2] == 255) {
    return 'image/jpeg';
  }
  if (b.length >= 8 &&
      b[0] == 137 &&
      b[1] == 80 &&
      b[2] == 78 &&
      b[3] == 71 &&
      b[4] == 13 &&
      b[5] == 10 &&
      b[6] == 26 &&
      b[7] == 10) {
    return 'image/png';
  }
  if (b.length >= 12 &&
      String.fromCharCodes(b.sublist(0, 4)) == 'RIFF' &&
      String.fromCharCodes(b.sublist(8, 12)) == 'WEBP') {
    return 'image/webp';
  }
  return null;
}

Future<Uint8List> prepareBookingPhotoBytes(
  Uint8List bytes, {
  BookingPhotoEncoder? encode,
}) async {
  final mime = bookingPhotoMime(bytes);
  if (bytes.length > maxBookingPhotoInputBytes || mime == null) {
    throw BookingPhotoFormatException();
  }
  try {
    final result = await (encode ?? encoder.encodeBookingPhoto)(bytes, mime);
    if (result.length > maxBookingPhotoStoredBytes ||
        bookingPhotoMime(result) != 'image/jpeg') {
      throw BookingPhotoFormatException();
    }
    return result;
  } catch (_) {
    throw BookingPhotoFormatException();
  }
}
