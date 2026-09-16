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

class FirebaseDriverRepository implements DriverRepository {
  FirebaseDriverRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  })  : _db = firestore ?? FirebaseFirestore.instance,
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
    final snap =
        await _driverDocuments.where('driver_id', isEqualTo: driverId).get();
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
    final snap =
        await _driverVehicles.where('driver_id', isEqualTo: driverId).get();
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

  @override
  Future<void> submitDriverOnboarding(DriverProfileV2 profile) async {
    final safeStatus = (profile.status == DriverStatus.approved ||
            profile.status == DriverStatus.rejected ||
            profile.status == DriverStatus.suspended)
        ? DriverStatus.registrationIncomplete
        : profile.status;

    // Conserver tous les champs déclaratifs du nouveau wizard tout en
    // réinitialisant les champs sensibles à leurs valeurs sûres. L'ancienne
    // version reconstruisait le modèle en perdant notamment téléphone,
    // adresse structurée, langues et disponibilité d'aide au chargement.
    final safeProfile = DriverProfileV2(
      uid: profile.uid,
      fullName: profile.fullName,
      city: profile.city,
      phone: profile.phone,
      baseAddressFormatted: profile.baseAddressFormatted,
      baseAddressLine1: profile.baseAddressLine1,
      baseRegion: profile.baseRegion,
      basePostalCode: profile.basePostalCode,
      baseCountry: profile.baseCountry,
      basePlaceId: profile.basePlaceId,
      baseLat: profile.baseLat,
      baseLng: profile.baseLng,
      spokenLanguages: profile.spokenLanguages,
      loadingAssistanceAvailable: profile.loadingAssistanceAvailable,
      status: safeStatus,
      serviceRadiusKm: profile.serviceRadiusKm,
      acceptedVehicleCategories: profile.acceptedVehicleCategories,
      acceptedItemCategoryKeys: profile.acceptedItemCategoryKeys,
      createdAt: profile.createdAt,
    );

    try {
      await _functions.httpsCallable('registerAsDriver').call();

      final currentUser = fb.FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.getIdTokenResult(true);
      }

      await _driverProfiles
          .doc(profile.uid)
          .set(safeProfile.toJson(), SetOptions(merge: true));
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
      throw BackendNotConfiguredException(
        'submitDriverVehicle a échoué: $e',
      );
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
  Stream<List<DriverProfileV2>> watchDriversByStatus(DriverStatus? status) {
    final query = status == null
        ? _driverProfiles
        : _driverProfiles.where('status', isEqualTo: status.firestoreValue);
    return query.snapshots().map(
          (snap) => snap.docs
              .where(
                (d) => (d.data()['migrated_to_uid'] ?? '').toString().isEmpty,
              )
              .map((d) => DriverProfileV2.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  @override
  Future<void> approveDriver(String driverId) async {
    try {
      await _functions
          .httpsCallable('approveDriver')
          .call({'driverId': driverId});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'approveDriver a échoué (${e.code}): ${e.message}',
      );
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
        'rejectDriver a échoué (${e.code}): ${e.message}',
      );
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
        'requestDriverDocuments a échoué (${e.code}): ${e.message}',
      );
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
        'suspendDriver a échoué (${e.code}): ${e.message}',
      );
    }
  }

  @override
  Future<void> reactivateDriver(String driverId) async {
    try {
      await _functions
          .httpsCallable('reactivateDriver')
          .call({'driverId': driverId});
    } on FirebaseFunctionsException catch (e) {
      throw BackendNotConfiguredException(
        'reactivateDriver a échoué (${e.code}): ${e.message}',
      );
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
      await _functions
          .httpsCallable('logDriverReviewOpened')
          .call({'driverId': driverId});
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
        'online_status': (online
                ? DriverOnlineStatus.online
                : DriverOnlineStatus.offline)
            .firestoreValue,
      });
    } catch (e) {
      throw BackendNotConfiguredException(
        'setDriverOnlineStatus a échoué: $e',
      );
    }
  }

  @override
  Future<DriverStripeAccountResult>
      createOrRetrieveDriverStripeAccount() async {
    try {
      final result =
          await _functions.httpsCallable('createDriverStripeAccount').call();
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
