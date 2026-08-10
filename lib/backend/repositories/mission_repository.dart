// ---------------------------------------------------------------------------
// MissionRepository — interface abstraite pour la gestion des missions de
// livraison.
//
// RÈGLE CRITIQUE : `acceptMission()` n'effectue JAMAIS l'écriture
// directement depuis Flutter. Elle appelle une Cloud Function
// (`acceptDelivery()`) qui exécute la transaction atomique côté serveur.
// L'implémentation Firebase de cette interface doit utiliser
// `FirebaseFunctions.instance.httpsCallable('acceptDelivery')`, jamais un
// `.set()`/`.update()` direct sur le document mission.
// ---------------------------------------------------------------------------

import '../models/delivery_mission.dart';
import '../models/delivery_quote.dart';
import '../models/delivery_offer.dart';
import '../backend_exceptions.dart';

/// Résultat renvoyé après une tentative d'acceptation de mission.
class AcceptMissionResult {
  final bool success;
  final String? errorCode; // ex: 'delivery_already_assigned'
  final DeliveryMission? mission;

  const AcceptMissionResult({required this.success, this.errorCode, this.mission});
}

abstract class MissionRepository {
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  });

  /// Crée la mission à partir d'un devis valide (Cloud Function
  /// createDeliveryRequest()).
  Future<DeliveryMission> createMissionFromQuote(String quoteId);

  Stream<DeliveryMission?> watchMission(String missionId);

  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId);

  /// Missions ouvertes à l'acceptation, visibles par un chauffeur candidat
  /// (déjà filtrées côté serveur selon zone/catégorie/statut d'approbation).
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId);

  Stream<List<DeliveryOffer>> watchOffersForDriver(String driverId);

  /// Tente l'acceptation atomique d'une mission. Appelle la Cloud Function
  /// `acceptDelivery()`. Ne doit jamais écrire directement Firestore.
  Future<AcceptMissionResult> acceptMission({
    required String missionId,
    required String driverId,
  });

  Future<void> markPickupCompleted(String missionId);

  Future<void> markDeliveryCompleted(String missionId);
}

class NotConfiguredMissionRepository implements MissionRepository {
  const NotConfiguredMissionRepository();

  @override
  Future<DeliveryQuote> requestQuote({
    required String customerId,
    required String itemCategoryKey,
    required String vehicleCategoryName,
    required Map<String, dynamic> missionDetails,
  }) {
    throw BackendNotConfiguredException('requestQuote: backend Firebase non configuré.');
  }

  @override
  Future<DeliveryMission> createMissionFromQuote(String quoteId) {
    throw BackendNotConfiguredException('createMissionFromQuote: backend Firebase non configuré.');
  }

  @override
  Stream<DeliveryMission?> watchMission(String missionId) => Stream.value(null);

  @override
  Stream<List<DeliveryMission>> watchCustomerMissions(String customerId) => Stream.value(const []);

  @override
  Stream<List<DeliveryMission>> watchAvailableMissionsForDriver(String driverId) =>
      Stream.value(const []);

  @override
  Stream<List<DeliveryOffer>> watchOffersForDriver(String driverId) => Stream.value(const []);

  @override
  Future<AcceptMissionResult> acceptMission({required String missionId, required String driverId}) async {
    return const AcceptMissionResult(success: false, errorCode: 'backend_not_configured');
  }

  @override
  Future<void> markPickupCompleted(String missionId) {
    throw BackendNotConfiguredException('markPickupCompleted: backend Firebase non configuré.');
  }

  @override
  Future<void> markDeliveryCompleted(String missionId) {
    throw BackendNotConfiguredException('markDeliveryCompleted: backend Firebase non configuré.');
  }
}
