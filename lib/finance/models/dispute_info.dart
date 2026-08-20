// ---------------------------------------------------------------------------
// DisputeInfo — projection LECTURE SEULE du document `disputes/{disputeId}`
// (Cloud Functions, voir `functions/src/lib/types.ts` -> `DisputeDoc`,
// `functions/src/payment/disputeOrchestration.ts`,
// `functions/src/functions/updateDisputeStatus.ts`).
//
// RÈGLES CRITIQUES (Bloc L) :
// - Ce modèle ne fait QUE décrire la forme des données déjà écrites côté
//   serveur (webhook Stripe -> `processStripeWebhook.ts` ->
//   `disputeOrchestration.ts`). Il ne recalcule JAMAIS un montant ou un
//   statut.
// - Montants en UNITÉS MINEURES ENTIÈRES (cents), convention `*_minor`.
// - `provider_metadata` est volontairement EXCLU de ce modèle (voir
//   directive Bloc L point 22 : ne jamais exposer de payload provider brut
//   même à l'admin) — seuls les champs structurés utiles à l'affichage
//   admin sont mappés ici.
// - L'écriture (`updateDisputeStatus`) reste exclusivement une Cloud
//   Function ; ce modèle n'a pas de méthode d'écriture Firestore directe.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class DisputeInfo {
  final String disputeId;
  final String missionId;
  final String paymentId;
  final String providerDisputeId;

  final int amountMinor;
  final String currency;
  final String reason;
  final DisputeStatus status;

  final DateTime? evidenceDueAt;

  /// Dénormalisé depuis la mission (Phase 5) — URL de preuve de livraison,
  /// PAS une donnée sensible provider (voir note d'en-tête).
  final String? proofOfDeliveryUrl;

  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? resolvedAt;
  final DateTime? closedAt;

  const DisputeInfo({
    required this.disputeId,
    required this.missionId,
    required this.paymentId,
    required this.providerDisputeId,
    required this.amountMinor,
    required this.currency,
    required this.reason,
    required this.status,
    this.evidenceDueAt,
    this.proofOfDeliveryUrl,
    required this.createdAt,
    required this.updatedAt,
    this.resolvedAt,
    this.closedAt,
  });

  bool get isOpen =>
      status == DisputeStatus.opened || status == DisputeStatus.underReview;
  bool get isWon => status == DisputeStatus.won;
  bool get isLost => status == DisputeStatus.lost;
  bool get isReversed => status == DisputeStatus.reversed;
  bool get isClosed => status == DisputeStatus.closed;
  bool get isTerminal =>
      status == DisputeStatus.won ||
      status == DisputeStatus.lost ||
      status == DisputeStatus.reversed ||
      status == DisputeStatus.closed;

  Map<String, dynamic> toJson() => {
    'dispute_id': disputeId,
    'mission_id': missionId,
    'payment_id': paymentId,
    'provider_dispute_id': providerDisputeId,
    'amount_minor': amountMinor,
    'currency': currency,
    'reason': reason,
    'status': status.firestoreValue,
    'evidence_due_at': evidenceDueAt?.toIso8601String(),
    'proof_of_delivery_url': proofOfDeliveryUrl,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
    'resolved_at': resolvedAt?.toIso8601String(),
    'closed_at': closedAt?.toIso8601String(),
  };

  /// Parse un document `disputes/{id}` réel. Repli sûr sur chaque champ
  /// numérique/texte, statut inconnu retombe sur `DisputeStatus.opened`
  /// (voir `DisputeStatusX.fromFirestoreValue`) — ne plante jamais sur un
  /// document historique partiel.
  factory DisputeInfo.fromJson(String disputeId, Map<String, dynamic> json) {
    return DisputeInfo(
      disputeId: json['dispute_id'] as String? ?? disputeId,
      missionId: json['mission_id'] as String? ?? '',
      paymentId: json['payment_id'] as String? ?? '',
      providerDisputeId: json['provider_dispute_id'] as String? ?? '',
      amountMinor: (json['amount_minor'] as num? ?? 0).toInt(),
      currency: json['currency'] as String? ?? 'CAD',
      reason: json['reason'] as String? ?? '',
      status: DisputeStatusX.fromFirestoreValue(json['status'] as String?),
      evidenceDueAt: parseFirestoreDate(json['evidence_due_at']),
      proofOfDeliveryUrl: json['proof_of_delivery_url'] as String?,
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
      resolvedAt: parseFirestoreDate(json['resolved_at']),
      closedAt: parseFirestoreDate(json['closed_at']),
    );
  }
}
