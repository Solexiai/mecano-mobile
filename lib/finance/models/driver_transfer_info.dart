// ---------------------------------------------------------------------------
// DriverTransferInfo — projection LECTURE SEULE de `driver_transfers/{paymentId}`
// (option A, 2026-10-27 ; voir `functions/src/lib/types.ts` ->
// `DriverTransferDoc` et `onPaymentWrittenMirrorDriverTransfer.ts`).
//
// À l'encaissement d'une livraison, Stripe Connect vire la part du chauffeur
// (montant encaissé moins frais de plateforme) sur son compte Stripe, puis
// la dépose sur son compte bancaire. Ce document, écrit uniquement par le
// serveur, en est le miroir minimal lisible par le chauffeur propriétaire :
// aucun montant n'est recalculé ici, chaque champ est lu tel quel.
// ---------------------------------------------------------------------------

import '../../backend/models/firestore_date.dart';

enum DriverTransferStatus {
  transferred,
  partiallyReversed,
  reversed;

  String get i18nKey {
    switch (this) {
      case DriverTransferStatus.transferred:
        return 'payout_transfer_status_transferred';
      case DriverTransferStatus.partiallyReversed:
        return 'payout_transfer_status_partially_reversed';
      case DriverTransferStatus.reversed:
        return 'payout_transfer_status_reversed';
    }
  }

  static DriverTransferStatus fromFirestoreValue(String? value) {
    switch (value) {
      case 'reversed':
        return DriverTransferStatus.reversed;
      case 'partially_reversed':
        return DriverTransferStatus.partiallyReversed;
      default:
        return DriverTransferStatus.transferred;
    }
  }
}

class DriverTransferInfo {
  final String paymentId;
  final String missionId;
  final String driverId;
  final String currency;

  /// Viré sur le compte Stripe du chauffeur à l'encaissement (cents).
  final int amountMinor;

  /// Part renversée à la suite d'un remboursement client (cents).
  final int reversedMinor;

  /// `amountMinor - reversedMinor`, calculé par le serveur.
  final int netMinor;
  final DriverTransferStatus status;

  /// `true` : frais de mission (annulation tardive, déplacement inutile)
  /// plutôt qu'une livraison.
  final bool isMissionFee;
  final DateTime? capturedAt;
  final DateTime updatedAt;

  const DriverTransferInfo({
    required this.paymentId,
    required this.missionId,
    required this.driverId,
    required this.currency,
    required this.amountMinor,
    required this.reversedMinor,
    required this.netMinor,
    required this.status,
    this.isMissionFee = false,
    this.capturedAt,
    required this.updatedAt,
  });

  bool get isReversed => status == DriverTransferStatus.reversed;

  Map<String, dynamic> toJson() => {
    'payment_id': paymentId,
    'mission_id': missionId,
    'driver_id': driverId,
    'currency': currency,
    'amount_minor': amountMinor,
    'reversed_minor': reversedMinor,
    'net_minor': netMinor,
    'status': status.name == 'partiallyReversed'
        ? 'partially_reversed'
        : status.name,
    'capture_purpose': isMissionFee ? 'mission_fee' : null,
    'captured_at': capturedAt?.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  /// Un document partiel ne fait jamais planter l'UI.
  factory DriverTransferInfo.fromJson(
    String paymentId,
    Map<String, dynamic> json,
  ) {
    final amount = (json['amount_minor'] as num? ?? 0).toInt();
    final reversed = (json['reversed_minor'] as num? ?? 0).toInt();
    return DriverTransferInfo(
      paymentId: paymentId,
      missionId: json['mission_id'] as String? ?? '',
      driverId: json['driver_id'] as String? ?? '',
      currency: json['currency'] as String? ?? 'CAD',
      amountMinor: amount,
      reversedMinor: reversed,
      netMinor: (json['net_minor'] as num?)?.toInt() ?? (amount - reversed),
      status: DriverTransferStatus.fromFirestoreValue(
        json['status'] as String?,
      ),
      isMissionFee: json['capture_purpose'] == 'mission_fee',
      capturedAt: parseFirestoreDate(json['captured_at']),
      updatedAt: parseFirestoreDate(json['updated_at']) ?? DateTime.now(),
    );
  }
}
