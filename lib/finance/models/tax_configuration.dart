// ---------------------------------------------------------------------------
// TaxConfiguration — projection LECTURE SEULE des documents versionnés
// `tax_configs/{jurisdiction}_{taxCode}_v{N}` (Cloud Functions, voir
// `functions/src/lib/types.ts` -> `TaxConfigDoc`,
// `functions/src/functions/updateTaxConfiguration.ts`,
// `functions/src/lib/taxEngine.ts`).
//
// RÈGLES CRITIQUES (Bloc L) :
// - La collection `tax_configs` contient DEUX types de documents : les
//   versions immuables (`{jurisdiction}_{taxCode}_v{N}`) et des alias
//   mutables (`{jurisdiction}_{taxCode}_current`, `is_alias: true`) qui ne
//   sont PAS des `TaxConfigDoc` complets — voir `updateTaxConfiguration.ts`.
//   Ce modèle ne mappe QUE les documents de version réels ; le repository
//   est responsable de filtrer les alias avant de construire ce modèle
//   (voir `firebase_finance_repository.dart`, section Bloc L).
// - Chaque écriture (`updateTaxConfiguration`) crée une NOUVELLE version —
//   jamais un overwrite. Ce modèle Dart reste donc immuable une fois
//   construit et n'a AUCUNE méthode d'écriture Firestore directe.
// - Directive Bloc L point 17 : ce modèle est une projection TECHNIQUE
//   neutre — il ne présume/n'injecte AUCUNE valeur fiscale par défaut
//   (ex: TPS/TVQ Québec). Les valeurs affichées sont EXACTEMENT celles
//   déjà écrites par un admin via `updateTaxConfiguration`.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class TaxConfiguration {
  /// ID du document Firestore (`{jurisdiction}_{taxCode}_v{N}`).
  final String docId;

  final String jurisdiction;
  final String taxCode;
  final TaxType taxType;
  final String displayName;

  /// Taux exprimé en fraction (ex: 0.05 pour 5%) — AUCUNE valeur par
  /// défaut présumée, lu tel quel depuis le document serveur.
  final double rate;

  final List<String> taxableComponents;
  final bool appliesToTransport;
  final bool appliesToPlatformFees;

  final DateTime effectiveFrom;
  final DateTime? effectiveUntil;
  final bool enabled;
  final int version;
  final bool isActive;
  final String taxRegistrationOwner; // 'platform' | 'driver' | 'not_applicable'

  final DateTime createdAt;
  final DateTime updatedAt;
  final String updatedByUserId;

  const TaxConfiguration({
    required this.docId,
    required this.jurisdiction,
    required this.taxCode,
    required this.taxType,
    required this.displayName,
    required this.rate,
    required this.taxableComponents,
    required this.appliesToTransport,
    required this.appliesToPlatformFees,
    required this.effectiveFrom,
    this.effectiveUntil,
    required this.enabled,
    required this.version,
    required this.isActive,
    required this.taxRegistrationOwner,
    required this.createdAt,
    required this.updatedAt,
    required this.updatedByUserId,
  });

  /// true si `effectiveUntil` est null (toujours active depuis
  /// `effectiveFrom`, tant que `enabled` reste vrai).
  bool get isOpenEnded => effectiveUntil == null;

  Map<String, dynamic> toJson() => {
    'jurisdiction': jurisdiction,
    'tax_code': taxCode,
    'tax_type': taxType.firestoreValue,
    'display_name': displayName,
    'rate': rate,
    'taxable_components': taxableComponents,
    'applies_to_transport': appliesToTransport,
    'applies_to_platform_fees': appliesToPlatformFees,
    'effective_from': effectiveFrom.toIso8601String(),
    'effective_until': effectiveUntil?.toIso8601String(),
    'enabled': enabled,
    'version': version,
    'is_active': isActive,
    'tax_registration_owner': taxRegistrationOwner,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'updated_by_user_id': updatedByUserId,
  };

  /// Parse un document `tax_configs/{jurisdiction}_{taxCode}_v{N}` réel.
  /// N'appeler cette factory QUE sur un document de version (pas un alias
  /// `is_alias: true`) — voir note d'en-tête.
  factory TaxConfiguration.fromJson(String docId, Map<String, dynamic> json) {
    final rawComponents = json['taxable_components'];
    return TaxConfiguration(
      docId: docId,
      jurisdiction: json['jurisdiction'] as String? ?? '',
      taxCode: json['tax_code'] as String? ?? '',
      taxType: TaxTypeX.fromFirestoreValue(json['tax_type'] as String?),
      displayName: json['display_name'] as String? ?? '',
      rate: (json['rate'] as num? ?? 0).toDouble(),
      taxableComponents: rawComponents is List
          ? rawComponents.whereType<String>().toList()
          : const <String>[],
      appliesToTransport: json['applies_to_transport'] as bool? ?? false,
      appliesToPlatformFees: json['applies_to_platform_fees'] as bool? ?? false,
      effectiveFrom:
          parseFirestoreDate(json['effective_from']) ?? DateTime.now(),
      effectiveUntil: parseFirestoreDate(json['effective_until']),
      enabled: json['enabled'] as bool? ?? false,
      version: (json['version'] as num? ?? 1).toInt(),
      isActive: json['is_active'] as bool? ?? false,
      taxRegistrationOwner:
          json['tax_registration_owner'] as String? ?? 'not_applicable',
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
      updatedByUserId: json['updated_by_user_id'] as String? ?? '',
    );
  }
}
