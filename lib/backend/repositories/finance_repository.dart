// ---------------------------------------------------------------------------
// FinanceRepository — accès LECTURE SEULEMENT aux données financières
// confirmées (snapshots, ledger, pricing config active).
//
// RÈGLE ABSOLUE : cette interface n'expose AUCUNE méthode d'écriture pour
// FinancialSnapshot ou LedgerEntry. Ces documents ne sont créés QUE par des
// Cloud Functions (createFinancialSnapshot, createLedgerEntry,
// calculateDriverPayout, recordTip, processRefund). Si un jour un besoin
// d'écriture apparaît côté client, cela doit rester un appel à une Cloud
// Function (callable), jamais un accès Firestore direct.
// ---------------------------------------------------------------------------

import '../../finance/models/pricing_config.dart';
import '../../finance/models/financial_snapshot.dart';
import '../../finance/models/transaction_ledger.dart';
import '../../finance/models/payment_info.dart';
import '../../finance/models/refund_info.dart';
import '../../finance/models/mission_financial_balance.dart';

abstract class FinanceRepository {
  /// Configuration de pricing active (dernière pricing_version publiée).
  Future<PricingConfig> getActivePricingConfig();

  Stream<PricingConfig> watchActivePricingConfig();

  Future<FinancialSnapshot?> getFinancialSnapshot(String missionId);

  Stream<FinancialSnapshot?> watchFinancialSnapshot(String missionId);

  /// Entrées de ledger visibles par l'utilisateur courant pour une mission
  /// donnée (le serveur filtre déjà selon les Security Rules).
  Stream<List<LedgerEntry>> watchLedgerEntriesForMission(String missionId);

  /// Historique de gains d'un chauffeur (lecture seule, déjà filtré
  /// côté serveur pour ne montrer que ses propres entrées).
  Stream<List<LedgerEntry>> watchDriverEarningsHistory(String driverId);

  // ---- Bloc J — UI financière client (Phase 6) ----

  /// Paiement RÉEL (`payments/{id}`) rattaché à cette mission, ou `null` si
  /// aucun paiement n'a encore été créé pour cette mission (ancienne
  /// mission pré-Phase 6, ou mission jamais acceptée). Le Security Rule
  /// `payments/{paymentId}` ne laisse lire que le propriétaire
  /// (`customer_id == uid()`) ou analyst+ — cette méthode ne fait
  /// qu'exposer un flux déjà scopé par le serveur.
  Stream<PaymentInfo?> watchPaymentForMission(String missionId);

  /// Remboursements (`refunds/{id}`) rattachés à cette mission, triés du
  /// plus récent au plus ancien (tri en mémoire, pas de `.orderBy()` pour
  /// rester cohérent avec les autres méthodes de ce repository).
  Stream<List<RefundInfo>> watchRefundsForMission(String missionId);

  /// Solde financier synthétique (`mission_financial_balance/{missionId}`)
  /// de cette mission, ou `null` si le document n'a pas encore été calculé
  /// (mission trop ancienne, ou pas encore de mouvement financier).
  Stream<MissionFinancialBalance?> watchMissionFinancialBalance(String missionId);
}

class NotConfiguredFinanceRepository implements FinanceRepository {
  const NotConfiguredFinanceRepository();

  @override
  Future<PricingConfig> getActivePricingConfig() async => PricingConfig.unconfigured();

  @override
  Stream<PricingConfig> watchActivePricingConfig() =>
      Stream.value(PricingConfig.unconfigured());

  @override
  Future<FinancialSnapshot?> getFinancialSnapshot(String missionId) async => null;

  @override
  Stream<FinancialSnapshot?> watchFinancialSnapshot(String missionId) => Stream.value(null);

  @override
  Stream<List<LedgerEntry>> watchLedgerEntriesForMission(String missionId) =>
      Stream.value(const []);

  @override
  Stream<List<LedgerEntry>> watchDriverEarningsHistory(String driverId) =>
      Stream.value(const []);

  @override
  Stream<PaymentInfo?> watchPaymentForMission(String missionId) => Stream.value(null);

  @override
  Stream<List<RefundInfo>> watchRefundsForMission(String missionId) => Stream.value(const []);

  @override
  Stream<MissionFinancialBalance?> watchMissionFinancialBalance(String missionId) =>
      Stream.value(null);
}
