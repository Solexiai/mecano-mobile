// ---------------------------------------------------------------------------
// Tests unitaires — LedgerEntry (append-only, entrées compensatoires)
//
// Couvre (Étape 12) : le pattern "append-only" — une correction ne modifie
// jamais une entrée existante, elle crée une NOUVELLE entrée compensatoire
// qui référence l'entrée d'origine via `referenceId`. Ces modèles Dart sont
// en LECTURE SEULE (aucune logique d'écriture réelle ici — celle-ci vit
// uniquement côté Cloud Function `createLedgerEntry()`), le test vérifie
// donc la sémantique de lecture (isConfirmed / isCompensatingEntry) et la
// cohérence du couple (entrée d'origine, entrée compensatoire).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/transaction_ledger.dart';
import 'package:movik_connect/models/enums.dart';

void main() {
  group('LedgerEntry.isConfirmed / isCompensatingEntry', () {
    test('une entrée standard confirmée sans referenceId n\'est pas une entrée compensatoire', () {
      final entry = LedgerEntry(
        ledgerEntryId: 'ledger_001',
        missionId: 'mission_001',
        type: LedgerEntryType.platformCommission,
        amount: 15,
        direction: LedgerDirection.credit,
        party: LedgerParty.platform,
        createdAt: DateTime(2025, 6, 15),
        createdBy: 'cloud_function:createFinancialSnapshot',
        sourceEvent: 'delivery_completed',
        status: LedgerEntryStatus.confirmed,
      );

      expect(entry.isConfirmed, isTrue);
      expect(entry.isCompensatingEntry, isFalse);
    });

    test('une entrée pending n\'est pas encore confirmée', () {
      final entry = LedgerEntry(
        ledgerEntryId: 'ledger_002',
        type: LedgerEntryType.driverEarning,
        amount: 85,
        direction: LedgerDirection.credit,
        party: LedgerParty.driver,
        createdAt: DateTime(2025, 6, 15),
        createdBy: 'cloud_function:createFinancialSnapshot',
        sourceEvent: 'delivery_completed',
        status: LedgerEntryStatus.pending,
      );

      expect(entry.isConfirmed, isFalse);
    });

    test('une entrée compensatoire référence bien l\'entrée d\'origine via referenceId', () {
      final original = LedgerEntry(
        ledgerEntryId: 'ledger_003',
        missionId: 'mission_002',
        type: LedgerEntryType.driverEarning,
        amount: 85,
        direction: LedgerDirection.credit,
        party: LedgerParty.driver,
        createdAt: DateTime(2025, 6, 15, 10, 0, 0),
        createdBy: 'cloud_function:createFinancialSnapshot',
        sourceEvent: 'delivery_completed',
        status: LedgerEntryStatus.confirmed,
      );

      // Correction : le montant original était erroné, une entrée
      // compensatoire est créée pour ANNULER l'effet (jamais de
      // modification/suppression de `original`).
      final compensating = LedgerEntry(
        ledgerEntryId: 'ledger_004',
        missionId: original.missionId,
        type: original.type,
        amount: -85, // annule intégralement le montant original
        direction: LedgerDirection.debit,
        party: LedgerParty.driver,
        createdAt: DateTime(2025, 6, 15, 11, 0, 0),
        createdBy: 'cloud_function:reverseLedgerEntry',
        sourceEvent: 'manual_correction',
        status: LedgerEntryStatus.confirmed,
        referenceId: original.ledgerEntryId,
      );

      expect(original.isCompensatingEntry, isFalse);
      expect(compensating.isCompensatingEntry, isTrue);
      expect(compensating.referenceId, original.ledgerEntryId);
      // Les deux entrées coexistent (append-only) : le solde net se calcule
      // en additionnant les deux, jamais en réécrivant `original`.
      expect(original.amount + compensating.amount, closeTo(0.0, 1e-9));

      // L'entrée d'origine reste totalement inchangée (aucune mutation
      // possible : tous les champs sont `final`, ceci confirme simplement
      // que la référence retourne toujours les valeurs d'origine).
      expect(original.amount, 85);
      expect(original.status, LedgerEntryStatus.confirmed);
    });

    test('round-trip toJson/fromJson préserve le referenceId d\'une entrée compensatoire', () {
      final compensating = LedgerEntry(
        ledgerEntryId: 'ledger_005',
        type: LedgerEntryType.refund,
        amount: -20,
        direction: LedgerDirection.debit,
        party: LedgerParty.customer,
        createdAt: DateTime(2025, 6, 15),
        createdBy: 'cloud_function:reverseLedgerEntry',
        sourceEvent: 'refund_issued',
        status: LedgerEntryStatus.confirmed,
        referenceId: 'ledger_original_xyz',
      );

      final roundTripped = LedgerEntry.fromJson(compensating.toJson());

      expect(roundTripped.isCompensatingEntry, isTrue);
      expect(roundTripped.referenceId, 'ledger_original_xyz');
      expect(roundTripped.amount, closeTo(-20.0, 1e-9));
      expect(roundTripped.type, LedgerEntryType.refund);
    });
  });
}
