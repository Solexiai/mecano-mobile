import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class BookingPhotoFormatException implements Exception {}

Future<String?> uploadBookingPhoto({
  required String uid,
  required String draftId,
  required String itemId,
  required int slot,
}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1600,
    imageQuality: 82,
  );
  if (file == null) return null;
  final bytes = await file.readAsBytes();
  // Explicit JPEG signature; reject instead of mislabelling HEIC/PNG/SVG.
  if (bytes.length > 5 * 1024 * 1024 ||
      bytes.length < 3 ||
      bytes[0] != 0xff ||
      bytes[1] != 0xd8 ||
      bytes[2] != 0xff) {
    throw BookingPhotoFormatException();
  }
  final path = 'booking_photos/$uid/$draftId/$itemId/$slot.jpg';
  await FirebaseStorage.instance
      .ref(path)
      .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
  return path; // No public download URL or bearer token is stored.
}
