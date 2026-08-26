// ---------------------------------------------------------------------------
// DriverDocumentUploadRepository — abstraction du point d'upload binaire vers
// Firebase Storage pour les documents chauffeur (permis, assurance, photo
// véhicule). Phase 7, Bloc U, U-0 — "dead upload button" (BUG-U-01).
//
// AVANT CE FICHIER : les boutons "Téléverser le permis"/"Téléverser
// l'assurance"/"Photos du véhicule" de `DriverOnboardingScreen` avaient
// `onPressed: () {}` — aucun mécanisme d'upload n'existait, alors qu'aucune
// autre voie fonctionnelle de fournir ces documents n'existe ailleurs dans
// l'app (grep exhaustif de `driver_status_screen.dart` : 0 occurrence de
// submitDriverDocument/ImagePicker/pickImage/DriverDocument).
//
// RÈGLE RESPECTÉE (cf. ProofUploadRepository, même pattern EXACT, seule
// différence : contentType peut être image OU application/pdf, et le
// chemin cible est `driver_documents/{driverId}/{fileName}` au lieu de
// `delivery_proofs/{missionId}/{fileName}` — chemin déjà spécifié et
// validé par storage.rules, Bloc P, NON modifié ici) : cette abstraction ne
// fait QUE fournir un seam de test pour un appel Storage réel, elle ne crée
// aucune architecture parallèle.
// ---------------------------------------------------------------------------

import '../backend_exceptions.dart';

abstract class DriverDocumentUploadRepository {
  /// Upload les octets `bytes` sous `driver_documents/{driverId}/{fileName}`
  /// et retourne l'URL de téléchargement. Ne doit jamais avaler une
  /// exception : tout échec (réseau, permission Storage refusée car le
  /// custom claim `driver` n'est pas encore visible, quota, etc.) doit se
  /// propager à l'appelant pour qu'aucun document fictif ne soit jamais
  /// considéré comme téléversé avec succès.
  Future<String> uploadDriverDocument({
    required String driverId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  });
}

class NotConfiguredDriverDocumentUploadRepository
    implements DriverDocumentUploadRepository {
  const NotConfiguredDriverDocumentUploadRepository();

  @override
  Future<String> uploadDriverDocument({
    required String driverId,
    required String fileName,
    required List<int> bytes,
    required String contentType,
  }) {
    throw BackendNotConfiguredException(
      'uploadDriverDocument: backend Firebase Storage non configuré.',
    );
  }
}
