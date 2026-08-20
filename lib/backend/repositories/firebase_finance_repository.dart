// ---------------------------------------------------------------------------
// FirebaseFinanceRepository — implémentation RÉELLE de FinanceRepository.
// LECTURE SEULE (voir en-tête de finance_repository.dart) : cette classe
// n'écrit JAMAIS dans `financial_snapshots`, `transaction_ledger` ou
// `pricing_versions` — toutes les écritures restent exclusivement du
// ressort des Cloud Functions (acceptDelivery, completeDelivery, recordTip,
// calculateDriverPayout, createLedgerEntry).
//
// DÉCISIONS D'IMPLÉMENTATION :
// - `getActivePricingConfig()`/`watchActivePricingConfig()` : lit d'abord le
//   pointeur `pricing_configs/active` (champ `active_pricing_version`), puis
//   le document `pricing_versions/{version}` correspondant. Aucun index
//   composite requis (lectures par ID direct).
// - `getFinancialSnapshot(missionId)`/`watchFinancialSnapshot(missionId)` :
//   plutôt que d'interroger `financial_snapshots` par `mission_id` (aucun
//   index composite dédié à ce filtre seul dans firestore.indexes.json), on
//   lit d'abord `delivery_requests/{missionId}.active_financial_snapshot_id`
//   (déjà dénormalisé là par acceptDelivery()) puis on récupère directement
//   `financial_snapshots/{id}` par ID — aucune question d'index, lecture en
//   O(1).
// - `watchLedgerEntriesForMission(missionId)` : requête simple
//   `.where('mission_id', isEqualTo: missionId)`, tri par date en mémoire
//   (index mission_id+created_at existe mais on reste cohérent avec la
//   convention "pas de .orderBy()" du reste du projet).
// - `watchDriverEarningsHistory(driverId)` : AUCUN champ driver_id direct
//   n'existe sur `transaction_ledger` (seulement `mission_id` + `party`) et
//   aucun index composite driver-first n'existe pour cette collection. On
//   part donc de `financial_snapshots` (index driver_id+created_at déjà
//   présent) pour obtenir la liste des missions de ce chauffeur, puis on lit
//   pour chacune les entrées `transaction_ledger` (index mission_id+created_at
//   déjà présent) en filtrant `party == 'driver'` en mémoire — ce qui
//   correspond exactement à la règle de sécurité déjà en place sur
//   `transaction_ledger` (isAnalystOrAbove() OR party-matched via lookup
//   mission.driver_id == uid()).
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/enums.dart';
import '../../finance/models/pricing_config.dart';
import '../../finance/models/financial_snapshot.dart';
import '../../finance/models/transaction_ledger.dart';
import '../../finance/models/payment_info.dart';
import '../../finance/models/refund_info.dart';
import '../../finance/models/mission_financial_balance.dart';
import '../../finance/models/driver_payout_info.dart';
import 'finance_repository.dart';

class FirebaseFinanceRepository implements FinanceRepository {
  FirebaseFinanceRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _pricingConfigs =>
      _db.collection('pricing_configs');
  CollectionReference<Map<String, dynamic>> get _pricingVersions =>
      _db.collection('pricing_versions');
  CollectionReference<Map<String, dynamic>> get _missions =>
      _db.collection('delivery_requests');
  CollectionReference<Map<String, dynamic>> get _snapshots =>
      _db.collection('financial_snapshots');
  CollectionReference<Map<String, dynamic>> get _ledger =>
      _db.collection('transaction_ledger');
  CollectionReference<Map<String, dynamic>> get _payments =>
      _db.collection('payments');
  CollectionReference<Map<String, dynamic>> get _refunds =>
      _db.collection('refunds');
  CollectionReference<Map<String, dynamic>> get _missionFinancialBalance =>
      _db.collection('mission_financial_balance');
  CollectionReference<Map<String, dynamic>> get _driverPayouts =>
      _db.collection('driver_payouts');

  Future<String?> _readActivePricingVersion() async {
    final snap = await _pricingConfigs.doc('active').get();
    if (!snap.exists || snap.data() == null) return null;
    return snap.data()!['active_pricing_version'] as String?;
  }

  @override
  Future<PricingConfig> getActivePricingConfig() async {
    final version = await _readActivePricingVersion();
    if (version == null) return PricingConfig.unconfigured();
    final versionSnap = await _pricingVersions.doc(version).get();
    if (!versionSnap.exists || versionSnap.data() == null) {
      return PricingConfig.unconfigured();
    }
    return PricingConfig.fromJson(versionSnap.data()!);
  }

  @override
  Stream<PricingConfig> watchActivePricingConfig() {
    // On écoute d'abord le pointeur `pricing_configs/active` : à chaque
    // changement (rare — nouvelle version publiée), on bascule l'écoute sur
    // le document `pricing_versions/{version}` correspondant.
    return _pricingConfigs.doc('active').snapshots().asyncExpand((configSnap) {
      final version = (configSnap.exists && configSnap.data() != null)
          ? configSnap.data()!['active_pricing_version'] as String?
          : null;
      if (version == null) return Stream.value(PricingConfig.unconfigured());
      return _pricingVersions.doc(version).snapshots().map((versionSnap) {
        if (!versionSnap.exists || versionSnap.data() == null) {
          return PricingConfig.unconfigured();
        }
        return PricingConfig.fromJson(versionSnap.data()!);
      });
    });
  }

  Future<String?> _activeSnapshotIdForMission(String missionId) async {
    final missionSnap = await _missions.doc(missionId).get();
    if (!missionSnap.exists || missionSnap.data() == null) return null;
    return missionSnap.data()!['active_financial_snapshot_id'] as String?;
  }

  @override
  Future<FinancialSnapshot?> getFinancialSnapshot(String missionId) async {
    final snapshotId = await _activeSnapshotIdForMission(missionId);
    if (snapshotId == null) return null;
    final snap = await _snapshots.doc(snapshotId).get();
    if (!snap.exists || snap.data() == null) return null;
    return FinancialSnapshot.fromJson(snap.data()!);
  }

  @override
  Stream<FinancialSnapshot?> watchFinancialSnapshot(String missionId) {
    // On écoute la mission pour récupérer/suivre active_financial_snapshot_id
    // (celui-ci peut passer de null à un ID lors de acceptDelivery()), puis
    // on bascule l'écoute sur le snapshot lui-même.
    return _missions.doc(missionId).snapshots().asyncExpand((missionSnap) {
      final snapshotId = (missionSnap.exists && missionSnap.data() != null)
          ? missionSnap.data()!['active_financial_snapshot_id'] as String?
          : null;
      if (snapshotId == null) return Stream.value(null);
      return _snapshots.doc(snapshotId).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return FinancialSnapshot.fromJson(snap.data()!);
      });
    });
  }

  @override
  Stream<List<LedgerEntry>> watchLedgerEntriesForMission(String missionId) {
    return _ledger.where('mission_id', isEqualTo: missionId).snapshots().map((
      snap,
    ) {
      final entries = snap.docs
          .map((d) => LedgerEntry.fromJson(_normalizeLedgerJson(d.data())))
          .toList();
      entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return entries;
    });
  }

  @override
  Stream<List<LedgerEntry>> watchDriverEarningsHistory(String driverId) {
    // Étape 1 : missions financières de ce chauffeur (index driver_id+created_at
    // déjà présent dans firestore.indexes.json).
    return _snapshots
        .where('driver_id', isEqualTo: driverId)
        .snapshots()
        .asyncMap((snapshotsSnap) async {
          final missionIds = snapshotsSnap.docs
              .map((d) => d.data()['mission_id'] as String?)
              .whereType<String>()
              .toSet()
              .toList();
          if (missionIds.isEmpty) return <LedgerEntry>[];

          final entries = <LedgerEntry>[];
          // transaction_ledger n'a pas de champ driver_id direct : on interroge
          // par mission_id (index existant) puis on filtre party=='driver' en
          // mémoire — cohérent avec la règle de sécurité déjà en place.
          for (final missionId in missionIds) {
            final ledgerSnap = await _ledger
                .where('mission_id', isEqualTo: missionId)
                .get();
            for (final d in ledgerSnap.docs) {
              final data = d.data();
              if (data['party'] == LedgerParty.driver.firestoreValue) {
                entries.add(LedgerEntry.fromJson(_normalizeLedgerJson(data)));
              }
            }
          }
          entries.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return entries;
        });
  }

  // -------------------------------------------------------------------
  // Bloc J — UI financière client (Phase 6).
  //
  // Même pattern "pointeur puis lecture directe par ID" que
  // `watchFinancialSnapshot()` ci-dessus : `delivery_requests/{missionId}`
  // porte `active_payment_id` (dénormalisé par createAndAuthorizeMissionPayment,
  // voir payment/paymentOrchestration.ts), on bascule donc l'écoute sur
  // `payments/{id}` par ID direct — aucun index composite requis.
  // -------------------------------------------------------------------

  @override
  Stream<PaymentInfo?> watchPaymentForMission(String missionId) {
    return _missions.doc(missionId).snapshots().asyncExpand((missionSnap) {
      final paymentId = (missionSnap.exists && missionSnap.data() != null)
          ? missionSnap.data()!['active_payment_id'] as String?
          : null;
      if (paymentId == null) return Stream.value(null);
      return _payments.doc(paymentId).snapshots().map((snap) {
        if (!snap.exists || snap.data() == null) return null;
        return PaymentInfo.fromJson(snap.data()!);
      });
    });
  }

  // `refunds/{id}` porte un champ `mission_id` direct (voir RefundDoc) —
  // requête simple `.where('mission_id', isEqualTo: ...)` puis tri en
  // mémoire, cohérent avec `watchLedgerEntriesForMission()` ci-dessus
  // (aucun index composite mission_id+created_at n'existe pour `refunds`
  // dans firestore.indexes.json, donc pas de `.orderBy()` ici non plus).
  @override
  Stream<List<RefundInfo>> watchRefundsForMission(String missionId) {
    return _refunds.where('mission_id', isEqualTo: missionId).snapshots().map((
      snap,
    ) {
      final refunds = snap.docs
          .map((d) => RefundInfo.fromJson(d.data()))
          .toList();
      refunds.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return refunds;
    });
  }

  // `mission_financial_balance/{missionId}` — l'ID de document EST le
  // missionId (voir recalculateMissionFinancialBalance() côté serveur,
  // `db.collection("mission_financial_balance").doc(missionId).set(...)`),
  // donc lecture directe par ID, aucune requête nécessaire.
  @override
  Stream<MissionFinancialBalance?> watchMissionFinancialBalance(
    String missionId,
  ) {
    return _missionFinancialBalance.doc(missionId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return MissionFinancialBalance.fromJson(missionId, snap.data()!);
    });
  }

  // -------------------------------------------------------------------
  // Bloc K — UI financière chauffeur (Phase 6).
  //
  // Requête RÉELLEMENT scopée `.where('driver_id', isEqualTo: driverId)` +
  // `.orderBy('created_at', descending: true)` — l'index composite
  // `driver_payouts` (driver_id ASC, created_at DESC) existe déjà dans
  // firestore.indexes.json, donc ce tri côté serveur est sûr ici
  // (contrairement au reste de ce repository qui évite .orderBy() par
  // absence d'index composite dédié).
  // -------------------------------------------------------------------
  @override
  Stream<List<DriverPayoutInfo>> watchPayoutsForDriver(String driverId) {
    return _driverPayouts
        .where('driver_id', isEqualTo: driverId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DriverPayoutInfo.fromJson(d.id, d.data()))
              .toList(),
        );
  }

  // Même index composite que `watchDriverEarningsHistory()` ci-dessus
  // (driver_id ASC, created_at DESC, déjà présent dans
  // firestore.indexes.json) — tri serveur sûr ici.
  @override
  Stream<List<FinancialSnapshot>> watchFinancialSnapshotsForDriver(
    String driverId,
  ) {
    return _snapshots
        .where('driver_id', isEqualTo: driverId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => FinancialSnapshot.fromJson(d.data()))
              .toList(),
        );
  }

  /// Les Cloud Functions écrivent `type`/`direction`/`party`/`status` en
  /// snake_case (`firestoreValue`, voir functions/src/lib/types.ts) alors
  /// que `LedgerEntry.fromJson()` compare actuellement via `enum.name`
  /// (camelCase, ex: `customerCharge`) — voir transaction_ledger.dart. Ce
  /// mappeur convertit les valeurs snake_case serveur vers les noms d'enum
  /// Dart camelCase attendus par `fromJson()`, pour combler cet écart sans
  /// modifier le modèle partagé.
  Map<String, dynamic> _normalizeLedgerJson(Map<String, dynamic> json) {
    final out = Map<String, dynamic>.from(json);
    if (out['type'] is String) {
      out['type'] = LedgerEntryTypeX.fromFirestoreValue(
        out['type'] as String,
      ).name;
    }
    if (out['direction'] is String) {
      out['direction'] = LedgerDirectionX.fromFirestoreValue(
        out['direction'] as String,
      ).name;
    }
    if (out['party'] is String) {
      out['party'] = LedgerPartyX.fromFirestoreValue(
        out['party'] as String,
      ).name;
    }
    if (out['status'] is String) {
      out['status'] = LedgerEntryStatusX.fromFirestoreValue(
        out['status'] as String,
      ).name;
    }
    final createdAt = out['created_at'];
    if (createdAt is Timestamp) {
      out['created_at'] = createdAt.toDate().toIso8601String();
    }
    return out;
  }
}
