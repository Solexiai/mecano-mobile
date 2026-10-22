// ---------------------------------------------------------------------------
// FirebaseDriverRepository — implémentation réelle de DriverRepository.
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

import '../../models/enums.dart';
import '../backend_exceptions.dart';
import '../models/driver_document.dart';
import '../models/driver_internal_note.dart';
import '../models/driver_profile_v2.dart';
import '../models/driver_vehicle.dart';
import 'driver_repository.dart';
import 'firestore_driver_window.dart';

class FirebaseDriverRepository implements DriverRepository {
  FirebaseDriverRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _db = firestore ?? FirebaseFirestore.instance,
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
    final snap = await _driverDocuments
        .where('driver_id', isEqualTo: driverId)
        .get();
    return snap.docs
        .map((d) => DriverDocument.fromJson(d.id, d.data()))
        .toList();
  }

  @override
  Stream<List<DriverDocument>> watchDriverDocuments(String driverId) {
    return _driverDocuments
        .where('driver_id', isEqualTo: driverId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DriverDocument.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<List<DriverVehicle>> getDriverVehicles(String driverId) async {
    final snap = await _driverVehicles
        .where('driver_id', isEqualTo: driverId)
        .get();
    return snap.docs
        .map((d) => DriverVehicle.fromJson(d.id, d.data()))
        .toList();
  }

  @override
  Future<void> submitDriverDocument(DriverDocument document) async {
    try {
      await _driverDocuments
          .doc(document.id)
          .set(document.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw BackendNotConfiguredException('submitDriverDocument a échoué: $e');
    }
  }

  /// Champs que le chauffeur déclare lui-même. Doit rester identique à
  /// `driverDeclaredFields()` dans firestore.rules (SEC-S2) : tout autre
  /// champ (statut, vérifications, adresse vérifiée, compte Stripe…) est
  /// réservé aux Cloud Functions.
  static Map<String, dynamic> declaredOnboardingFields(DriverProfileV2 p) {
    final json = p.toJson();
    const keys = [
      'full_name',
      'city',
      'phone',
      'base_address_formatted',
      'base_address_line1',
      'base_region',
      'base_postal_code',
      'base_country',
      'base_place_id',
      'base_lat',
      'base_lng',
      'spoken_languages',
      'loading_assistance_available',
      'service_radius_km',
      'accepted_vehicle_categories',
      'accepted_item_category_keys',
      'max_loading_team_size',
    ];
    return {
      for (final k in keys)
        if (json.containsKey(k)) k: json[k],
    };
  }

  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) async {
    try {
      await _functions.httpsCallable('registerAsDriver').call();

      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.getIdTokenResult(true);
      }

      // Création : statut initial + champs déclarés. Resoumission : SEULEMENT
      // les champs déclarés. L'ancienne version réécrivait tout le profil
      // (statut, approved_at, compte Stripe à null…) : les règles refusaient
      // donc toute resoumission, et sans elles le compte de versement Stripe
      // du chauffeur aurait été effacé.
      final ref = _driverProfiles.doc(profile.uid);
      final declared = declaredOnboardingFields(profile);
      final existing = await ref.get();
      if (existing.exists) {
        await ref.update(declared);
      } else {
        await ref.set({
          ...declared,
          'uid': profile.uid,
          'status': DriverStatus.registrationIncomplete.firestoreValue,
          'online_status': DriverOnlineStatus.offline.firestoreValue,
          'created_at': profile.createdAt.toIso8601String(),
        });
      }
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'submitDriverOnboarding: registerAsDriver a échoué (${e.code}): ${e.message}',
      );
    } catch (e) {
      throw BackendNotConfiguredException(
        'submitDriverOnboarding a échoué: $e',
      );
    }
  }

  @override
  Future<void> submitDriverVehicle(DriverVehicle vehicle) async {
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
      color: vehicle.color,
    );
    try {
      await _driverVehicles
          .doc(safeVehicle.id)
          .set(safeVehicle.toJson(), SetOptions(merge: true));
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
        'submitForReview: submitDriverForReview a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Stream<List<DriverProfileV2>> watchPendingReviewDrivers() {
    return _driverProfiles
        .where('status', isEqualTo: DriverStatus.pendingReview.firestoreValue)
        .snapshots()
        .map(
          (snap) => snap.docs
              .where(
                (d) => (d.data()['migrated_to_uid'] ?? '').toString().isEmpty,
              )
              .map((d) => DriverProfileV2.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Stream<List<DriverProfileV2>> watchDriversByStatus(
    DriverStatus? status, {
    int limit = 50,
  }) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    // Stable document-ID window. The optional status filter remains a
    // single-field Firestore query; no new composite index is required.
    // The admin UI can explicitly request further finite windows.
    final query = status == null
        ? _driverProfiles
        : _driverProfiles.where('status', isEqualTo: status.firestoreValue);
    return query
        .orderBy(FieldPath.documentId)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => FirestoreDriverWindow(
            snap.docs
                .where(
                  (d) => (d.data()['migrated_to_uid'] ?? '').toString().isEmpty,
                )
                .map((d) => DriverProfileV2.fromJson(d.id, d.data()))
                .toList(),
            fetchedCount: snap.docs.length,
          ),
        );
  }

  @override
  Future<void> reviewDriverVehicle({
    required DriverVehicle vehicle,
    required bool approve,
    Map<String, dynamic>? capacity,
    DateTime? validUntil,
    required String note,
  }) async {
    await _functions.httpsCallable('reviewDriverVehicle').call({
      'driverId': vehicle.driverId,
      'vehicleId': vehicle.id,
      'action': approve ? 'approve' : 'revoke',
      'expectedIdentity': vehicle.verificationIdentity,
      if (capacity != null) 'capacity': capacity,
      if (validUntil != null)
        'validUntil': validUntil.toUtc().toIso8601String(),
      'verificationNote': note,
    });
  }

  @override
  Future<void> approveDriver(String driverId) async {
    try {
      await _functions.httpsCallable('approveDriver').call({
        'driverId': driverId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'approveDriver a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> rejectDriver(String driverId, String reason) async {
    try {
      await _functions.httpsCallable('rejectDriver').call({
        'driverId': driverId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'rejectDriver a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> requestDriverDocuments(String driverId, String reason) async {
    try {
      await _functions.httpsCallable('requestDriverDocuments').call({
        'driverId': driverId,
        'reason': reason,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'requestDriverDocuments a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> suspendDriver(
    String driverId,
    String reason, {
    String suspensionMode = 'urgent',
  }) async {
    try {
      await _functions.httpsCallable('suspendDriver').call({
        'driverId': driverId,
        'reason': reason,
        'suspensionMode': suspensionMode,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'suspendDriver a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> reactivateDriver(String driverId) async {
    try {
      await _functions.httpsCallable('reactivateDriver').call({
        'driverId': driverId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'reactivateDriver a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> addDriverInternalNote(String driverId, String text) async {
    try {
      await _functions.httpsCallable('addDriverInternalNote').call({
        'driverId': driverId,
        'text': text,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'addDriverInternalNote a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Stream<List<DriverInternalNote>> watchDriverInternalNotes(String driverId) {
    return _driverInternalNotes
        .where('driver_id', isEqualTo: driverId)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DriverInternalNote.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<void> logDriverReviewOpened(String driverId) async {
    try {
      await _functions.httpsCallable('logDriverReviewOpened').call({
        'driverId': driverId,
      });
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'logDriverReviewOpened a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> setDriverOnlineStatus(String driverId, bool online) async {
    try {
      await _driverProfiles.doc(driverId).update({
        'online_status':
            (online ? DriverOnlineStatus.online : DriverOnlineStatus.offline)
                .firestoreValue,
      });
    } catch (e) {
      throw BackendNotConfiguredException('setDriverOnlineStatus a échoué: $e');
    }
  }

  @override
  Future<DriverStripeAccountResult>
  createOrRetrieveDriverStripeAccount() async {
    try {
      final result = await _functions
          .httpsCallable('createDriverStripeAccount')
          .call();
      final data = Map<String, dynamic>.from(result.data as Map);
      return DriverStripeAccountResult(
        success: data['success'] == true,
        connectedAccountId: data['connectedAccountId'] as String?,
        onboardingUrl: data['onboardingUrl'] as String?,
        alreadyExisted: data['alreadyExisted'] == true,
      );
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'createOrRetrieveDriverStripeAccount a échoué (${e.code}): ${e.message}',
      );
    } catch (e) {
      throw BackendNotConfiguredException(
        'createOrRetrieveDriverStripeAccount a échoué: $e',
      );
    }
  }
}
