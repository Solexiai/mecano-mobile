// ---------------------------------------------------------------------------
// DeliveryQuote (Firestore-ready) — collection `delivery_quotes/{id}`.
//
// Un devis a une durée de validité limitée (voir QuoteConfig). Créé par la
// Cloud Function `calculateDeliveryQuote()`. Devient obsolète après
// `expiresAt` et ne peut plus servir de base à une acceptation.
//
// EXTENSION (Phase 4) : `quote_breakdown` (écrit par
// `calculateDeliveryQuote.ts`, miroir de `CustomerPricingResult` dans
// `functions/src/lib/pricingEngine.ts`) est désormais exposé via
// `QuoteBreakdown` pour permettre à l'UI d'afficher le détail réel du devis
// (subtotal / frais / taxes / total) — jamais recalculé côté Flutter.
// ---------------------------------------------------------------------------

import 'firestore_date.dart';

/// Miroir exact de `CustomerPricingResult` (functions/src/lib/pricingEngine.ts).
/// Purement un objet d'affichage — jamais recalculé côté client.
class QuoteBreakdown {
  final double missionBaseValue;
  final double handlingFeesTotal;
  final double waitingFee;
  final double additionalStopsFee;
  final double surchargesTotal;
  final double subtotal; // après remise client
  final double customerDiscountAmount;
  final double customerServiceFee;
  final double taxAmount;
  final double customerTotal;

  const QuoteBreakdown({
    required this.missionBaseValue,
    required this.handlingFeesTotal,
    required this.waitingFee,
    required this.additionalStopsFee,
    required this.surchargesTotal,
    required this.subtotal,
    required this.customerDiscountAmount,
    required this.customerServiceFee,
    required this.taxAmount,
    required this.customerTotal,
  });

  factory QuoteBreakdown.fromJson(Map<String, dynamic> json) => QuoteBreakdown(
        missionBaseValue: (json['missionBaseValue'] as num? ?? 0).toDouble(),
        handlingFeesTotal: (json['handlingFeesTotal'] as num? ?? 0).toDouble(),
        waitingFee: (json['waitingFee'] as num? ?? 0).toDouble(),
        additionalStopsFee: (json['additionalStopsFee'] as num? ?? 0).toDouble(),
        surchargesTotal: (json['surchargesTotal'] as num? ?? 0).toDouble(),
        subtotal: (json['subtotal'] as num? ?? 0).toDouble(),
        customerDiscountAmount: (json['customerDiscountAmount'] as num? ?? 0).toDouble(),
        customerServiceFee: (json['customerServiceFee'] as num? ?? 0).toDouble(),
        taxAmount: (json['taxAmount'] as num? ?? 0).toDouble(),
        customerTotal: (json['customerTotal'] as num? ?? 0).toDouble(),
      );
}

class DeliveryQuote {
  final String id;
  final String missionId;
  final String pricingVersion;
  final double customerTotal;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isConsumed; // true une fois qu'une mission a été créée à partir de ce devis
  final QuoteBreakdown? breakdown;

  const DeliveryQuote({
    required this.id,
    required this.missionId,
    required this.pricingVersion,
    required this.customerTotal,
    required this.createdAt,
    required this.expiresAt,
    this.isConsumed = false,
    this.breakdown,
  });

  bool isValidAt(DateTime now) => !isConsumed && now.isBefore(expiresAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'mission_id': missionId,
        'pricing_version': pricingVersion,
        'customer_total': customerTotal,
        'created_at': createdAt.toIso8601String(),
        'expires_at': expiresAt.toIso8601String(),
        'is_consumed': isConsumed,
      };

  factory DeliveryQuote.fromJson(String id, Map<String, dynamic> json) {
    final rawBreakdown = json['quote_breakdown'];
    return DeliveryQuote(
      id: id,
      missionId: json['mission_id'] as String? ?? '',
      pricingVersion: json['pricing_version'] as String? ?? 'UNCONFIGURED',
      customerTotal: (json['customer_total'] as num? ?? 0).toDouble(),
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      expiresAt: parseFirestoreDate(json['expires_at']) ?? DateTime.now(),
      isConsumed: json['is_consumed'] as bool? ?? false,
      breakdown: rawBreakdown is Map
          ? QuoteBreakdown.fromJson(Map<String, dynamic>.from(rawBreakdown))
          : null,
    );
  }
}
