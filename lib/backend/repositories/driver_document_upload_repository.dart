// ---------------------------------------------------------------------------
// DriverDocumentUploadRepository — abstraction du point d'upload binaire
// Firebase Storage pour les documents chauffeur (permis, assurance, photo
// véhicule), Phase 7, Bloc U, U-0 — "dead upload button".
//
// AVANT ce correctif : les boutons "Téléverser le permis"/"Téléverser
// l'assurance"/"Photos du véhicule" de DriverOnboardingScreen étaient
// `onPressed: () {}` — aucune abstraction d'upload binaire n'existait pour
// les documents chauffeur (contrairement à `ProofUploadRepository` pour la
// preuve de livraison). `DriverRepository.submitDriverDocument()` existait
// déjà mais n'écrit QUE les métadonnées Firestore (`driver_documents/{id}`),
// jamais le fichier binaire lui-même.
//
// Ce fichier suit EXACTEMENT le même pattern que `proof_upload_repository.dart`
// (seul autre point d'upload Storage de l'app) : interface abstraite +
// implémentation `NotConfigured*` qui échoue proprement (jamais un faux
// succès), aucune nouvelle architecture parallèle.
//
// Chemin de destination : `driver_documents/{driverId}/{fileName}`, déjà
// entièrement spécifié et validé par storage.rules (Bloc P, non modifié) :
// - `create` exige `isSignedIn() && isDriver() && uid() == driverId` — ce
//   qui borne l'appel de cette méthode à un moment où le compte Firebase
//   Auth existe ET où le custom claim `driver` a déjà été accordé et
//   rafraîchi côté client (voir `DriverOnboardingScreen._handleSubmit`,
//   étapes 1-4 avant tout appel à `uploadDriverDocument`).
// - `isValidDocumentUpload()` : 10 Mo max, image OU PDF (contrairement à
//   `isValidImageUpload` utilisé par `profile_photos`/`delivery_proofs`,
//   limité aux images) — ce repository accepte donc explicitement un
//   `contentType` arbitraire (image/* ou application/pdf), laissé au choix
//   de l'appelant plutôt que restreint en dur ici.
// ---------------------------------------------------------------------------

import '../backend_exceptions.dart';

abstract class DriverDocumentUploadRepository {
  /// Upload les octets `bytes` sous `driver_documents/{driverId}/{fileName}`
  /// et retourne l'URL de téléchargement publique. Ne doit jamais avaler une
  /// exception : tout échec (réseau, permission Storage refusée — ex. claim
  /// `driver` pas encore visible, quota, etc.) doit se propager à l'appelant
  /// pour qu'aucun document fictif ne soit jamais considéré comme téléversé
  /// avec succès.
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
