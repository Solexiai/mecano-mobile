// ---------------------------------------------------------------------------
// FirebaseMissionRepository — implémentation RÉELLE de MissionRepository,
// branchée sur Cloud Firestore + Cloud Functions.
//
// RÈGLES RESPECTÉES (voir en-tête de mission_repository.dart) :
// - `requestQuote()` appelle la Cloud Function `calculateDeliveryQuote()` —
//   jamais un calcul de prix côté client. Le devis résultant est ensuite
//   RELU depuis Firestore (delivery_quotes/{quoteId}) pour construire un
//   `DeliveryQuote` fidèle au document stocké côté serveur.
// - `createMissionFromQuote()` appelle la Cloud Function
//   `createDeliveryRequest()` — `firestore.rules` interdit `create` direct
//   sur `delivery_requests` (allow create: if false).
// - `acceptMission()` appelle la Cloud Function `acceptDelivery()` —
//   JAMAIS un `.update()` direct. C'est cette Cloud Function qui exécute la
//   transaction atomique garantissant qu'un seul chauffeur gagne.
// - `markPickupCompleted()`/`markDeliveryCompleted()` appellent
//   respectivement `completePickup()`/`completeDelivery()` — ces Cloud
//   Functions gèrent les transitions de statut ET les écritures financières
//   (ledger, snapshot) associées.
// - Les lectures (`watchMission`, `watchCustomerMissions`,
//   `watchAvailableMissionsForDriver`, `watchOffersForDriver`) sont des
//   streams Firestore directs, déjà protégés par firestore.rules.
// - Requêtes volontairement SIMPLES (un seul filtre en profondeur utile,
//   tri en mémoire côté UI si besoin) pour rester cohérent avec les index
//   composites déjà déclarés dans firestore.indexes.json.
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../../models/enums.dart';
import '../models/delivery_mission.dart';
import '../models/delivery_quote.dart';
import '../models/delivery_offer.dart';
import '../backend_exceptions.dart';
import 'mission_repository.dart';

class FirebaseMissionRepository implements MissionRepository {
  FirebaseMissionRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _missions =>
      _db.collection('delivery_requests');
  CollectionReference<Map<String, dynamic>> get _quotes =>
      _db.collection('delivery_quotes');
  CollectionReference<Map<String, dynamic>> get _offers =>
      _db.collection('delivery_offers');

  @override
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  }) async {
    try {
      final result = await _functions.httpsCallable('calculateDeliveryQuote').call({
        'vehicleCategory': vehicleCategoryName,
        'distanceKm': missionDetails['distanceKm'],
        'estimatedDurationMinutes': missionDetails['estimatedDurationMinutes'],
        if (missionDetails['handling'] != null) 'handling': missionDetails['handling'],
        if (missionDetails['totalWaitingMinutes'] != null)
          'totalWaitingMinutes': missionDetails['totalWaitingMinutes'],
        if (missionDetails['additionalStopsCount'] != null)
          'additionalStopsCount': missionDetails['additionalStopsCount'],
        if (missionDetails['applicableSurchargeIds'] != null)
          'applicableSurchargeIds': missionDetails['applicableSurchargeIds'],
        if (missionDetails['promoCode'] != null) 'promoCode': missionDetails['promoCode'],
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final quoteId = data['quoteId'] as String;

      // Le devis stocké côté serveur (delivery_quotes/{quoteId}) est la
      // source de vérité — on le relit plutôt que de reconstruire un
      // DeliveryQuote uniquement à partir de la réponse callable, pour
      // rester fidèle au document réellement persisté (is_consumed,
      // mission_id, etc. reflètent alors toujours l'état Firestore actuel).
      final snap = await _quotes.doc(quoteId).get();
      if (!snap.exists || snap.data() == null) {
        throw BackendNotConfiguredException(
            'requestQuote: delivery_quotes/$quoteId introuvable après calculateDeliveryQuote.');
      }
      return DeliveryQuote.fromJson(quoteId, snap.data()!);
    } on FirebaseFunctionsException catch (e) {
      throw CloudFunctionException(e.code, e.message ?? 'calculateDeliveryQuote a échoué.');
    } catch (e) {
      if (e is CloudFunctionException || e is BackendNotConfiguredException) rethrow;
      throw BackendNotConfiguredException('requestQuote a échoué: $e');
    }
  }

  @override
  Future<DeliveryMission> createMissionFromQuote(CreateMissionRequest request) async {
    try {
      final result = await _functions.httpsCallable('createDeliveryRequest').call({
        'quoteId': request.quoteId,
        'itemCategoryKey': request.itemCategoryKey,
        'description': request.description,
        'requiredVehicleCategory': request.requiredVehicleCategory.firestoreValue,
        'distanceKm': request.distanceKm,
        'estimatedDurationMinutes': request.estimatedDurationMinutes,
        'stops': request.stops.map((s) => s.toJson()).toList(),
        'customerDisplayName': request.customerDisplayName,
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      final missionId = data['missionId'] as String;

      final snap = await _missions.doc(missionId).get();
      if (!snap.exists || snap.data() == null) {
        throw BackendNotConfiguredException(
            'createMissionFromQuote: delivery_requests/$missionId introuvable après createDeliveryRequest.');
      }
      return DeliveryMission.fromJson(missionId, snap.data()!);
    } on FirebaseFunctionsException catch (e) {
      throw CloudFunctionException(e.code, e.message ?? 'createDeliveryRequest a échoué.');
    } catch (e) {
      if (e is CloudFunctionException || e is BackendNotConfiguredException) rethrow;
      throw BackendNotConfiguredException('createMissionFromQuote a échoué: $e');
    }
  }

  @override
  Stream<DeliveryMission?> watchMission(String missionId) {
    return _missions.doc(missionId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DeliveryMission.fromJson(missionId, snap.data()!);
    });
  }

  @override
  Stream<DeliveryMission?> watchActiveMissionForDriver(String driverId) {
    // Requête simple (un seul .where()) : le filtrage par statut "en
    // trajet" (assigned -> arrived_at_dropoff) se fait en mémoire pour ne
    // dépendre d'aucun index composite driver_id+status. Une mission
    // `completed`/`cancelled` récente reste dans le résultat brut mais est
    // exclue ici — c'est cette méthode qui décide de la mission "active".
    const activeStatuses = {
      MissionStatus.assigned,
      MissionStatus.driverToPickup,
      MissionStatus.arrivedAtPickup,
      MissionStatus.pickedUp,
      MissionStatus.inTransit,
      MissionStatus.arrivedAtDropoff,
    };
    return _missions.where('driver_id', isEqualTo: driverId).snapshots().map((snap) {
      final candidates = snap.docs
          .map((d) => DeliveryMission.fromJson(d.id, d.data()))
          .where((m) => activeStatuses.contains(m.status))
          .toList();
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return candidates.first;
    });
  }

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) {
    // Requête simple (un seul .where()) : le tri par date se fait en
    // mémoire côté UI pour ne dépendre d'aucun index composite, même si
    // customer_id+created_at existe déjà dans firestore.indexes.json — on
    // reste cohérent avec la convention du reste du projet
    // (voir FirebaseDriverRepository.watchDriversByStatus()).
    return _missions.where('customer_id', isEqualTo: customerId).snapshots().map((snap) {
      final missions =
          snap.docs.map((d) => DeliveryMission.fromJson(d.id, d.data())).toList();
      missions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return missions;
    });
  }

  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId) {
    // Les missions "disponibles" pour un chauffeur candidat transitent par
    // `delivery_offers/{id}` (créées par le trigger dispatchMissionToDrivers,
    // voir functions/src/functions/dispatchMissionToDrivers.ts) — ce flux
    // est exposé séparément via `watchOffersForDriver()`. Cette méthode
    // regroupe les missions ENCORE ouvertes (searching_driver/offered) pour
    // lesquelles ce chauffeur a une offre active, en combinant les deux
    // lectures (offres du chauffeur -> missions correspondantes), sans
    // jamais scanner `delivery_requests` par catégorie/zone côté client
    // (ce filtrage reste server-side, voir dispatchMissionToDrivers.ts).
    return _offers
        .where('driver_id', isEqualTo: driverId)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((offerSnap) async {
      if (offerSnap.docs.isEmpty) return <DeliveryMission>[];
      final missionIds = offerSnap.docs
          .map((d) => (d.data())['mission_id'] as String?)
          .whereType<String>()
          .toSet()
          .toList();
      if (missionIds.isEmpty) return <DeliveryMission>[];

      // Firestore whereIn est limité à 30 valeurs — les lots de dispatch
      // sont bornés à MAX_CANDIDATE_DRIVERS/mission côté serveur, mais un
      // chauffeur peut avoir plusieurs offres actives simultanées ; on
      // découpe en lots de 30 par prudence.
      final missions = <DeliveryMission>[];
      for (var i = 0; i < missionIds.length; i += 30) {
        final batchIds = missionIds.sublist(i, i + 30 > missionIds.length ? missionIds.length : i + 30);
        final batchSnap =
            await _missions.where(FieldPath.documentId, whereIn: batchIds).get();
        for (final d in batchSnap.docs) {
          final mission = DeliveryMission.fromJson(d.id, d.data());
          if (mission.isOpenForAcceptance) missions.add(mission);
        }
      }
      missions.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return missions;
    });
  }

  @override
  Stream<List<DeliveryOffer>> watchOffersForDriver(String driverId) {
    return _offers.where('driver_id', isEqualTo: driverId).snapshots().map((snap) {
      final offers = snap.docs.map((d) => DeliveryOffer.fromJson(d.id, d.data())).toList();
      offers.sort((a, b) => b.offeredAt.compareTo(a.offeredAt));
      return offers;
    });
  }

  @override
  Future<AcceptMissionResult> acceptMission({
    required String missionId,
    required String driverId,
  }) async {
    try {
      final result = await _functions.httpsCallable('acceptDelivery').call({
        'missionId': missionId,
      });
      final data = Map<String, dynamic>.from(result.data as Map);
      if (data['success'] != true) {
        return const AcceptMissionResult(success: false, errorCode: 'unknown_error');
      }
      final snap = await _missions.doc(missionId).get();
      final mission =
          (snap.exists && snap.data() != null) ? DeliveryMission.fromJson(missionId, snap.data()!) : null;
      return AcceptMissionResult(success: true, mission: mission);
    } on FirebaseFunctionsException catch (e) {
      // Codes attendus : permission-denied, failed-precondition, not-found —
      // voir acceptDelivery.ts. Le frontend affiche errorCode, il ne décide
      // jamais lui-même qui "gagne" l'acceptation.
      return AcceptMissionResult(success: false, errorCode: e.code);
    } catch (e) {
      return const AcceptMissionResult(success: false, errorCode: 'unknown_error');
    }
  }

  @override
  Future<void> markPickupCompleted(String missionId) async {
    try {
      await _functions.httpsCallable('completePickup').call({'missionId': missionId});
    } on FirebaseFunctionsException catch (e) {
      throw CloudFunctionException(e.code, e.message ?? 'completePickup a échoué.');
    }
  }

  @override
  Future<void> markDeliveryCompleted(String missionId) async {
    try {
      await _functions.httpsCallable('completeDelivery').call({'missionId': missionId});
    } on FirebaseFunctionsException catch (e) {
      throw CloudFunctionException(e.code, e.message ?? 'completeDelivery a échoué.');
    }
  }

  @override
  Future<void> updateTrackingStatus({
    required String missionId,
    required MissionStatus targetStatus,
  }) async {
    try {
      await _functions.httpsCallable('updateMissionTrackingStatus').call({
        'missionId': missionId,
        'targetStatus': targetStatus.firestoreValue,
      });
    } on FirebaseFunctionsException catch (e) {
      throw CloudFunctionException(e.code, e.message ?? 'updateMissionTrackingStatus a échoué.');
    }
  }
}
