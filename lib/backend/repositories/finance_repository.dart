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
import '../../finance/models/driver_payout_info.dart';
import '../../finance/models/dispute_info.dart';
import '../../finance/models/reconciliation_report.dart';
import '../../finance/models/tax_configuration.dart';
import '../../finance/models/payout_policy_configuration.dart';
import '../../models/enums.dart';

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
  Stream<MissionFinancialBalance?> watchMissionFinancialBalance(
    String missionId,
  );

  // ---- Bloc K — UI financière chauffeur (Phase 6) ----

  /// Payouts (`driver_payouts/{id}`) appartenant à ce chauffeur, triés du
  /// plus récent au plus ancien. Requête RÉELLEMENT scopée côté serveur
  /// (`.where('driver_id', isEqualTo: driverId)`), jamais un scan complet
  /// de la collection filtré en mémoire. Le Security Rule
  /// `driver_payouts/{payoutId}` ne laisse lire que le propriétaire
  /// (`driver_id == uid()`) ou analyst+.
  Stream<List<DriverPayoutInfo>> watchPayoutsForDriver(String driverId);

  /// `FinancialSnapshot` figés (offer/bonus/pourboire/net déjà calculés
  /// côté serveur à l'acceptation) pour toutes les missions de ce
  /// chauffeur, triés du plus récent au plus ancien. Requête RÉELLEMENT
  /// scopée `.where('driver_id', isEqualTo: driverId)` (index composite
  /// driver_id+created_at déjà présent). Source de vérité pour l'onglet
  /// "Missions" du Bloc K — jamais `DriverCompensationResult` (estimation
  /// locale pré-mission uniquement, voir driver_compensation.dart).
  Stream<List<FinancialSnapshot>> watchFinancialSnapshotsForDriver(
    String driverId,
  );

  // ---- Bloc L — UI admin finance (Phase 6) ----
  //
  // Toutes les méthodes ci-dessous sont des lectures ADMIN-SCOPÉES (rôle
  // analyst/admin/super_admin requis côté Security Rules — voir
  // firestore.rules). Aucune n'effectue de `.get()` non borné : chaque
  // flux est paginé (`limit`) et/ou filtré serveur. Les actions
  // d'écriture sensibles (refund, reverse payout, update tax config,
  // update payout policy, resolve reconciliation, run reconciliation,
  // create ledger adjustment) sont des Cloud Functions callables
  // distinctes (voir méthodes `admin*` en fin d'interface), jamais des
  // écritures Firestore directes.

  /// Paiements les plus récents, optionnellement filtrés par statut.
  /// Requête bornée (`limit`) — jamais un scan complet de `payments`.
  Stream<List<PaymentInfo>> watchPayments({
    PaymentStatus? status,
    int limit = 50,
  });

  /// Remboursements les plus récents, optionnellement filtrés par statut.
  Stream<List<RefundInfo>> watchRefunds({RefundStatus? status, int limit = 50});

  /// Payouts chauffeur — VUE ADMIN (tous chauffeurs), distincte de
  /// `watchPayoutsForDriver` (scopée à un seul chauffeur). Optionnellement
  /// filtrée par statut.
  Stream<List<DriverPayoutInfo>> watchDriverPayouts({
    PayoutStatus? status,
    int limit = 50,
  });

  /// Litiges (`disputes/{id}`) les plus récents, optionnellement filtrés
  /// par statut.
  Stream<List<DisputeInfo>> watchDisputes({
    DisputeStatus? status,
    int limit = 50,
  });

  /// Ledger append-only — VUE ADMIN (toutes missions/parties), distincte
  /// de `watchLedgerEntriesForMission`/`watchDriverEarningsHistory`
  /// (scopées à une mission/un chauffeur).
  Stream<List<LedgerEntry>> watchLedger({int limit = 50});

  /// Rapports de réconciliation (Bloc G) les plus récents.
  Stream<List<ReconciliationReport>> watchReconciliationReports({
    int limit = 20,
  });

  /// Toutes les VERSIONS de configuration fiscale (jamais les alias
  /// `_current` — voir note d'en-tête de `TaxConfiguration`). Volume
  /// intrinsèquement faible (une poignée de juridictions/versions), donc
  /// pas de pagination nécessaire ici.
  Stream<List<TaxConfiguration>> watchTaxConfigurations();

  /// Configuration courante de politique de rétention des versements
  /// (`payout_policy_configs/default`), ou une valeur de repli explicite
  /// (72h) si l'admin n'a encore jamais publié de configuration — voir
  /// `PayoutPolicyConfiguration.bootstrapDefault()`.
  Stream<PayoutPolicyConfiguration> watchPayoutPolicy();

  // ---- Bloc L — Actions admin (Cloud Functions callables uniquement) ----
  //
  // Aucune de ces méthodes n'écrit Firestore directement : chacune
  // délègue à la Cloud Function existante correspondante. Toute erreur
  // serveur (permission-denied, invalid-argument, ...) est propagée telle
  // quelle à l'appelant (l'UI est responsable de l'afficher).

  /// Déclenche `refundPayment`. `amountMinor` omis/0 = remboursement total
  /// du solde restant (comportement serveur, voir `refundPayment.ts`).
  Future<void> adminRefundPayment({
    required String paymentId,
    required RefundReason reason,
    int? amountMinor,
    String? clientRequestId,
  });

  /// Déclenche `reverseDriverPayout`. `reason` est obligatoire côté
  /// serveur (jamais de reversal silencieux).
  Future<void> adminReverseDriverPayout({
    required String payoutId,
    required String reason,
  });

  /// Déclenche `runReconciliationNow` pour la période donnée.
  Future<void> adminRunReconciliationNow({
    required DateTime periodStart,
    required DateTime periodEnd,
  });

  /// Déclenche `resolveReconciliationAnomaly`. `anomalyIndex` doit être
  /// `ReconciliationAnomaly.index` (position dans le tableau embarqué).
  Future<void> adminResolveReconciliationAnomaly({
    required String reportId,
    required int anomalyIndex,
    required ReconciliationAnomalyStatus newStatus,
    required String resolutionNotes,
  });

  /// Déclenche `updateTaxConfiguration`. Crée TOUJOURS une nouvelle
  /// version — n'écrase jamais l'historique fiscal (voir contrat serveur).
  /// `rate` DOIT être fourni explicitement (voir directive Bloc L point 17
  /// — aucune valeur fiscale présumée par l'UI).
  Future<void> adminUpdateTaxConfiguration({
    required String jurisdiction,
    required String taxCode,
    required TaxType taxType,
    required String displayName,
    required double rate,
    required List<String> taxableComponents,
    required DateTime effectiveFrom,
    DateTime? effectiveUntil,
    required bool enabled,
    required String taxRegistrationOwner,
  });

  /// Déclenche `updatePayoutPolicyConfiguration`.
  Future<void> adminUpdatePayoutPolicyConfiguration({
    required int defaultHoldPeriodHours,
    required int newDriverHoldPeriodHours,
    required int riskyDriverHoldPeriodHours,
    String? correlationId,
  });

  /// Déclenche `createLedgerEntry` pour un ajustement financier manuel
  /// (crée une NOUVELLE entrée compensatoire — ne modifie jamais
  /// l'historique existant, voir directive Bloc L point 12).
  Future<void> adminCreateLedgerAdjustment({
    String? missionId,
    String? transactionId,
    required LedgerEntryType type,
    required double amount,
    required LedgerDirection direction,
    required LedgerParty party,
    required String sourceEvent,
    String? referenceId,
    String? reason,
    String? correlationId,
  });

  /// Déclenche `updateDisputeStatus`.
  Future<void> adminUpdateDisputeStatus({
    required String disputeId,
    required DisputeStatus newStatus,
  });
}

class NotConfiguredFinanceRepository implements FinanceRepository {
  const NotConfiguredFinanceRepository();

  @override
  Future<PricingConfig> getActivePricingConfig() async =>
      PricingConfig.unconfigured();

  @override
  Stream<PricingConfig> watchActivePricingConfig() =>
      Stream.value(PricingConfig.unconfigured());

  @override
  Future<FinancialSnapshot?> getFinancialSnapshot(String missionId) async =>
      null;

  @override
  Stream<FinancialSnapshot?> watchFinancialSnapshot(String missionId) =>
      Stream.value(null);

  @override
  Stream<List<LedgerEntry>> watchLedgerEntriesForMission(String missionId) =>
      Stream.value(const []);

  @override
  Stream<List<LedgerEntry>> watchDriverEarningsHistory(String driverId) =>
      Stream.value(const []);

  @override
  Stream<PaymentInfo?> watchPaymentForMission(String missionId) =>
      Stream.value(null);

  @override
  Stream<List<RefundInfo>> watchRefundsForMission(String missionId) =>
      Stream.value(const []);

  @override
  Stream<MissionFinancialBalance?> watchMissionFinancialBalance(
    String missionId,
  ) => Stream.value(null);

  @override
  Stream<List<DriverPayoutInfo>> watchPayoutsForDriver(String driverId) =>
      Stream.value(const []);

  @override
  Stream<List<FinancialSnapshot>> watchFinancialSnapshotsForDriver(
    String driverId,
  ) => Stream.value(const []);

  // ---- Bloc L — UI admin finance (Phase 6) ----

  @override
  Stream<List<PaymentInfo>> watchPayments({
    PaymentStatus? status,
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Stream<List<RefundInfo>> watchRefunds({
    RefundStatus? status,
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Stream<List<DriverPayoutInfo>> watchDriverPayouts({
    PayoutStatus? status,
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Stream<List<DisputeInfo>> watchDisputes({
    DisputeStatus? status,
    int limit = 50,
  }) => Stream.value(const []);

  @override
  Stream<List<LedgerEntry>> watchLedger({int limit = 50}) =>
      Stream.value(const []);

  @override
  Stream<List<ReconciliationReport>> watchReconciliationReports({
    int limit = 20,
  }) => Stream.value(const []);

  @override
  Stream<List<TaxConfiguration>> watchTaxConfigurations() =>
      Stream.value(const []);

  @override
  Stream<PayoutPolicyConfiguration> watchPayoutPolicy() =>
      Stream.value(PayoutPolicyConfiguration.bootstrapDefault());

  @override
  Future<void> adminRefundPayment({
    required String paymentId,
    required RefundReason reason,
    int? amountMinor,
    String? clientRequestId,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminRefundPayment indisponible.',
  );

  @override
  Future<void> adminReverseDriverPayout({
    required String payoutId,
    required String reason,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminReverseDriverPayout indisponible.',
  );

  @override
  Future<void> adminRunReconciliationNow({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminRunReconciliationNow indisponible.',
  );

  @override
  Future<void> adminResolveReconciliationAnomaly({
    required String reportId,
    required int anomalyIndex,
    required ReconciliationAnomalyStatus newStatus,
    required String resolutionNotes,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminResolveReconciliationAnomaly indisponible.',
  );

  @override
  Future<void> adminUpdateTaxConfiguration({
    required String jurisdiction,
    required String taxCode,
    required TaxType taxType,
    required String displayName,
    required double rate,
    required List<String> taxableComponents,
    required DateTime effectiveFrom,
    DateTime? effectiveUntil,
    required bool enabled,
    required String taxRegistrationOwner,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminUpdateTaxConfiguration indisponible.',
  );

  @override
  Future<void> adminUpdatePayoutPolicyConfiguration({
    required int defaultHoldPeriodHours,
    required int newDriverHoldPeriodHours,
    required int riskyDriverHoldPeriodHours,
    String? correlationId,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminUpdatePayoutPolicyConfiguration indisponible.',
  );

  @override
  Future<void> adminCreateLedgerAdjustment({
    String? missionId,
    String? transactionId,
    required LedgerEntryType type,
    required double amount,
    required LedgerDirection direction,
    required LedgerParty party,
    required String sourceEvent,
    String? referenceId,
    String? reason,
    String? correlationId,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminCreateLedgerAdjustment indisponible.',
  );

  @override
  Future<void> adminUpdateDisputeStatus({
    required String disputeId,
    required DisputeStatus newStatus,
  }) async => throw UnsupportedError(
    'Backend non configuré : adminUpdateDisputeStatus indisponible.',
  );
}
