// ---------------------------------------------------------------------------
// PayoutPolicyConfiguration — projection LECTURE SEULE du document unique
// `payout_policy_configs/default` (Cloud Functions, voir
// `functions/src/lib/types.ts` -> `PayoutPolicyConfigDoc`,
// `functions/src/functions/updatePayoutPolicyConfiguration.ts`).
//
// RÈGLES CRITIQUES (Bloc L) :
// - Document MUTABLE UNIQUE (id fixe `default`, pas de versioning en
//   tableau/collection) — contrairement à `TaxConfiguration`. Chaque appel
//   `updatePayoutPolicyConfiguration` écrase ce document, mais journalise
//   l'ancienne configuration via `audit_logs` (voir Cloud Function) : ce
//   modèle Dart n'expose donc PAS d'historique de versions, uniquement
//   l'état courant + sa date de dernière modification.
// - Trois catégories RÉELLEMENT supportées côté serveur : default (délai
//   standard), new_driver (nouveau chauffeur), risky_driver (chauffeur à
//   risque/suspendu — voir `readPayoutPolicyConfig()`). Aucune catégorie
//   supplémentaire n'est inventée ici.
// - Aucune écriture Firestore directe : la modification passe exclusivement
//   par `updatePayoutPolicyConfiguration` (Cloud Function).
// ---------------------------------------------------------------------------

import '../../backend/models/firestore_date.dart';

class PayoutPolicyConfiguration {
  final int defaultHoldPeriodHours;
  final int newDriverHoldPeriodHours;
  final int riskyDriverHoldPeriodHours;

  final DateTime updatedAt;
  final String updatedByUserId;

  const PayoutPolicyConfiguration({
    required this.defaultHoldPeriodHours,
    required this.newDriverHoldPeriodHours,
    required this.riskyDriverHoldPeriodHours,
    required this.updatedAt,
    required this.updatedByUserId,
  });

  /// Valeurs de repli EXPLICITES (72h) utilisées côté serveur avant tout
  /// appel admin — voir `readPayoutPolicyConfig()` dans
  /// `updatePayoutPolicyConfiguration.ts`. Reflète le même filet de
  /// sécurité de bootstrap côté UI admin (affichage uniquement, jamais
  /// utilisé pour un calcul de payout réel).
  factory PayoutPolicyConfiguration.bootstrapDefault() =>
      PayoutPolicyConfiguration(
        defaultHoldPeriodHours: 72,
        newDriverHoldPeriodHours: 72,
        riskyDriverHoldPeriodHours: 72,
        updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
        updatedByUserId: '',
      );

  Map<String, dynamic> toJson() => {
    'default_hold_period_hours': defaultHoldPeriodHours,
    'new_driver_hold_period_hours': newDriverHoldPeriodHours,
    'risky_driver_hold_period_hours': riskyDriverHoldPeriodHours,
    'updated_at': updatedAt.toIso8601String(),
    'updated_by_user_id': updatedByUserId,
  };

  /// Parse `payout_policy_configs/default`. Repli sûr sur 72h par champ
  /// manquant (cohérent avec `readPayoutPolicyConfig()` côté serveur).
  factory PayoutPolicyConfiguration.fromJson(Map<String, dynamic> json) {
    return PayoutPolicyConfiguration(
      defaultHoldPeriodHours: (json['default_hold_period_hours'] as num? ?? 72)
          .toInt(),
      newDriverHoldPeriodHours:
          (json['new_driver_hold_period_hours'] as num? ?? 72).toInt(),
      riskyDriverHoldPeriodHours:
          (json['risky_driver_hold_period_hours'] as num? ?? 72).toInt(),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
      updatedByUserId: json['updated_by_user_id'] as String? ?? '',
    );
  }
}
