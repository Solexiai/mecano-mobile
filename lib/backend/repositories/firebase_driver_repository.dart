// ---------------------------------------------------------------------------
// FirebaseDriverRepository — première implémentation RÉELLE de
// DriverRepository, branchée sur Cloud Firestore.
//
// RÈGLES RESPECTÉES (voir en-tête de driver_repository.dart) :
// - Lecture : accès direct Firestore (`driver_profiles`, `driver_documents`),
//   déjà protégé par firestore.rules (un chauffeur ne peut lire que son
//   propre profil ; un analyste/admin peut lire la file pending_review).
// - Écriture : `submitDriverOnboarding()` et `submitDriverDocument()` sont
//   des écritures NON sensibles autorisées explicitement par
//   firestore.rules (un chauffeur peut créer/mettre à jour son propre
//   profil tant que `status` reste `registration_incomplete` ou
//   `pending_review`, jamais `approved` — voir la règle
//   `driver_profiles` dans firestore.rules).
// - AUCUNE écriture de champs protégés (status=approved, approved_at,
//   approved_by_user_id, rating, documents_all_valid, etc.) n'est faite
//   ici : ces champs sont exclusivement modifiés par les Cloud Functions
//   `approveDriver`/`rejectDriver`/`validateDriverDocument`.
// - Toute valeur d'enum sérialisée utilise `firestoreValue` (snake_case),
//   jamais `.name` (camelCase) — cohérence avec functions/src/lib/types.ts.
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/enums.dart';
import '../models/driver_profile_v2.dart';
import '../models/driver_document.dart';
import '../models/driver_vehicle.dart';
import '../models/driver_internal_note.dart';
import '../backend_exceptions.dart';
import 'driver_repository.dart';

class FirebaseDriverRepository implements DriverRepository {
  FirebaseDriverRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _driverProfiles =>
      _db.collection('driver_profiles');
  CollectionReference<Map<String, dynamic>> get _driverDocuments =>
      _db.collection('driver_documents');
  CollectionReference<Map<String, dynamic>> get _driverVehicles =>
      _db.collection('driver_vehicles');
  CollectionReference<Map<String, dynamic>> get _driverInternalNotes =>
      _db.collection('driver_internal_notes');

  @override
  Future<DriverProfileV2?> getDriverProfile(String driverId) async {
    final snap = await _driverProfiles.doc(driverId).get();
    if (!snap.exists || snap.data() == null) return null;
    return DriverProfileV2.fromJson(driverId, snap.data()!);
  }

  @override
  Stream<DriverProfileV2?> watchDriverProfile(String driverId) {
    return _driverProfiles.doc(driverId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DriverProfileV2.fromJson(driverId, snap.data()!);
    });
  }

  @override
  Future<List<DriverDocument>> getDriverDocuments(String driverId) async {
    final snap = await _driverDocuments.where('driver_id', isEqualTo: driverId).get();
    return snap.docs.map((d) => DriverDocument.fromJson(d.id, d.data())).toList();
  }

  @override
  Stream<List<DriverDocument>> watchDriverDocuments(String driverId) {
    return _driverDocuments.where('driver_id', isEqualTo: driverId).snapshots().map(
          (snap) => snap.docs.map((d) => DriverDocument.fromJson(d.id, d.data())).toList(),
        );
  }

  @override
  Future<List<DriverVehicle>> getDriverVehicles(String driverId) async {
    final snap = await _driverVehicles.where('driver_id', isEqualTo: driverId).get();
    return snap.docs.map((d) => DriverVehicle.fromJson(d.id, d.data())).toList();
  }

  @override
  Future<void> submitDriverDocument(DriverDocument document) async {
    try {
      await _driverDocuments.doc(document.id).set(document.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw BackendNotConfiguredException('submitDriverDocument a échoué: $e');
    }
  }

  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) async {
    // Garde-fou défensif côté client (en plus de firestore.rules) : on
    // n'autorise jamais ce repository à écrire un statut protégé. Le
    // statut initial d'un onboarding est TOUJOURS 'registration_incomplete'
    // (seule valeur autorisée par la règle `create` de driver_profiles) ;
    // le passage à 'pending_review' se fait via une écriture ultérieure du
    // chauffeur lui-même une fois le formulaire complet (autorisé par la
    // règle `update`, qui ne protège que les champs sensibles listés).
    final safeStatus = (profile.status == DriverStatus.approved ||
            profile.status == DriverStatus.rejected ||
            profile.status == DriverStatus.suspended)
        ? DriverStatus.registrationIncomplete
        : profile.status;

    final safeProfile = DriverProfileV2(
      uid: profile.uid,
      fullName: profile.fullName,
      city: profile.city,
      status: safeStatus,
      serviceRadiusKm: profile.serviceRadiusKm,
      acceptedVehicleCategories: profile.acceptedVehicleCategories,
      acceptedItemCategoryKeys: profile.acceptedItemCategoryKeys,
      createdAt: profile.createdAt,
    );

    try {
      // 1. S'assurer que le custom claim `driver` est présent (requis par
      //    la règle `create` de driver_profiles : isDriver()). Sans appel,
      //    un tout nouvel utilisateur (rôle customer uniquement) ne
      //    pourrait jamais créer son document d'onboarding.
      await _functions.httpsCallable('registerAsDriver').call();

      // 2. Forcer le rafraîchissement du token pour que le claim soit
      //    visible immédiatement dans cette même session (sinon la règle
      //    Firestore verrait encore l'ancien token sans le rôle driver).
      // Note: l'appelant (écran d'onboarding) doit avoir déjà déclenché
      // FirebaseAuthProvider.refreshClaims() après le succès de cette
      // méthode pour que l'UI reflète aussi le nouveau rôle.

      // 3. Créer/mettre à jour le document d'onboarding avec un statut sûr.
      await _driverProfiles.doc(profile.uid).set(safeProfile.toJson(), SetOptions(merge: true));
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'submitDriverOnboarding: registerAsDriver a échoué (${e.code}): ${e.message}');
    } catch (e) {
      throw BackendNotConfiguredException('submitDriverOnboarding a échoué: $e');
    }
  }

  @override
  Future<void> submitDriverVehicle(DriverVehicle vehicle) async {
    // Garde-fou défensif : la règle `create` de driver_vehicles exige
    // is_verified == false (seule une Cloud Function/analyste peut vérifier
    // un véhicule ensuite) — on ne fait jamais confiance à une valeur
    // `true` qui viendrait du modèle passé en paramètre.
    final safeVehicle = DriverVehicle(
      id: vehicle.id,
      driverId: vehicle.driverId,
      category: vehicle.category,
      makeModel: vehicle.makeModel,
      year: vehicle.year,
      plate: vehicle.plate,
      maxPayloadKg: vehicle.maxPayloadKg,
      isVerified: false,
      createdAt: vehicle.createdAt,
    );
    try {
      await _driverVehicles.doc(safeVehicle.id).set(safeVehicle.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw BackendNotConfiguredException('submitDriverVehicle a échoué: $e');
    }
  }

  @override
  Future<void> submitForReview() async {
    try {
      await _functions.httpsCallable('submitDriverForReview').call();
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'submitForReview: submitDriverForReview a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() {
    return _driverProfiles
        .where('status', isEqualTo: DriverStatus.pendingReview.firestoreValue)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DriverProfileV2.fromJson(d.id, d.data())).toList());
  }

  // -------------------------------------------------------------------
  // Phase 2 — portail analyste `/admin/chauffeurs`.
  // -------------------------------------------------------------------

  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status) {
    // Requête volontairement SIMPLE (un seul .where(), pas de .orderBy())
    // pour éviter toute dépendance à un index composite Firestore — le tri
    // (le cas échéant) doit être fait en mémoire côté UI. Voir section
    // "Firebase Data Type Consistency" des consignes du sandbox.
    final query = status == null
        ? _driverProfiles
        : _driverProfiles.where('status', isEqualTo: status.firestoreValue);
    return query.snapshots().map(
          (snap) => snap.docs.map((d) => DriverProfileV2.fromJson(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> approveDriver(String driverId) async {
    try {
      await _functions.httpsCallable('approveDriver').call({'driverId': driverId});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'approveDriver a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> rejectDriver(String driverId, String reason) async {
    try {
      await _functions
          .httpsCallable('rejectDriver')
          .call({'driverId': driverId, 'reason': reason});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'rejectDriver a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> requestDriverDocuments(String driverId, String reason) async {
    try {
      await _functions
          .httpsCallable('requestDriverDocuments')
          .call({'driverId': driverId, 'reason': reason});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'requestDriverDocuments a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> suspendDriver(String driverId, String reason) async {
    try {
      await _functions
          .httpsCallable('suspendDriver')
          .call({'driverId': driverId, 'reason': reason});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'suspendDriver a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> reactivateDriver(String driverId) async {
    try {
      await _functions.httpsCallable('reactivateDriver').call({'driverId': driverId});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'reactivateDriver a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> addDriverInternalNote(String driverId, String text) async {
    try {
      await _functions
          .httpsCallable('addDriverInternalNote')
          .call({'driverId': driverId, 'text': text});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'addDriverInternalNote a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) {
    // Pas de .orderBy() ici non plus (voir watchDriversByStatus) : tri par
    // date en mémoire côté UI pour éviter un index composite.
    return _driverInternalNotes.where('driver_id', isEqualTo: driverId).snapshots().map(
          (snap) => snap.docs.map((d) => DriverInternalNote.fromJson(d.id, d.data())).toList(),
        );
  }

  @override
  Future<void> logDriverReviewOpened(String driverId) async {
    try {
      await _functions.httpsCallable('logDriverReviewOpened').call({'driverId': driverId});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'logDriverReviewOpened a échoué (${e.code}): ${e.message}');
    }
  }

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) async {
    try {
      // Écriture Firestore directe (pas de Cloud Function dédiée) : ce
      // champ n'est PAS protégé par firestore.rules, mais la règle
      // `update` exige `resource.data.status == 'approved'` pour
      // l'autoriser — voir en-tête de driver_repository.dart. Un chauffeur
      // non approuvé reçoit donc un PERMISSION_DENIED natif Firestore.
      await _driverProfiles.doc(driverId).update({
        'online_status': (online ? DriverOnlineStatus.online : DriverOnlineStatus.offline)
            .firestoreValue,
      });
    } catch (e) {
      throw BackendNotConfiguredException('setDriverOnlineStatus a échoué: $e');
    }
  }

  // -------------------------------------------------------------------
  // Bloc 8B — Connect Onboarding Flutter.
  // -------------------------------------------------------------------

  @override
  Future<DriverStripeAccountResult> createOrRetrieveDriverStripeAccount() async {
    try {
      // RÉUTILISATION STRICTE de la Cloud Function existante — aucune
      // nouvelle fonction backend créée pour ce Bloc (directive PRIORITÉ 1).
      // Le secret Stripe (STRIPE_SECRET_KEY) ne quitte jamais le serveur :
      // seule cette Cloud Function le charge (voir
      // createDriverStripeAccount.ts, { secrets: [...] }), Flutter ne reçoit
      // que l'identifiant de compte (opaque) et une URL d'onboarding.
      final result = await _functions.httpsCallable('createDriverStripeAccount').call();
      final data = Map<String, dynamic>.from(result.data as Map);
      return DriverStripeAccountResult(
        success: data['success'] == true,
        connectedAccountId: data['connectedAccountId'] as String?,
        onboardingUrl: data['onboardingUrl'] as String?,
        alreadyExisted: data['alreadyExisted'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
          'createOrRetrieveDriverStripeAccount a échoué (${e.code}): ${e.message}');
    } catch (e) {
      throw BackendNotConfiguredException('createOrRetrieveDriverStripeAccount a échoué: $e');
    }
  }
}
