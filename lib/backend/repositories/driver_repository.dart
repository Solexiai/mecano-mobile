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
//
// PHASE 2 — portail analyste `/admin/chauffeurs` : les nouvelles méthodes
// ci-dessous (approveDriver, rejectDriver, requestDriverDocuments,
// suspendDriver, reactivateDriver, addDriverInternalNote,
// watchDriverInternalNotes, logDriverReviewOpened, watchDriversByStatus)
// suivent STRICTEMENT le même principe : chaque écriture sensible passe par
// une Cloud Function callable (jamais une écriture Firestore directe depuis
// ce repository), voir firebase_driver_repository.dart pour l'implémentation.
// ---------------------------------------------------------------------------

import '../models/driver_profile_v2.dart';
import '../models/driver_document.dart';
import '../models/driver_vehicle.dart';
import '../models/driver_internal_note.dart';
import '../../models/enums.dart';
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

  /// Crée le véhicule déclaré par le chauffeur pendant l'onboarding
  /// (`driver_vehicles/{id}`, `is_verified: false` — seule valeur permise
  /// par la règle `create` de `driver_vehicles`, voir firestore.rules).
  Future<void> submitDriverVehicle(DriverVehicle vehicle);

  /// Fait transitionner le profil de registration_incomplete/
  /// documents_required vers pending_review, via la Cloud Function
  /// `submitDriverForReview` (le client ne peut jamais écrire `status`
  /// directement — voir firestore.rules).
  Future<void> submitForReview();

  /// Liste des chauffeurs en attente de revue (pour le portail analyste).
  /// Nécessite le rôle analyst/admin/super_admin côté serveur (Security
  /// Rules) — cette interface ne fait qu'exposer l'appel.
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers();

  /// Liste filtrable des chauffeurs par statut (portail analyste — liste
  /// `/admin/chauffeurs` avec filtres pending_review/documents_required/
  /// approved/rejected/suspended, point 4 du cahier des charges Phase 2).
  /// `null` = tous les statuts confondus (à utiliser avec prudence, coûteux
  /// sur une base de données volumineuse : privilégier un statut explicite).
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status);

  // -------------------------------------------------------------------
  // Actions analyste — Cloud Functions ONLY (voir en-tête de fichier).
  // -------------------------------------------------------------------

  /// Approuve un dossier chauffeur via la Cloud Function `approveDriver`.
  /// Ne rend PAS le chauffeur `online` automatiquement (point 13).
  Future<void> approveDriver(String driverId);

  /// Refuse un dossier chauffeur via la Cloud Function `rejectDriver`.
  /// `reason` est obligatoire (min 3 caractères côté serveur).
  Future<void> rejectDriver(String driverId, String reason);

  /// Demande un nouveau document / correction via la Cloud Function
  /// `requestDriverDocuments` (statut `documents_required`).
  Future<void> requestDriverDocuments(String driverId, String reason);

  /// Suspend un chauffeur (admin/super_admin uniquement côté serveur) via
  /// la Cloud Function `suspendDriver`.
  Future<void> suspendDriver(String driverId, String reason);

  /// Réactive un chauffeur suspendu (admin/super_admin uniquement côté
  /// serveur) via la Cloud Function `reactivateDriver`.
  Future<void> reactivateDriver(String driverId);

  /// Ajoute une note interne analyste/admin sur un dossier (jamais visible
  /// au chauffeur) via la Cloud Function `addDriverInternalNote`.
  Future<void> addDriverInternalNote(String driverId, String text);

  /// Flux temps réel des notes internes d'un dossier chauffeur (lecture
  /// directe Firestore, protégée par firestore.rules : analyst+ uniquement).
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId);

  /// Journalise l'ouverture d'un dossier par un analyste (audit_logs,
  /// action `driver_review_opened`) via la Cloud Function
  /// `logDriverReviewOpened`. N'écrit aucune donnée Firestore hors audit.
  Future<void> logDriverReviewOpened(String driverId);
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
  Future<void> submitDriverVehicle(DriverVehicle vehicle) {
    throw BackendNotConfiguredException('submitDriverVehicle: Firebase Firestore non configuré.');
  }

  @override
  Future<void> submitForReview() {
    throw BackendNotConfiguredException(
        'submitForReview: Firebase Functions non configuré.');
  }

  @override
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() => Stream.value(const []);

  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status) =>
      Stream.value(const []);

  @override
  Future<void> approveDriver(String driverId) {
    throw BackendNotConfiguredException('approveDriver: Firebase Functions non configuré.');
  }

  @override
  Future<void> rejectDriver(String driverId, String reason) {
    throw BackendNotConfiguredException('rejectDriver: Firebase Functions non configuré.');
  }

  @override
  Future<void> requestDriverDocuments(String driverId, String reason) {
    throw BackendNotConfiguredException(
        'requestDriverDocuments: Firebase Functions non configuré.');
  }

  @override
  Future<void> suspendDriver(String driverId, String reason) {
    throw BackendNotConfiguredException('suspendDriver: Firebase Functions non configuré.');
  }

  @override
  Future<void> reactivateDriver(String driverId) {
    throw BackendNotConfiguredException('reactivateDriver: Firebase Functions non configuré.');
  }

  @override
  Future<void> addDriverInternalNote(String driverId, String text) {
    throw BackendNotConfiguredException(
        'addDriverInternalNote: Firebase Functions non configuré.');
  }

  @override
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) =>
      Stream.value(const []);

  @override
  Future<void> logDriverReviewOpened(String driverId) {
    throw BackendNotConfiguredException(
        'logDriverReviewOpened: Firebase Functions non configuré.');
  }
}
