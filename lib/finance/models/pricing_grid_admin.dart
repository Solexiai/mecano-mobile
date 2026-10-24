// ---------------------------------------------------------------------------
// Modèles de la grille de tarifs admin : versions publiées, résultat du
// simulateur (`previewPricingConfiguration`) et erreurs de publication.
// Lecture seule : les montants viennent tels quels du serveur (cents).
// ---------------------------------------------------------------------------

import '../../backend/models/firestore_date.dart';

Map<String, dynamic> _deepMap(Object? value) {
  if (value is! Map) return <String, dynamic>{};
  return value.map((k, v) => MapEntry('$k', _deep(v)));
}

Object? _deep(Object? value) {
  if (value is Map) return _deepMap(value);
  if (value is List) return value.map(_deep).toList();
  return value;
}

/// Conversion profonde d'un résultat de fonction callable
/// (`Map<Object?, Object?>`) en `Map<String, dynamic>`.
Map<String, dynamic> callableMap(Object? value) => _deepMap(value);

class AdminPricingVersionInfo {
  const AdminPricingVersionInfo({
    required this.id,
    required this.raw,
    this.effectiveFrom,
    this.previousVersion,
    this.publishedByUserId,
    this.changeNote,
  });

  final String id;
  final Map<String, dynamic> raw;
  final DateTime? effectiveFrom;
  final String? previousVersion;
  final String? publishedByUserId;
  final String? changeNote;

  factory AdminPricingVersionInfo.fromDoc(String id, Map<String, dynamic> data) {
    return AdminPricingVersionInfo(
      id: id,
      raw: _deepMap(data),
      effectiveFrom: parseFirestoreDate(data['effective_from']),
      previousVersion: data['previous_pricing_version'] as String?,
      publishedByUserId: data['published_by_user_id'] as String?,
      changeNote: data['change_note'] as String?,
    );
  }
}

class PricingPreviewAmounts {
  const PricingPreviewAmounts({
    required this.customerTotalMinor,
    required this.subtotalMinor,
    required this.serviceFeeMinor,
    required this.taxMinor,
    required this.platformMinor,
    required this.driverMinor,
    required this.cardHoldMinor,
  });

  final int customerTotalMinor;
  final int subtotalMinor;
  final int serviceFeeMinor;
  final int taxMinor;
  final int platformMinor;
  final int driverMinor;
  final int cardHoldMinor;

  static PricingPreviewAmounts? fromJson(Object? raw) {
    if (raw is! Map) return null;
    int v(String key) => (raw[key] as num? ?? 0).round();
    return PricingPreviewAmounts(
      customerTotalMinor: v('customer_total_minor'),
      subtotalMinor: v('subtotal_minor'),
      serviceFeeMinor: v('service_fee_minor'),
      taxMinor: v('tax_minor'),
      platformMinor: v('platform_minor'),
      driverMinor: v('driver_minor'),
      cardHoldMinor: v('card_hold_minor'),
    );
  }
}

class PricingPreviewRow {
  const PricingPreviewRow({required this.id, this.current, this.draft});

  final String id;
  final PricingPreviewAmounts? current;
  final PricingPreviewAmounts? draft;
}

class PricingPreviewResult {
  const PricingPreviewResult({
    required this.activeVersion,
    required this.errors,
    required this.rows,
  });

  final String? activeVersion;

  /// Erreurs de validation du brouillon (vide = publiable).
  final List<String> errors;
  final List<PricingPreviewRow> rows;

  factory PricingPreviewResult.fromJson(Map<String, dynamic> json) {
    final rows = (json['rows'] is List ? json['rows'] as List : const [])
        .whereType<Map>()
        .map(
          (r) => PricingPreviewRow(
            id: '${r['id'] ?? ''}',
            current: PricingPreviewAmounts.fromJson(r['current']),
            draft: PricingPreviewAmounts.fromJson(r['draft']),
          ),
        )
        .toList();
    return PricingPreviewResult(
      activeVersion: json['activePricingVersion'] as String?,
      errors: (json['errors'] is List ? json['errors'] as List : const [])
          .map((e) => '$e')
          .toList(),
      rows: rows,
    );
  }
}

/// Refus du serveur à la simulation ou à la publication.
class PricingGridException implements Exception {
  const PricingGridException({
    required this.code,
    required this.message,
    this.reason,
    this.errors = const [],
  });

  final String code;
  final String message;
  final String? reason;
  final List<String> errors;

  @override
  String toString() => message;
}
