import 'dart:typed_data';

// Native image_picker already resizes JPEGs; Web uses an explicit local encoder.
Future<Uint8List> encodeBookingPhoto(Uint8List bytes, String mimeType) async {
  if (mimeType != 'image/jpeg') {
    throw const FormatException('Unsupported native image');
  }
  return bytes;
}
