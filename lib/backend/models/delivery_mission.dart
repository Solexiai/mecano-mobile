// ---------------------------------------------------------------------------
// DeliveryMission (Firestore-ready) — collection `delivery_requests/{id}`.
//
// Représente l'état serveur-authoritative d'une mission, distinct du
// modèle legacy `DeliveryRequest` (customer-facing, statuts `DeliveryStatus`
// simplifiés). `status` (MissionStatus) est la machine à états complète
// gérée par les Cloud Functions ; `driverId` ne doit être écrit QUE par la
// transaction atomique `acceptDelivery()`.
//
// EXTENSION (Phase 4) : le document réel écrit par
// `createDeliveryRequest.ts` contient également `pickup_address`,
// `dropoff_address`, `distance_km`, `estimated_duration_minutes`,
// `driver_offer_amount`, `customer_total`, `customer_display_name`,
// `driver_display_name` — nécessaires pour que les écrans (demandes client,
// jobs chauffeur, mission active) affichent les vraies informations sans
// jamais les recalculer côté Flutter. `MissionAddress` est réutilisé depuis
// `mission_repository.dart` pour rester cohérent avec `StopInput.address`
// dans `createDeliveryRequest.ts`.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import 'firestore_date.dart';
import 'mission_address.dart';

MissionAddress? _parseAddress(dynamic raw) {
  if (raw is! Map) return null;
  return MissionAddress.fromJson(Map<String, dynamic>.from(raw));
}

class DeliveryMission {
  final String id;
  final String customerId;
  final String? customerDisplayName;
  final String itemCategoryKey; // clé i18n cat_*
  final String description;
  final VehicleCategory requiredVehicleCategory;
  final MissionStatus status;
  final String? driverId;
  final String? driverDisplayName;
  final DateTime? acceptedAt;
  final String pricingVersion;
  final String? activeQuoteId;
  final String? activeFinancialSnapshotId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  // Champs dénormalisés écrits par createDeliveryRequest() — lecture seule,
  // jamais recalculés côté Flutter.
  final MissionAddress? pickupAddress;
  final MissionAddress? dropoffAddress;
  final double? distanceKm;
  final double? estimatedDurationMinutes;
  final double driverOfferAmount;
  final double customerTotal;

  const DeliveryMission({
    required this.id,
    required this.customerId,
    this.customerDisplayName,
    required this.itemCategoryKey,
    required this.description,
    required this.requiredVehicleCategory,
    required this.status,
    this.driverId,
    this.driverDisplayName,
    this.acceptedAt,
    required this.pricingVersion,
    this.activeQuoteId,
    this.activeFinancialSnapshotId,
    required this.createdAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.pickupAddress,
    this.dropoffAddress,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.driverOfferAmount = 0,
    this.customerTotal = 0,
  });

  bool get isOpenForAcceptance => status.isOpenForAcceptance;
  bool get hasAssignedDriver => driverId != null && driverId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'customer_display_name': customerDisplayName,
        'item_category_key': itemCategoryKey,
        'description': description,
        'required_vehicle_category': requiredVehicleCategory.firestoreValue,
        'status': status.firestoreValue,
        'driver_id': driverId,
        'driver_display_name': driverDisplayName,
        'accepted_at': acceptedAt?.toIso8601String(),
        'pricing_version': pricingVersion,
        'active_quote_id': activeQuoteId,
        'active_financial_snapshot_id': activeFinancialSnapshotId,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'cancellation_reason': cancellationReason,
        'distance_km': distanceKm,
        'estimated_duration_minutes': estimatedDurationMinutes,
        'driver_offer_amount': driverOfferAmount,
        'customer_total': customerTotal,
      };

  factory DeliveryMission.fromJson(String id, Map<String, dynamic> json) {
    return DeliveryMission(
      id: id,
      customerId: json['customer_id'] as String? ?? '',
      customerDisplayName: json['customer_display_name'] as String?,
      itemCategoryKey: json['item_category_key'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiredVehicleCategory: VehicleCategoryX.fromFirestoreValue(json['required_vehicle_category'] as String?),
      status: MissionStatusX.fromFirestoreValue(json['status'] as String?),
      driverId: json['driver_id'] as String?,
      driverDisplayName: json['driver_display_name'] as String?,
      acceptedAt: parseFirestoreDate(json['accepted_at']),
      pricingVersion: json['pricing_version'] as String? ?? 'UNCONFIGURED',
      activeQuoteId: json['active_quote_id'] as String?,
      activeFinancialSnapshotId: json['active_financial_snapshot_id'] as String?,
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      completedAt: parseFirestoreDate(json['completed_at']),
      cancelledAt: parseFirestoreDate(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      pickupAddress: _parseAddress(json['pickup_address']),
      dropoffAddress: _parseAddress(json['dropoff_address']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes: (json['estimated_duration_minutes'] as num?)?.toDouble(),
      driverOfferAmount: (json['driver_offer_amount'] as num? ?? 0).toDouble(),
      customerTotal: (json['customer_total'] as num? ?? 0).toDouble(),
    );
  }
}
