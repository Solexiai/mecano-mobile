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

/// Open the native picker directly from the user's gesture, before network I/O.
/// No capture attribute on web: the browser offers camera/library as supported.
/// The returned upload action must only run after draft ownership is saved.
Future<BookingPhotoUploader?> selectBookingPhotoUpload() async {
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
  return ({
    required String uid,
    required String draftId,
    required String itemId,
    required int slot,
  }) async {
    final path = 'booking_photos/$uid/$draftId/$itemId/$slot.jpg';
    await FirebaseStorage.instance
        .ref(path)
        .putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return path;
  };
}

Future<String?> uploadBookingPhoto({
  required String uid,
  required String draftId,
  required String itemId,
  required int slot,
}) async {
  final upload = await selectBookingPhotoUpload();
  return upload == null
      ? null
      : upload(uid: uid, draftId: draftId, itemId: itemId, slot: slot);
}
