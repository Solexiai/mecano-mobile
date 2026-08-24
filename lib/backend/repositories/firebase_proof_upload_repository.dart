// ---------------------------------------------------------------------------
// FirebaseProofUploadRepository — implémentation RÉELLE de
// ProofUploadRepository. Reproduit EXACTEMENT l'appel Storage qui vivait
// auparavant en dur dans `DriverActiveMissionScreen` (même chemin, même
// `SettableMetadata(contentType: ...)`) — aucun changement de comportement,
// seulement une indirection permettant l'injection d'un fake en test (voir
// `BackendLocator.proofUploadRepositoryOverride`).
// ---------------------------------------------------------------------------

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import 'proof_upload_repository.dart';

class FirebaseProofUploadRepository implements ProofUploadRepository {
  FirebaseProofUploadRepository({FirebaseStorage? storage})
      : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  Future<String> uploadDeliveryProof({
    required String missionId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) async {
    final ref = _storage
        .ref()
        .child('delivery_proofs')
        .child(missionId)
        .child(fileName);
    await ref.putData(
      Uint8List.fromList(bytes),
      SettableMetadata(contentType: contentType),
    );
    return ref.getDownloadURL();
  }
}
