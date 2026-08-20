// ---------------------------------------------------------------------------
// DriverPayoutInfo — projection LECTURE SEULE du document
// `driver_payouts/{payoutId}` (Cloud Functions, voir
// `functions/src/lib/types.ts` -> `DriverPayoutDoc`).
//
// RÈGLES CRITIQUES (Bloc K) :
// - Ce document est écrit UNIQUEMENT par les Cloud Functions du pipeline
//   de payout (calculateDriverPayout / processDriverPayout / webhooks
//   provider) — voir Security Rules `driver_payouts/{payoutId}` :
//   `allow write: if false;` en toute circonstance côté client.
// - `amount_minor` est en UNITÉS MINEURES ENTIÈRES (cents), convention
//   `*_minor` du projet.
// - `payout_eligible_at` est une date SERVEUR déjà calculée
//   (created_at + payout_hold_period_hours, appliqué par la Cloud
//   Function) — ne JAMAIS la recalculer côté Flutter à partir de
//   `payout_hold_period_hours` : toujours lire `payoutEligibleAt`
//   directement (voir directive Bloc K point 8).
// - `financial_snapshot_ids` référence les missions couvertes par CE
//   payout (un payout peut regrouper plusieurs missions), utile pour lier
//   un payout à son historique de gains mais ne remplace pas
//   `FinancialSnapshot`/`LedgerEntry`/`MissionFinancialBalance` comme
//   source des gains détaillés par mission (voir directive Bloc K
//   point 3).
// - AUCUN calcul local : chaque champ est une lecture directe du document
//   serveur, jamais une addition/soustraction Flutter.
// - Rétrocompatibilité : tous les champs optionnels/timestamps peuvent
//   être absents/null (payout jamais planifié, jamais échoué, jamais
//   renversé) — un document minimal ne doit jamais faire planter l'UI.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class DriverPayoutInfo {
  final String payoutId;
  final String driverId;

  /// Missions (FinancialSnapshot ids) regroupées dans ce payout.
  final List<String> financialSnapshotIds;

  final int amountMinor;
  final String currency;
  final PayoutStatus status;

  final int payoutHoldPeriodHours;

  /// Date SERVEUR déjà calculée à laquelle ce payout devient éligible au
  /// versement. Ne jamais recalculer à partir de payoutHoldPeriodHours.
  final DateTime payoutEligibleAt;

  final String? providerPayoutId;
  final String? connectedAccountId;

  final DateTime createdAt;
  final DateTime? scheduledAt;
  final DateTime? processingAt;
  final DateTime? paidAt;
  final DateTime? failedAt;

  /// Raison d'échec brute serveur — jamais un code provider brut, voir
  /// directive Bloc K point 9 (ne jamais exposer d'info technique
  /// sensible au chauffeur ; l'UI doit reformuler ce champ si besoin).
  final String? failureReason;

  final DateTime? reversedAt;
  final String? reversalReason;

  const DriverPayoutInfo({
    required this.payoutId,
    required this.driverId,
    required this.financialSnapshotIds,
    required this.amountMinor,
    required this.currency,
    required this.status,
    required this.payoutHoldPeriodHours,
    required this.payoutEligibleAt,
    this.providerPayoutId,
    this.connectedAccountId,
    required this.createdAt,
    this.scheduledAt,
    this.processingAt,
    this.paidAt,
    this.failedAt,
    this.failureReason,
    this.reversedAt,
    this.reversalReason,
  });

  bool get isPaid => status == PayoutStatus.paid;
  bool get isFailed => status == PayoutStatus.failed;
  bool get isReversed => status == PayoutStatus.reversed;
  bool get isHeld => status == PayoutStatus.held;
  bool get isPending => status == PayoutStatus.pending;
  bool get isEligible => status == PayoutStatus.eligible;
  bool get isScheduled => status == PayoutStatus.scheduled;
  bool get isProcessing => status == PayoutStatus.processing;

  /// Le payout est encore "en cours" (pas encore terminal) : utile pour
  /// distinguer les payouts affichés dans "gains disponibles/en attente"
  /// de ceux dans "historique des versements".
  bool get isTerminal =>
      status == PayoutStatus.paid ||
      status == PayoutStatus.failed ||
      status == PayoutStatus.reversed;

  Map<String, dynamic> toJson() => {
    'driver_id': driverId,
    'financial_snapshot_ids': financialSnapshotIds,
    'amount_minor': amountMinor,
    'currency': currency,
    'status': status.firestoreValue,
    'payout_hold_period_hours': payoutHoldPeriodHours,
    'payout_eligible_at': payoutEligibleAt.toIso8601String(),
    'provider_payout_id': providerPayoutId,
    'connected_account_id': connectedAccountId,
    'created_at': createdAt.toIso8601String(),
    'scheduled_at': scheduledAt?.toIso8601String(),
    'processing_at': processingAt?.toIso8601String(),
    'paid_at': paidAt?.toIso8601String(),
    'failed_at': failedAt?.toIso8601String(),
    'failure_reason': failureReason,
    'reversed_at': reversedAt?.toIso8601String(),
    'reversal_reason': reversalReason,
  };

  /// Parse un document `driver_payouts/{payoutId}` réel. Repli sûr sur
  /// chaque champ : un document partiel (ancien payout, pipeline pas
  /// encore totalement rempli) ne doit jamais faire planter l'UI.
  factory DriverPayoutInfo.fromJson(
    String payoutId,
    Map<String, dynamic> json,
  ) {
    return DriverPayoutInfo(
      payoutId: payoutId,
      driverId: json['driver_id'] as String? ?? '',
      financialSnapshotIds:
          (json['financial_snapshot_ids'] as List?)
              ?.whereType<String>()
              .toList() ??
          const [],
      amountMinor: (json['amount_minor'] as num? ?? 0).toInt(),
      currency: json['currency'] as String? ?? 'CAD',
      status: PayoutStatusX.fromFirestoreValue(json['status'] as String?),
      payoutHoldPeriodHours: (json['payout_hold_period_hours'] as num? ?? 0)
          .toInt(),
      payoutEligibleAt:
          parseFirestoreDate(json['payout_eligible_at']) ?? DateTime.now(),
      providerPayoutId: json['provider_payout_id'] as String?,
      connectedAccountId: json['connected_account_id'] as String?,
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      scheduledAt: parseFirestoreDate(json['scheduled_at']),
      processingAt: parseFirestoreDate(json['processing_at']),
      paidAt: parseFirestoreDate(json['paid_at']),
      failedAt: parseFirestoreDate(json['failed_at']),
      failureReason: json['failure_reason'] as String?,
      reversedAt: parseFirestoreDate(json['reversed_at']),
      reversalReason: json['reversal_reason'] as String?,
    );
  }
}
