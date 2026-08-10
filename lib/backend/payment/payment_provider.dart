// ---------------------------------------------------------------------------
// PaymentProvider — abstraction provider-agnostic pour les paiements.
//
// Aucune décision n'est prise ici sur le fournisseur final (Stripe Connect
// ou autre). Cette interface permet de développer tout le reste de
// l'architecture (missions, snapshots, ledger) sans dépendre d'un choix
// définitif de fournisseur de paiement.
//
// IMPORTANT : TOUTE implémentation réelle de cette interface doit vivre
// côté serveur (Cloud Functions), jamais dans Flutter. Le rôle du Flutter
// côté client se limite à :
//   - initier un paiement via un appel à une Cloud Function callable
//     (qui elle-même appelle le PaymentProvider réel côté serveur), et
//   - afficher un éventuel widget de saisie de carte fourni par le SDK
//     du fournisseur (ex: Stripe Elements/PaymentSheet), sans jamais
//     manipuler les clés secrètes.
// Cette classe abstraite documente le CONTRAT que l'implémentation serveur
// devra respecter ; elle n'est pas destinée à être instanciée depuis
// Flutter avec une vraie clé secrète.
// ---------------------------------------------------------------------------

class PaymentResult {
  final bool success;
  final String? paymentId;
  final String? errorCode;

  const PaymentResult({required this.success, this.paymentId, this.errorCode});
}

class PayoutResult {
  final bool success;
  final String? payoutId;
  final String? errorCode;

  const PayoutResult({required this.success, this.payoutId, this.errorCode});
}

abstract class PaymentProvider {
  /// Crée une intention de paiement pour le client (montant = customerTotal
  /// du FinancialSnapshot). Ne capture pas nécessairement immédiatement les
  /// fonds (peut être une simple autorisation selon le workflow choisi).
  Future<PaymentResult> createCustomerPayment({
    required String customerId,
    required String missionId,
    required double amount,
    required String currency,
  });

  /// Capture définitivement un paiement préalablement autorisé.
  Future<PaymentResult> capturePayment({required String paymentId});

  /// Remboursement total ou partiel.
  Future<PaymentResult> refundPayment({
    required String paymentId,
    required double amount,
  });

  /// Déclenche un versement au chauffeur (driver_total_payout du snapshot
  /// confirmé).
  Future<PayoutResult> createDriverPayout({
    required String driverId,
    required double amount,
    required String currency,
  });

  /// Traite un webhook entrant du fournisseur de paiement (à appeler
  /// depuis une Cloud Function HTTP dédiée, jamais depuis Flutter).
  Future<void> processWebhook(Map<String, dynamic> payload);
}

/// Stub explicite : aucun fournisseur de paiement n'est encore branché.
/// Toute tentative d'utilisation échoue proprement plutôt que de simuler
/// un paiement réel.
class NotConfiguredPaymentProvider implements PaymentProvider {
  const NotConfiguredPaymentProvider();

  @override
  Future<PaymentResult> createCustomerPayment({
    required String customerId,
    required String missionId,
    required double amount,
    required String currency,
  }) async {
    return const PaymentResult(success: false, errorCode: 'payment_provider_not_configured');
  }

  @override
  Future<PaymentResult> capturePayment({required String paymentId}) async {
    return const PaymentResult(success: false, errorCode: 'payment_provider_not_configured');
  }

  @override
  Future<PaymentResult> refundPayment({required String paymentId, required double amount}) async {
    return const PaymentResult(success: false, errorCode: 'payment_provider_not_configured');
  }

  @override
  Future<PayoutResult> createDriverPayout({
    required String driverId,
    required double amount,
    required String currency,
  }) async {
    return const PayoutResult(success: false, errorCode: 'payment_provider_not_configured');
  }

  @override
  Future<void> processWebhook(Map<String, dynamic> payload) async {
    // Aucune action : pas de fournisseur configuré.
  }
}
