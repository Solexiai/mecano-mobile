// ---------------------------------------------------------------------------
// PayoutDisplayStatus — couche de présentation pour PayoutStatus (Bloc K
// point 5). Contrairement à PaymentDisplayStatus, `PayoutStatus` a déjà un
// nombre restreint et pleinement compréhensible de valeurs côté serveur
// (8 statuts), donc ce mapping est 1:1 — il existe surtout pour séparer la
// clé i18n affichée du nom d'enum interne (cohérence architecturale avec
// Bloc J, et compatibilité future Bloc M).
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

extension PayoutStatusDisplayX on PayoutStatus {
  String get i18nKey {
    switch (this) {
      case PayoutStatus.pending:
        return 'payout_status_pending';
      case PayoutStatus.held:
        return 'payout_status_held';
      case PayoutStatus.eligible:
        return 'payout_status_eligible';
      case PayoutStatus.scheduled:
        return 'payout_status_scheduled';
      case PayoutStatus.processing:
        return 'payout_status_processing';
      case PayoutStatus.paid:
        return 'payout_status_paid';
      case PayoutStatus.failed:
        return 'payout_status_failed';
      case PayoutStatus.reversed:
        return 'payout_status_reversed';
    }
  }
}
