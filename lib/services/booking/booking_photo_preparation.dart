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
  // ISO-BMFF "ftyp" box: iPhone HEIC/HEIF photos. Decoded by the browser
  // (Safari on iOS/macOS) and re-encoded to JPEG; other browsers fail cleanly.
  if (b.length >= 12 && String.fromCharCodes(b.sublist(4, 8)) == 'ftyp') {
    final brand = String.fromCharCodes(b.sublist(8, 12));
    if (const {'heic', 'heix', 'hevc', 'hevx', 'heim', 'heis', 'mif1', 'msf1'}
        .contains(brand)) {
      return 'image/heic';
    }
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
