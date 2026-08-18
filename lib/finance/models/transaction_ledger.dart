// ---------------------------------------------------------------------------
// Transaction Ledger — modèle de l'entrée comptable append-only.
//
// RÈGLES CRITIQUES :
// - Ce document ne doit être créé QUE côté serveur (Cloud Function
//   `createLedgerEntry()`), jamais depuis Flutter.
// - Une entrée confirmée (`status = confirmed`) n'est JAMAIS modifiée ni
//   supprimée. Toute correction crée une NOUVELLE entrée compensatoire qui
//   référence l'entrée d'origine via `referenceId`.
// - Le frontend a un accès LECTURE SEULEMENT à ce modèle.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';
import '../../backend/models/firestore_date.dart';

class LedgerEntry {
  final String ledgerEntryId;
  final String? missionId;
  final String? transactionId;
  final LedgerEntryType type;
  final double amount;
  final String currency; // ex: 'CAD'
  final LedgerDirection direction;
  final LedgerParty party;
  final DateTime createdAt;

  /// Identifiant de la Cloud Function ou du processus serveur qui a créé
  /// cette entrée (jamais un identifiant client Flutter).
  final String createdBy;

  /// Évènement source ayant déclenché cette écriture (ex:
  /// 'delivery_completed', 'refund_issued', 'manual_correction').
  final String sourceEvent;

  final LedgerEntryStatus status;

  /// Si cette entrée est une correction, référence l'entrée d'origine.
  final String? referenceId;

  const LedgerEntry({
    required this.ledgerEntryId,
    this.missionId,
    this.transactionId,
    required this.type,
    required this.amount,
    this.currency = 'CAD',
    required this.direction,
    required this.party,
    required this.createdAt,
    required this.createdBy,
    required this.sourceEvent,
    required this.status,
    this.referenceId,
  });

  bool get isConfirmed => status == LedgerEntryStatus.confirmed;
  bool get isCompensatingEntry => referenceId != null;

  Map<String, dynamic> toJson() => {
        'ledger_entry_id': ledgerEntryId,
        'mission_id': missionId,
        'transaction_id': transactionId,
        'type': type.name,
        'amount': amount,
        'currency': currency,
        'direction': direction.name,
        'party': party.name,
        'created_at': createdAt.toIso8601String(),
        'created_by': createdBy,
        'source_event': sourceEvent,
        'status': status.name,
        'reference_id': referenceId,
      };

  factory LedgerEntry.fromJson(Map<String, dynamic> json) {
    return LedgerEntry(
      ledgerEntryId: json['ledger_entry_id'] as String,
      missionId: json['mission_id'] as String?,
      transactionId: json['transaction_id'] as String?,
      type: LedgerEntryType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => LedgerEntryType.driverAdjustment,
      ),
      amount: (json['amount'] as num? ?? 0).toDouble(),
      currency: json['currency'] as String? ?? 'CAD',
      direction: LedgerDirection.values.firstWhere(
        (d) => d.name == json['direction'],
        orElse: () => LedgerDirection.credit,
      ),
      party: LedgerParty.values.firstWhere(
        (p) => p.name == json['party'],
        orElse: () => LedgerParty.platform,
      ),
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      createdBy: json['created_by'] as String? ?? 'unknown',
      sourceEvent: json['source_event'] as String? ?? 'unknown',
      status: LedgerEntryStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => LedgerEntryStatus.pending,
      ),
      referenceId: json['reference_id'] as String?,
    );
  }
}
