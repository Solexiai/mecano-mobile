import 'dart:typed_data';
import 'booking_photo_encoder_stub.dart'
    if (dart.library.js_interop) 'booking_photo_encoder_web.dart'
    as encoder;

const maxBookingPhotoInputBytes = 20 * 1024 * 1024;
const maxBookingPhotoStoredBytes = 5 * 1024 * 1024;

enum BookingPhotoFailure {
  unsupportedFormat,
  inputTooLarge,
  processingFailed,
  outputTooLarge,
}

class BookingPhotoFormatException implements Exception {
  const BookingPhotoFormatException([
    this.reason = BookingPhotoFailure.unsupportedFormat,
  ]);
  final BookingPhotoFailure reason;
}

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
  if (bytes.length > maxBookingPhotoInputBytes) {
    throw const BookingPhotoFormatException(BookingPhotoFailure.inputTooLarge);
  }
  if (mime == null) {
    throw const BookingPhotoFormatException();
  }
  try {
    final result = await (encode ?? encoder.encodeBookingPhoto)(bytes, mime);
    if (result.length > maxBookingPhotoStoredBytes) {
      throw const BookingPhotoFormatException(
        BookingPhotoFailure.outputTooLarge,
      );
    }
    if (bookingPhotoMime(result) != 'image/jpeg') {
      throw const BookingPhotoFormatException(
        BookingPhotoFailure.processingFailed,
      );
    }
    return result;
  } on BookingPhotoFormatException {
    rethrow;
  } catch (_) {
    throw const BookingPhotoFormatException(
      BookingPhotoFailure.processingFailed,
    );
  }
}
