// ---------------------------------------------------------------------------
// DeliveryQuote (Firestore-ready) — collection `delivery_quotes/{id}`.
//
// Un devis a une durée de validité limitée (voir QuoteConfig). Créé par la
// Cloud Function `calculateDeliveryQuote()`. Devient obsolète après
// `expiresAt` et ne peut plus servir de base à une acceptation.
// ---------------------------------------------------------------------------

class DeliveryQuote {
  final String id;
  final String missionId;
  final String pricingVersion;
  final double customerTotal;
  final DateTime createdAt;
  final DateTime expiresAt;
  final bool isConsumed; // true une fois qu'une mission a été créée à partir de ce devis

  const DeliveryQuote({
    required this.id,
    required this.missionId,
    required this.pricingVersion,
    required this.customerTotal,
    required this.createdAt,
    required this.expiresAt,
    this.isConsumed = false,
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
    return DeliveryQuote(
      id: id,
      missionId: json['mission_id'] as String? ?? '',
      pricingVersion: json['pricing_version'] as String? ?? 'UNCONFIGURED',
      customerTotal: (json['customer_total'] as num? ?? 0).toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'] as String)
          : DateTime.now(),
      isConsumed: json['is_consumed'] as bool? ?? false,
    );
  }
}
