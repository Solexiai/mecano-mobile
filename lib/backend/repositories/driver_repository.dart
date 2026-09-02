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

/// Résultat de `createOrRetrieveDriverStripeAccount()` — miroir exact de la
/// réponse `{success, connectedAccountId, onboardingUrl, alreadyExisted}` de
/// la Cloud Function `createDriverStripeAccount` (voir
/// `functions/src/functions/createDriverStripeAccount.ts`). Ce repository ne
/// fait QUE relayer cet appel : aucune logique Stripe, aucun secret, jamais
/// d'écriture Firestore directe des champs `stripe_*` depuis Flutter.
class DriverStripeAccountResult {
  final bool success;
  final String? connectedAccountId;
  final String? onboardingUrl;
  final bool alreadyExisted;

  const DriverStripeAccountResult({
    required this.success,
    this.connectedAccountId,
    this.onboardingUrl,
    this.alreadyExisted = false,
  });
}

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

  /// Change `online_status` (online/offline) du chauffeur COURANT.
  /// Écriture Firestore DIRECTE autorisée par firestore.rules UNIQUEMENT
  /// lorsque `status == 'approved'` (voir règle `driver_profiles.update`) :
  /// le serveur re-vérifie systématiquement cette condition, ce champ
  /// n'étant pas dans la liste des champs protégés (contrairement à
  /// `status`, `approved_at`, etc.). Un chauffeur non approuvé qui tente
  /// cet appel se heurte à un refus Security Rules (PERMISSION_DENIED),
  /// jamais à un faux succès.
  Future<void> setDriverOnlineStatus(String driverId, bool online);

  // -------------------------------------------------------------------
  // Bloc 8B — Connect Onboarding Flutter (PRIORITÉ 1, PR #12 follow-up).
  // -------------------------------------------------------------------

  /// Crée (première fois) ou récupère (idempotent) le compte Stripe Connect
  /// Express du chauffeur COURANT via la Cloud Function existante
  /// `createDriverStripeAccount` — RÉUTILISÉE telle quelle, jamais dupliquée
  /// ni réimplémentée côté client. Ne transporte, ne stocke, ni ne calcule
  /// AUCUN secret Stripe : le retour ne contient qu'un identifiant de
  /// compte connecté (opaque) et une URL d'onboarding hébergée par Stripe
  /// elle-même (le chauffeur y est redirigé, jamais de formulaire de carte/
  /// compte bancaire affiché dans Movi-K). L'état réel (`charges_enabled`,
  /// `payouts_enabled`) n'est JAMAIS déduit de ce retour : il est lu
  /// séparément depuis `DriverProfileV2` (synchronisé par le webhook
  /// `account.updated`, voir GAP-8B-01), qui reste la seule source de
  /// vérité après le retour d'onboarding.
  Future<DriverStripeAccountResult> createOrRetrieveDriverStripeAccount();
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

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) {
    throw BackendNotConfiguredException(
        'setDriverOnlineStatus: Firebase Firestore non configuré.');
  }

  @override
  Future<DriverStripeAccountResult> createOrRetrieveDriverStripeAccount() {
    throw BackendNotConfiguredException(
        'createOrRetrieveDriverStripeAccount: Firebase Functions non configuré.');
  }
}
