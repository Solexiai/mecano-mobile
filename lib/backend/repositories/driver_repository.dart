// ---------------------------------------------------------------------------
// DriverRepository — interface abstraite découplant les écrans Flutter de
// l'implémentation concrète (Firebase ou NotConfigured).
//
// RÈGLE : aucune méthode d'écriture sensible (approve/reject, changement de
// statut Founding Driver, changement de commission) n'existe ici avec une
// implémentation "directe" — ces opérations DOIVENT être des appels à des
// Cloud Functions (voir lib/backend/repositories/cloud_functions_gateway.dart,
// à créer lors du branchement Firebase réel). Ce repository n'expose que de
// la LECTURE et des écritures non sensibles (ex: soumettre des documents).
// ---------------------------------------------------------------------------

import '../models/driver_profile_v2.dart';
import '../models/driver_document.dart';
import '../models/driver_vehicle.dart';
import '../backend_exceptions.dart';

abstract class DriverRepository {
  /// Retourne le profil chauffeur, ou null s'il n'existe pas encore.
  Future<DriverProfileV2?> getDriverProfile(String driverId);

  /// Flux temps réel du profil chauffeur (statut d'approbation, etc.).
  Stream<DriverProfileV2?> watchDriverProfile(String driverId);

  Future<List<DriverDocument>> getDriverDocuments(String driverId);

  Stream<List<DriverDocument>> watchDriverDocuments(String driverId);

  Future<List<DriverVehicle>> getDriverVehicles(String driverId);

  /// Enregistre les métadonnées d'un document après upload réussi dans
  /// Firebase Storage (le fichier binaire est géré séparément par le
  /// service de Storage, pas par ce repository).
  Future<void> submitDriverDocument(DriverDocument document);

  /// Crée ou met à jour le profil d'onboarding initial d'un chauffeur
  /// (statut de départ = registrationIncomplete / pendingReview, jamais
  /// "approved" — ce statut ne peut être positionné à approved que par la
  /// Cloud Function approveDriver()).
  Future<void> submitDriverOnboarding(DriverProfileV2 profile);

  /// Fait transitionner le profil de registration_incomplete/
  /// documents_required vers pending_review, via la Cloud Function
  /// `submitDriverForReview` (le client ne peut jamais écrire `status`
  /// directement — voir firestore.rules).
  Future<void> submitForReview();

  /// Liste des chauffeurs en attente de revue (pour le portail analyste).
  /// Nécessite le rôle analyst/admin/super_admin côté serveur (Security
  /// Rules) — cette interface ne fait qu'exposer l'appel.
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers();
}

/// Implémentation sûre utilisée quand Firebase n'est pas configuré.
/// Ne simule AUCUNE donnée réelle : retourne systématiquement des résultats
/// vides/null et lève une exception explicite sur toute tentative d'écriture,
/// pour que l'UI affiche un état `not_configured` plutôt qu'un faux succès.
class NotConfiguredDriverRepository implements DriverRepository {
  const NotConfiguredDriverRepository();

  @override
  Future<DriverProfileV2?> getDriverProfile(String driverId) async => null;

  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) => Stream.value(null);

  @override
  Future<List<DriverDocument>> getDriverDocuments(String driverId) async => const [];

  @override
  Stream<List<DriverDocument>> watchDriverDocuments(String driverId) => Stream.value(const []);

  @override
  Future<List<DriverVehicle>> getDriverVehicles(String driverId) async => const [];

  @override
  Future<void> submitDriverDocument(DriverDocument document) {
    throw BackendNotConfiguredException(
        'submitDriverDocument: Firebase Storage/Firestore non configuré.');
  }

  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) {
    throw BackendNotConfiguredException(
        'submitDriverOnboarding: Firebase Firestore non configuré.');
  }

  @override
  Future<void> submitForReview() {
    throw BackendNotConfiguredException(
        'submitForReview: Firebase Functions non configuré.');
  }

  @override
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() => Stream.value(const []);
}
