// ---------------------------------------------------------------------------
// FirebaseDriverDocumentUploadRepository — implémentation RÉELLE de
// DriverDocumentUploadRepository (Phase 7, Bloc U, U-0). Même structure que
// `FirebaseProofUploadRepository` : un seul appel Storage direct, chemin
// fixe déjà validé par storage.rules, aucune logique métier supplémentaire
// ici (la Firestore metadata est écrite séparément par
// `DriverRepository.submitDriverDocument()`).
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
