// ---------------------------------------------------------------------------
// FirebaseDriverDocumentUploadRepository — implémentation RÉELLE de
// DriverDocumentUploadRepository. Même pattern EXACT que
// FirebaseProofUploadRepository (Phase 5/Bloc C) : `putData` +
// `SettableMetadata(contentType: ...)` + `getDownloadURL()`. Chemin cible
// (`driver_documents/{driverId}/{fileName}`) déjà validé par storage.rules
// (Bloc P) — non modifié ici.
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'driver_document_upload_repository.dart';

class FirebaseDriverDocumentUploadRepository
    implements DriverDocumentUploadRepository {
  FirebaseDriverDocumentUploadRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadDriverDocument({
    required String driverId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    final ref = _storage
        .ref()
        .child('driver_documents')
        .child(driverId)
        .child(fileName);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }
}
