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
  final Map<String, dynamic>? bookingSnapshot;
  final Map<String, dynamic>? scheduling;
  final String? scheduleState;
  final String? dispatchState;
  final String? paymentStatus;
  // Dépôt de réservation (2026-11-06, serveur lib/bookingDeposit.ts) :
  // montant en cents et état (captured / refund_pending / refunded /
  // refund_failed / kept). Null sans dépôt (test interne, ancienne demande).
  final int? depositAmountMinor;
  final String? depositStatus;

  /// Pourboire (2026-11-09) : montant versé au chauffeur (cents), null tant
  /// qu'aucun pourboire n'a été laissé. Écrit par le serveur (tipDriver).
  final int? tipAmountMinor;

  /// Prix de la livraison avant taxes (cents), lu du devis verrouillé. Null
  /// si la mission n'a pas de ventilation lisible : voir [tipBaseMinor].
  final int? tipPreTaxMinor;
  // Blocage du solde posé à J-4 (lib/scheduledPaymentHold.ts) : état
  // (scheduled / failed / placed / cancelled) et échéance.
  final String? scheduledHoldStatus;
  final DateTime? scheduledHoldDueAt;
  final DateTime? offerExpiresAt;
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
  /// `payments/{id}` rattaché (PAY-03 : reprise de capture côté client).
  final String? activePaymentId;
  final String assignmentMode;
  final DateTime createdAt;
  // Timestamps métier par statut (Phase 5, partie 3) — un champ dédié par
  // transition, distinct de tout `updated_at` générique. Tous nullable :
  // les missions créées avant cette phase n'ont pas ces champs (aucune
  // migration rétrospective des documents existants n'est requise).
  final DateTime? driverToPickupAt;
  final DateTime? arrivedAtPickupAt;
  final DateTime? pickedUpAt;
  final DateTime? inTransitAt;
  final DateTime? arrivedAtDropoffAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  /// Qui a annulé (`customer`, `driver`, `admin`), écrit par le serveur.
  final String? cancelledBy;
  // Late cancellation / travel fee (2026-10-22), written by Cloud Functions
  // only: kind, status, total_minor, driver_minor, platform_minor.
  final Map<String, dynamic>? cancellationFee;
  // Preuve de livraison (Phase 5, partie 3) — dénormalisée sur le document
  // mission par completeDelivery(). Null pour toute mission pas encore
  // (ou jamais) complétée, ou complétée avant l'introduction de ce champ.
  final String? proofOfDeliveryUrl;

  /// Photo de l'article chargé, prise au ramassage (2026-10-26).
  final String? proofOfPickupUrl;

  // Champs dénormalisés écrits par createDeliveryRequest() — lecture seule,
  // jamais recalculés côté Flutter.
  final MissionAddress? pickupAddress;
  final MissionAddress? dropoffAddress;
  final double? distanceKm;
  final double? estimatedDurationMinutes;
  final double driverOfferAmount;
  final double customerTotal;

  const DeliveryMission({
    this.bookingSnapshot,
    this.scheduling,
    this.scheduleState,
    this.dispatchState,
    this.paymentStatus,
    this.depositAmountMinor,
    this.depositStatus,
    this.tipAmountMinor,
    this.tipPreTaxMinor,
    this.scheduledHoldStatus,
    this.scheduledHoldDueAt,
    this.offerExpiresAt,
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
    this.activePaymentId,
    this.assignmentMode = 'standard',
    required this.createdAt,
    this.driverToPickupAt,
    this.arrivedAtPickupAt,
    this.pickedUpAt,
    this.inTransitAt,
    this.arrivedAtDropoffAt,
    this.completedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancelledBy,
    this.cancellationFee,
    this.proofOfDeliveryUrl,
    this.proofOfPickupUrl,
    this.pickupAddress,
    this.dropoffAddress,
    this.distanceKm,
    this.estimatedDurationMinutes,
    this.driverOfferAmount = 0,
    this.customerTotal = 0,
  });

  bool get isOpenForAcceptance => status.isOpenForAcceptance;
  bool get hasAssignedDriver => driverId != null && driverId!.isNotEmpty;
  bool get isInternalTest => assignmentMode == 'internal_test';

  /// Base des pourcentages de pourboire (cents) : le prix avant taxes, sinon
  /// le total. Même calcul que le serveur (functions/src/lib/driverTip.ts).
  int get tipBaseMinor => tipPreTaxMinor ?? (customerTotal * 100).round();

  /// Prix avant taxes (cents) : total payé moins les taxes du devis
  /// verrouillé ; le total s'il n'y a pas de ventilation lisible.
  static int tipBaseMinorFromJson(Map<String, dynamic> json) {
    final rawTotalMinor = json['customer_total_minor'];
    final totalMinor = rawTotalMinor is num
        ? rawTotalMinor.round()
        : ((json['customer_total'] as num? ?? 0) * 100).round();
    if (totalMinor <= 0) return 0;
    final breakdown = json['quote_breakdown'];
    final tax = breakdown is Map ? breakdown['taxAmount'] : null;
    if (tax is! num || tax <= 0) return totalMinor;
    final taxMinor = (tax * 100).round();
    return taxMinor < totalMinor ? totalMinor - taxMinor : totalMinor;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'scheduling': scheduling,
    'schedule_state': scheduleState,
    'dispatch_state': dispatchState,
    'payment_status': paymentStatus,
    if (depositAmountMinor != null)
      'deposit': {'amount_minor': depositAmountMinor, 'status': depositStatus},
    if (tipAmountMinor != null)
      'tip': {'amount_minor': tipAmountMinor, 'status': 'paid'},
    if (scheduledHoldStatus != null)
      'scheduled_hold': {
        'status': scheduledHoldStatus,
        'due_at': scheduledHoldDueAt?.toIso8601String(),
      },
    'offered_until': offerExpiresAt?.toIso8601String(),
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
    'active_payment_id': activePaymentId,
    'assignment_mode': assignmentMode,
    'created_at': createdAt.toIso8601String(),
    'driver_to_pickup_at': driverToPickupAt?.toIso8601String(),
    'arrived_at_pickup_at': arrivedAtPickupAt?.toIso8601String(),
    'picked_up_at': pickedUpAt?.toIso8601String(),
    'in_transit_at': inTransitAt?.toIso8601String(),
    'arrived_at_dropoff_at': arrivedAtDropoffAt?.toIso8601String(),
    'completed_at': completedAt?.toIso8601String(),
    'cancelled_at': cancelledAt?.toIso8601String(),
    'cancellation_reason': cancellationReason,
    'cancelled_by': cancelledBy,
    'proof_of_delivery_url': proofOfDeliveryUrl,
    'proof_of_pickup_url': proofOfPickupUrl,
    'distance_km': distanceKm,
    'estimated_duration_minutes': estimatedDurationMinutes,
    'driver_offer_amount': driverOfferAmount,
    'customer_total': customerTotal,
  };

  factory DeliveryMission.fromJson(String id, Map<String, dynamic> json) {
    return DeliveryMission(
      bookingSnapshot: json['booking_snapshot'] is Map
          ? Map<String, dynamic>.from(json['booking_snapshot'] as Map)
          : null,
      scheduling: json['scheduling'] is Map
          ? Map<String, dynamic>.from(json['scheduling'] as Map)
          : null,
      scheduleState: json['schedule_state'] as String?,
      dispatchState: json['dispatch_state'] as String?,
      paymentStatus: json['payment_status'] as String?,
      depositAmountMinor: json['deposit'] is Map
          ? (json['deposit']['amount_minor'] as num?)?.toInt()
          : null,
      depositStatus: json['deposit'] is Map
          ? json['deposit']['status'] as String?
          : null,
      tipAmountMinor:
          json['tip'] is Map && json['tip']['status'] == 'paid'
          ? (json['tip']['amount_minor'] as num?)?.toInt()
          : null,
      tipPreTaxMinor: tipBaseMinorFromJson(json),
      scheduledHoldStatus: json['scheduled_hold'] is Map
          ? json['scheduled_hold']['status'] as String?
          : null,
      scheduledHoldDueAt: json['scheduled_hold'] is Map
          ? parseFirestoreDate(json['scheduled_hold']['due_at'])
          : null,
      offerExpiresAt: parseFirestoreDate(json['offered_until']),
      id: id,
      customerId: json['customer_id'] as String? ?? '',
      customerDisplayName: json['customer_display_name'] as String?,
      itemCategoryKey: json['item_category_key'] as String? ?? '',
      description: json['description'] as String? ?? '',
      requiredVehicleCategory: VehicleCategoryX.fromFirestoreValue(
        json['required_vehicle_category'] as String?,
      ),
      status: MissionStatusX.fromFirestoreValue(json['status'] as String?),
      driverId: json['driver_id'] as String?,
      driverDisplayName: json['driver_display_name'] as String?,
      acceptedAt: parseFirestoreDate(json['accepted_at']),
      pricingVersion: json['pricing_version'] as String? ?? 'UNCONFIGURED',
      activeQuoteId: json['active_quote_id'] as String?,
      activeFinancialSnapshotId:
          json['active_financial_snapshot_id'] as String?,
      activePaymentId: json['active_payment_id'] as String?,
      assignmentMode: json['assignment_mode'] as String? ?? 'standard',
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      driverToPickupAt: parseFirestoreDate(json['driver_to_pickup_at']),
      arrivedAtPickupAt: parseFirestoreDate(json['arrived_at_pickup_at']),
      pickedUpAt: parseFirestoreDate(json['picked_up_at']),
      inTransitAt: parseFirestoreDate(json['in_transit_at']),
      arrivedAtDropoffAt: parseFirestoreDate(json['arrived_at_dropoff_at']),
      completedAt: parseFirestoreDate(json['completed_at']),
      cancelledAt: parseFirestoreDate(json['cancelled_at']),
      cancellationReason: json['cancellation_reason'] as String?,
      cancelledBy: json['cancelled_by'] as String?,
      cancellationFee: json['cancellation_fee'] is Map
          ? Map<String, dynamic>.from(json['cancellation_fee'] as Map)
          : null,
      proofOfDeliveryUrl: json['proof_of_delivery_url'] as String?,
      proofOfPickupUrl: json['proof_of_pickup_url'] as String?,
      pickupAddress: _parseAddress(json['pickup_address']),
      dropoffAddress: _parseAddress(json['dropoff_address']),
      distanceKm: (json['distance_km'] as num?)?.toDouble(),
      estimatedDurationMinutes: (json['estimated_duration_minutes'] as num?)
          ?.toDouble(),
      driverOfferAmount: (json['driver_offer_amount'] as num? ?? 0).toDouble(),
      customerTotal: (json['customer_total'] as num? ?? 0).toDouble(),
    );
  }
}
