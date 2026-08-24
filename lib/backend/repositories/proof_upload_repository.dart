// ---------------------------------------------------------------------------
// ProofUploadRepository — abstraction du SEUL point d'upload binaire vers
// Firebase Storage utilisé par l'app (preuve de livraison, Phase 5 partie
// 3). Extraite de `DriverActiveMissionScreen._capturePhotoAndCompleteDelivery`
// (Phase 7, Bloc C, ACTION — "proof upload failure") : jusqu'ici l'écran
// appelait `FirebaseStorage.instance` DIRECTEMENT, sans aucun seam de test
// (contrairement à `MissionRepository`/`LocationRepository`), ce qui rendait
// impossible de simuler un échec d'upload sans dépendre d'un vrai bucket
// Firebase Storage.
//
// RÈGLE RESPECTÉE : cette abstraction ne fait QUE déplacer l'appel Storage
// existant derrière une interface — elle ne change ni le chemin de
// destination (`delivery_proofs/{missionId}/{fileName}`, toujours validé
// par storage.rules), ni le comportement métier (aucune Cloud Function
// n'est appelée ici ; `markDeliveryCompleted()` reste géré séparément par
// `MissionRepository`).
// ---------------------------------------------------------------------------

import '../backend_exceptions.dart';

abstract class ProofUploadRepository {
  /// Upload les octets `bytes` sous `delivery_proofs/{missionId}/{fileName}`
  /// et retourne l'URL de téléchargement publique. Ne doit jamais avaler une
  /// exception : tout échec (réseau, permission Storage refusée, quota,
  /// etc.) doit se propager à l'appelant pour qu'aucune preuve fictive ne
  /// soit jamais considérée comme uploadée avec succès.
  Future<String> uploadDeliveryProof({
    required String missionId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  });
}

class NotConfiguredProofUploadRepository implements ProofUploadRepository {
  const NotConfiguredProofUploadRepository();

  @override
  Future<String> uploadDeliveryProof({
    required String missionId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) {
    throw BackendNotConfiguredException(
      'uploadDeliveryProof: backend Firebase Storage non configuré.',
    );
  }
}
