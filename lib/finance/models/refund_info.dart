// ---------------------------------------------------------------------------
// RefundInfo — projection LECTURE SEULE du document `refunds/{refundId}`
// (Cloud Functions, voir `functions/src/lib/types.ts` -> `RefundDoc`).
//
// RÈGLES CRITIQUES (Bloc J) :
// - Ce document est append-only côté serveur (voir `refundPayment.ts`) :
//   un remboursement partiel supplémentaire crée un NOUVEAU `RefundDoc`,
//   jamais une modification d'un refund existant. Ce modèle Dart reste
//   donc lui aussi immuable une fois construit.
// - Montants en UNITÉS MINEURES ENTIÈRES (cents), convention `*_minor`.
// - `RefundDoc` n'a PAS de timestamp `failed_at` dédié : l'échec est
//   documenté uniquement par `failed_reason` (String?). On expose donc
//   `failedReason` (String?) plutôt qu'un `failedAt` (DateTime?) inventé —
//   conforme à la consigne "ne pas inventer de schéma". Si l'appelant a
//   besoin d'une date d'échec approximative, `processingAt`/`createdAt`
//   restent les seules dates fiables disponibles sur ce document.
// - `related_payout_id`/`is_post_payout` sont des détails de compensation
//   INTERNE (payout chauffeur) : conservés dans le modèle brut pour
//   complétude et pour l'usage admin/chauffeur (Bloc K/L), mais NE DOIVENT
//   PAS être affichés sur la vue financière CLIENT (Bloc J point 7).
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class RefundInfo {
  final String refundId;
  final String paymentId;
  final String missionId;

  final int amountMinor;
  final RefundReason reason;

  final String initiatedByUserId;
  final String initiatedByRole;
  final bool isAdminInitiated;

  /// true si ce refund a été demandé APRÈS qu'un `driver_payouts` lié à
  /// cette mission soit déjà passé en statut PAID. Détail interne — voir
  /// note d'en-tête, ne pas exposer côté client.
  final bool isPostPayout;
  final String? relatedPayoutId;

  final RefundStatus status;
  final String? providerRefundId;
  final bool reverseTransfer;
  final bool refundApplicationFee;

  final DateTime createdAt;
  final DateTime? processingAt;
  final DateTime? completedAt;

  /// Raison d'échec brute serveur (pas de timestamp dédié sur `RefundDoc` —
  /// voir note d'en-tête). Null si le refund n'a jamais échoué.
  final String? failedReason;

  const RefundInfo({
    required this.refundId,
    required this.paymentId,
    required this.missionId,
    required this.amountMinor,
    required this.reason,
    required this.initiatedByUserId,
    required this.initiatedByRole,
    required this.isAdminInitiated,
    required this.isPostPayout,
    this.relatedPayoutId,
    required this.status,
    this.providerRefundId,
    required this.reverseTransfer,
    required this.refundApplicationFee,
    required this.createdAt,
    this.processingAt,
    this.completedAt,
    this.failedReason,
  });

  bool get isSucceeded => status == RefundStatus.succeeded;
  bool get isFailed => status == RefundStatus.failed;
  bool get isInProgress => status == RefundStatus.requested || status == RefundStatus.processing;

  /// Date la plus pertinente à afficher pour ce refund : la date de
  /// complétion si disponible, sinon la date de création (jamais de
  /// recalcul, uniquement un choix d'affichage parmi des dates serveur).
  DateTime get displayDate => completedAt ?? createdAt;

  Map<String, dynamic> toJson() => {
        'refund_id': refundId,
        'payment_id': paymentId,
        'mission_id': missionId,
        'amount_minor': amountMinor,
        'reason': reason.firestoreValue,
        'initiated_by_user_id': initiatedByUserId,
        'initiated_by_role': initiatedByRole,
        'is_admin_initiated': isAdminInitiated,
        'is_post_payout': isPostPayout,
        'related_payout_id': relatedPayoutId,
        'status': status.firestoreValue,
        'provider_refund_id': providerRefundId,
        'reverse_transfer': reverseTransfer,
        'refund_application_fee': refundApplicationFee,
        'created_at': createdAt.toIso8601String(),
        'processing_at': processingAt?.toIso8601String(),
        'completed_at': completedAt?.toIso8601String(),
        'failed_reason': failedReason,
      };

  factory RefundInfo.fromJson(Map<String, dynamic> json) {
    return RefundInfo(
      refundId: json['refund_id'] as String? ?? '',
      paymentId: json['payment_id'] as String? ?? '',
      missionId: json['mission_id'] as String? ?? '',
      amountMinor: (json['amount_minor'] as num? ?? 0).toInt(),
      reason: RefundReasonX.fromFirestoreValue(json['reason'] as String?),
      initiatedByUserId: json['initiated_by_user_id'] as String? ?? '',
      initiatedByRole: json['initiated_by_role'] as String? ?? '',
      isAdminInitiated: json['is_admin_initiated'] as bool? ?? false,
      isPostPayout: json['is_post_payout'] as bool? ?? false,
      relatedPayoutId: json['related_payout_id'] as String?,
      status: RefundStatusX.fromFirestoreValue(json['status'] as String?),
      providerRefundId: json['provider_refund_id'] as String?,
      reverseTransfer: json['reverse_transfer'] as bool? ?? false,
      refundApplicationFee: json['refund_application_fee'] as bool? ?? false,
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      processingAt: parseFirestoreDate(json['processing_at']),
      completedAt: parseFirestoreDate(json['completed_at']),
      failedReason: json['failed_reason'] as String?,
    );
  }
}
