// TECH-04 (rapport pré-lancement 2026-10-27) — les enums Dart doivent
// couvrir toutes les valeurs écrites par les Cloud Functions
// (functions/src/lib/types.ts). Avant ce correctif, `payment_failed` était
// affiché « Brouillon » et sept types de registre « Ajustement chauffeur ».
//
// Ce test est la garde côté app : si le serveur ajoute une valeur, il faut
// l'ajouter ici ET dans l'enum, sinon elle tombera sur `unknown` (visible,
// jamais maquillée).
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/l10n/app_strings.dart';
import 'package:movik_connect/models/enums.dart';

// Copie littérale de `MissionStatuses` (types.ts).
const _serverMissionStatuses = [
  'draft',
  'quoted',
  'searching_driver',
  'offered',
  'assigned',
  'driver_to_pickup',
  'arrived_at_pickup',
  'picked_up',
  'in_transit',
  'arrived_at_dropoff',
  'delivered',
  'completed',
  'cancelled',
  'disputed',
  'refunded',
  'payment_failed',
];

// Copie littérale de `LedgerEntryTypes` (types.ts).
const _serverLedgerTypes = [
  'customer_authorization',
  'customer_charge',
  'customer_service_fee',
  'platform_commission',
  'driver_earning',
  'driver_tip',
  'driver_bonus',
  'tax',
  'payment_processing_fee',
  'payout_processing_fee',
  'insurance_cost',
  'refund',
  'partial_refund',
  'chargeback',
  'chargeback_reversal',
  'chargeback_fee',
  'chargeback_won',
  'chargeback_lost',
  'driver_adjustment',
  'customer_adjustment',
  'driver_payout',
  'driver_payout_reversal',
  'promotion_cost',
];

void main() {
  group('MissionStatus ↔ serveur', () {
    test('chaque statut serveur a une valeur Dart (jamais unknown)', () {
      for (final value in _serverMissionStatuses) {
        final parsed = MissionStatusX.fromFirestoreValue(value);
        expect(parsed, isNot(MissionStatus.unknown), reason: value);
        expect(parsed.firestoreValue, value);
      }
    });

    test('payment_failed est reconnu et libellé dans les 3 langues', () {
      final s = MissionStatusX.fromFirestoreValue('payment_failed');
      expect(s, MissionStatus.paymentFailed);
      for (final locale in const ['fr', 'en', 'es']) {
        final label = AppStrings.t(s.key, locale);
        expect(label, isNotEmpty);
        expect(label, isNot(s.key), reason: '$locale: clé non traduite');
      }
    });

    test('valeur inconnue -> unknown, valeur absente -> draft', () {
      expect(MissionStatusX.fromFirestoreValue('futur_statut'), MissionStatus.unknown);
      expect(MissionStatusX.fromFirestoreValue(null), MissionStatus.draft);
      expect(MissionStatusX.fromFirestoreValue(''), MissionStatus.draft);
    });

    test('tous les statuts Dart ont un libellé FR/EN/ES', () {
      for (final s in MissionStatus.values) {
        for (final locale in const ['fr', 'en', 'es']) {
          expect(AppStrings.t(s.key, locale), isNot(s.key), reason: '${s.name}/$locale');
        }
      }
    });
  });

  group('LedgerEntryType ↔ serveur', () {
    test('chaque type serveur a une valeur Dart (jamais unknown)', () {
      for (final value in _serverLedgerTypes) {
        final parsed = LedgerEntryTypeX.fromFirestoreValue(value);
        expect(parsed, isNot(LedgerEntryType.unknown), reason: value);
        expect(parsed.firestoreValue, value);
      }
    });

    test('valeur inconnue -> unknown, jamais driverAdjustment', () {
      expect(LedgerEntryTypeX.fromFirestoreValue('futur_type'), LedgerEntryType.unknown);
      expect(LedgerEntryTypeX.fromFirestoreValue(null), LedgerEntryType.unknown);
    });
  });
}
