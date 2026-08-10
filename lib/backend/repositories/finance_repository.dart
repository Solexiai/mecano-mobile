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
}
