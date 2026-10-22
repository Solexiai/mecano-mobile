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

/// Opens the system photo picker.
///
/// Must be the FIRST awaited call after the user's tap: iOS Safari only lets a
/// page open a file dialog during the user gesture, and any earlier network
/// await (draft save, token refresh…) makes the dialog silently not open.
Future<XFile?> pickBookingPhoto() => ImagePicker().pickImage(
  source: ImageSource.gallery,
  maxWidth: kIsWeb ? null : 1600,
  imageQuality: kIsWeb ? 100 : 82,
);

/// Converts an already-picked photo to JPEG (≤ 5 MB) and stores it at the
/// only path accepted by storage.rules and the server.
Future<String> storeBookingPhoto(
  XFile file, {
  required String uid,
  required String draftId,
  required String itemId,
  required int slot,
}) async {
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

/// Pick then store in one step. Only safe where nothing is awaited before it.
Future<String?> uploadBookingPhoto({
  required String uid,
  required String draftId,
  required String itemId,
  required int slot,
}) async {
  final file = await pickBookingPhoto();
  if (file == null) return null;
  return storeBookingPhoto(
    file,
    uid: uid,
    draftId: draftId,
    itemId: itemId,
    slot: slot,
  );
}
