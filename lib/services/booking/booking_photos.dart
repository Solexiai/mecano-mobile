import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'booking_photo_preparation.dart';
export 'booking_photo_preparation.dart' show BookingPhotoFormatException;

typedef BookingPhotoUploader =
    Future<String?> Function({
      required String uid,
      required String draftId,
      required String itemId,
      required int slot,
    });
Future<String?> uploadBookingPhoto({
  required String uid,
  required String draftId,
  required String itemId,
  required int slot,
}) async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: kIsWeb ? null : 1600,
    imageQuality: kIsWeb ? 100 : 82,
  );
  if (file == null) return null;
  if (await file.length() > maxBookingPhotoInputBytes) {
    throw BookingPhotoFormatException();
  }
  final bytes = await prepareBookingPhotoBytes(await file.readAsBytes());
  final path = 'booking_photos/$uid/$draftId/$itemId/$slot.jpg';
  await FirebaseStorage.instance
      .ref(path)
      .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
  return path;
}
