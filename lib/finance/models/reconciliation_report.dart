// ---------------------------------------------------------------------------
// ReconciliationReport — projection LECTURE SEULE du document
// `reconciliation_reports/{reportId}` (Cloud Functions, voir
// `functions/src/lib/types.ts` -> `ReconciliationReportDoc`/
// `ReconciliationAnomaly`, `functions/src/lib/reconciliationEngine.ts`,
// `functions/src/functions/runReconciliation.ts`,
// `functions/src/functions/resolveReconciliationAnomaly.ts`).
//
// RÈGLES CRITIQUES (Bloc L) :
// - `anomalies` est un TABLEAU EMBARQUÉ (pas une sous-collection) —
//   `resolveReconciliationAnomaly` cible une anomalie par
//   `(reportId, anomalyIndex)`. `ReconciliationAnomaly.index` ci-dessous
//   est donc dérivé de la position dans le tableau au moment du parsing
//   (jamais un champ Firestore natif) et DOIT être utilisé tel quel comme
//   `anomalyIndex` lors de l'appel de la Cloud Function.
// - Ce modèle n'écrit jamais Firestore directement : toute
//   résolution/acknowledgement passe par `resolveReconciliationAnomaly`.
// - Montants en UNITÉS MINEURES ENTIÈRES (cents).
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class ReconciliationAnomaly {
  /// Position dans le tableau `anomalies` du `ReconciliationReportDoc`
  /// parent — voir note d'en-tête. Utilisé tel quel comme `anomalyIndex`
  /// pour `resolveReconciliationAnomaly`.
  final int index;

  final ReconciliationAnomalySeverity severity;
  final String type;
  final String? missionId;
  final String? paymentId;
  final String? payoutId;
  final String? refundId;
  final int? expectedAmountMinor;
  final int? actualAmountMinor;
  final String description;
  final DateTime detectedAt;
  final ReconciliationAnomalyStatus status;
  final String? resolutionNotes;

  const ReconciliationAnomaly({
    required this.index,
    required this.severity,
    required this.type,
    this.missionId,
    this.paymentId,
    this.payoutId,
    this.refundId,
    this.expectedAmountMinor,
    this.actualAmountMinor,
    required this.description,
    required this.detectedAt,
    required this.status,
    this.resolutionNotes,
  });

  bool get isOpen => status == ReconciliationAnomalyStatus.open;
  bool get isAcknowledged => status == ReconciliationAnomalyStatus.acknowledged;
  bool get isResolved => status == ReconciliationAnomalyStatus.resolved;
  bool get isCritical => severity == ReconciliationAnomalySeverity.critical;
  bool get isWarning => severity == ReconciliationAnomalySeverity.warning;

  Map<String, dynamic> toJson() => {
    'severity': severity.firestoreValue,
    'type': type,
    'mission_id': missionId,
    'payment_id': paymentId,
    'payout_id': payoutId,
    'refund_id': refundId,
    'expected_amount_minor': expectedAmountMinor,
    'actual_amount_minor': actualAmountMinor,
    'description': description,
    'detected_at': detectedAt.toIso8601String(),
    'status': status.firestoreValue,
    'resolution_notes': resolutionNotes,
  };

  factory ReconciliationAnomaly.fromJson(int index, Map<String, dynamic> json) {
    return ReconciliationAnomaly(
      index: index,
      severity: ReconciliationAnomalySeverityX.fromFirestoreValue(
        json['severity'] as String?,
      ),
      type: json['type'] as String? ?? 'unknown',
      missionId: json['mission_id'] as String?,
      paymentId: json['payment_id'] as String?,
      payoutId: json['payout_id'] as String?,
      refundId: json['refund_id'] as String?,
      expectedAmountMinor: (json['expected_amount_minor'] as num?)?.toInt(),
      actualAmountMinor: (json['actual_amount_minor'] as num?)?.toInt(),
      description: json['description'] as String? ?? '',
      detectedAt: parseFirestoreDate(json['detected_at']) ?? DateTime.now(),
      status: ReconciliationAnomalyStatusX.fromFirestoreValue(
        json['status'] as String?,
      ),
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }
}

class ReconciliationReport {
  final String reportId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final ReconciliationStatus status;
  final List<ReconciliationAnomaly> anomalies;
  final int totalPaymentsChecked;
  final int totalPayoutsChecked;
  final int totalRefundsChecked;
  final int reconciliationDifferenceMinor;
  final DateTime createdAt;
  final DateTime lastReconciledAt;

  const ReconciliationReport({
    required this.reportId,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    required this.anomalies,
    required this.totalPaymentsChecked,
    required this.totalPayoutsChecked,
    required this.totalRefundsChecked,
    required this.reconciliationDifferenceMinor,
    required this.createdAt,
    required this.lastReconciledAt,
  });

  int get openAnomaliesCount => anomalies.where((a) => a.isOpen).length;
  int get criticalAnomaliesCount =>
      anomalies.where((a) => a.isCritical && !a.isResolved).length;
  int get warningAnomaliesCount =>
      anomalies.where((a) => a.isWarning && !a.isResolved).length;
  int get resolvedAnomaliesCount => anomalies.where((a) => a.isResolved).length;
  bool get hasAnomalies => anomalies.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'report_id': reportId,
    'period_start': periodStart.toIso8601String(),
    'period_end': periodEnd.toIso8601String(),
    'status': status.firestoreValue,
    'anomalies': anomalies.map((a) => a.toJson()).toList(),
    'total_payments_checked': totalPaymentsChecked,
    'total_payouts_checked': totalPayoutsChecked,
    'total_refunds_checked': totalRefundsChecked,
    'reconciliation_difference_minor': reconciliationDifferenceMinor,
    'created_at': createdAt.toIso8601String(),
    'last_reconciled_at': lastReconciledAt.toIso8601String(),
  };

  /// Parse un document `reconciliation_reports/{id}` réel. Repli sûr sur
  /// chaque champ ; `anomalies` absent/malformé retombe sur une liste vide
  /// plutôt que de planter l'écran admin.
  factory ReconciliationReport.fromJson(
    String reportId,
    Map<String, dynamic> json,
  ) {
    final rawAnomalies = json['anomalies'];
    final anomalies = <ReconciliationAnomaly>[];
    if (rawAnomalies is List) {
      for (var i = 0; i < rawAnomalies.length; i++) {
        final raw = rawAnomalies[i];
        if (raw is Map) {
          anomalies.add(
            ReconciliationAnomaly.fromJson(i, Map<String, dynamic>.from(raw)),
          );
        }
      }
    }
    return ReconciliationReport(
      reportId: json['report_id'] as String? ?? reportId,
      periodStart: parseFirestoreDate(json['period_start']) ?? DateTime.now(),
      periodEnd: parseFirestoreDate(json['period_end']) ?? DateTime.now(),
      status: ReconciliationStatusX.fromFirestoreValue(
        json['status'] as String?,
      ),
      anomalies: anomalies,
      totalPaymentsChecked: (json['total_payments_checked'] as num? ?? 0)
          .toInt(),
      totalPayoutsChecked: (json['total_payouts_checked'] as num? ?? 0).toInt(),
      totalRefundsChecked: (json['total_refunds_checked'] as num? ?? 0).toInt(),
      reconciliationDifferenceMinor:
          (json['reconciliation_difference_minor'] as num? ?? 0).toInt(),
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      lastReconciledAt:
          parseFirestoreDate(json['last_reconciled_at']) ?? DateTime.now(),
    );
  }
}
