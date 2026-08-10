// ---------------------------------------------------------------------------
// DeliveryMission (Firestore-ready) — collection `delivery_requests/{id}`.
//
// Représente l'état serveur-authoritative d'une mission, distinct du
// modèle legacy `DeliveryRequest` (customer-facing, statuts `DeliveryStatus`
// simplifiés). `status` (MissionStatus) est la machine à états complète
// gérée par les Cloud Functions ; `driverId` ne doit être écrit QUE par la
// transaction atomique `acceptDelivery()`.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

class DeliveryMission {
  final String id;
  final String customerId;
  final String itemCategoryKey; // clé i18n cat_*
  final String description;
  final VehicleCategory requiredVehicleCategory;
  final MissionStatus status;
  final String? driverId;
  final DateTime? acceptedAt;
  final String pricingVersion;
  final String? activeQuoteId;
  final String? activeFinancialSnapshotId;
  final DateTime createdAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;

  const DeliveryMission({
    required this.id,
    required this.customerId,
    required this.itemCategoryKey,
    required this.description,
    required this.requiredVehicleCategory,
    required this.status,
    this.driverId,
    this.acceptedAt,
    required this.pricingVersion,
    this.activeQuoteId,
    this.activeFinancialSnapshotId,
    required this.createdAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
  });

  bool get isOpenForAcceptance => status.isOpenForAcceptance;
  bool get hasAssignedDriver => driverId != null && driverId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
        'id': id,
        'customer_id': customerId,
        'item_category_key': itemCategoryKey,
        'description': description,
        'required_vehicle_category': requiredVehicleCategory.name,
        'status': status.name,
        'driver_id': driverId,
        'accepted_at': acceptedAt?.toIso8601String(),
        'pricing_version': pricingVersion,
        'active_quote_id': activeQuoteId,
        'active_financial_snapshot_id': activeFinancialSnapshotId,
        'created_at': createdAt.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'cancelled_at': cancelledAt?.toIso8601String(),
        'cancellation_reason': cancellationReason,
      };

  factory DeliveryMission.fromJson(String id, Map<String, dynamic> json) {
    return DeliveryMission(
      id: id,
      customerId: json['customer_id'] as String? ?? '',
      itemCategoryKey: json['item_category_key'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiredVehicleCategory: VehicleCategory.values.firstWhere(
        (c) => c.name == json['required_vehicle_category'],
        orElse: () => VehicleCategory.other,
      ),
      status: MissionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => MissionStatus.draft,
      ),
      driverId: json['driver_id'] as String?,
      acceptedAt:
          json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      pricingVersion: json['pricing_version'] as String? ?? 'UNCONFIGURED',
      activeQuoteId: json['active_quote_id'] as String?,
      activeFinancialSnapshotId: json['active_financial_snapshot_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      completedAt:
          json['completed_at'] != null ? DateTime.parse(json['completed_at'] as String) : null,
      cancelledAt:
          json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
      cancellationReason: json['cancellation_reason'] as String?,
    );
  }
}
