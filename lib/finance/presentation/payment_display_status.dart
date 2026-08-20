// ---------------------------------------------------------------------------
// PaymentDisplayStatus — couche de PRÉSENTATION (Bloc J point 9).
//
// Regroupe la machine d'état interne complète `PaymentStatus` (13 valeurs,
// voir lib/models/enums.dart) + le contexte `RefundInfo` associé en un
// nombre réduit de statuts COMPRÉHENSIBLES pour un client :
//   pending | authorized | confirmed | failed | partiallyRefunded | refunded
//
// Chaque valeur expose une clé i18n dédiée (`finance_status_*`, voir
// lib/l10n/app_strings.dart) — AUCUN texte n'est jamais hardcodé ici, ce
// qui rend ce mapping compatible avec le futur Bloc M (i18n) sans aucune
// dépendance à la machine d'état serveur complète.
//
// RÈGLE : ce fichier ne fait AUCUN calcul financier, il ne fait que classer
// un `PaymentStatus` + un indicateur "a des refunds" en une catégorie
// d'affichage.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

enum PaymentDisplayStatus {
  pending,
  authorized,
  confirmed,
  failed,
  partiallyRefunded,
  refunded,
}

extension PaymentDisplayStatusX on PaymentDisplayStatus {
  String get i18nKey {
    switch (this) {
      case PaymentDisplayStatus.pending:
        return 'finance_status_pending';
      case PaymentDisplayStatus.authorized:
        return 'finance_status_authorized';
      case PaymentDisplayStatus.confirmed:
        return 'finance_status_confirmed';
      case PaymentDisplayStatus.failed:
        return 'finance_status_failed';
      case PaymentDisplayStatus.partiallyRefunded:
        return 'finance_status_partially_refunded';
      case PaymentDisplayStatus.refunded:
        return 'finance_status_refunded';
    }
  }

  /// Détermine le statut d'affichage client à partir du `PaymentStatus`
  /// interne. `hasSucceededRefund` permet de refléter un remboursement
  /// même si `PaymentStatus` lui-même n'a pas encore été mis à jour à
  /// `refunded`/`partiallyRefunded` par le serveur (léger délai possible
  /// entre écriture de `refunds/{id}` et mise à jour de `payments/{id}`).
  static PaymentDisplayStatus fromPaymentStatus(
    PaymentStatus status, {
    bool hasSucceededRefund = false,
    bool isFullyRefundedAmount = false,
  }) {
    switch (status) {
      case PaymentStatus.refunded:
        return PaymentDisplayStatus.refunded;
      case PaymentStatus.partiallyRefunded:
        return PaymentDisplayStatus.partiallyRefunded;
      case PaymentStatus.disputed:
      case PaymentStatus.chargeback:
      case PaymentStatus.failed:
      case PaymentStatus.cancelled:
        return PaymentDisplayStatus.failed;
      case PaymentStatus.captured:
        if (hasSucceededRefund) {
          return isFullyRefundedAmount
              ? PaymentDisplayStatus.refunded
              : PaymentDisplayStatus.partiallyRefunded;
        }
        return PaymentDisplayStatus.confirmed;
      case PaymentStatus.authorized:
      case PaymentStatus.capturePending:
        return PaymentDisplayStatus.authorized;
      case PaymentStatus.created:
      case PaymentStatus.requiresPaymentMethod:
      case PaymentStatus.authorizationPending:
      case PaymentStatus.pending:
        return PaymentDisplayStatus.pending;
    }
  }
}
