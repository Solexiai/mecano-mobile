// ---------------------------------------------------------------------------
// Tests unitaires — DisputeInfo (Bloc L)
//
// Couvre : mapping exact des champs Firestore réels (`DisputeDoc`, voir
// functions/src/lib/types.ts), tous les statuts `DisputeStatuses` serveur,
// parsing de timestamps robuste (String ISO8601 ici), exclusion volontaire
// de `provider_metadata` (aucun champ sensible mappé), champs null
// explicites, et rétro-compatibilité avec un document partiellement absent.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/dispute_info.dart';
import 'package:movik_connect/models/enums.dart';

Map<String, dynamic> _fullDisputeJson({String status = 'opened'}) => {
  'dispute_id': 'dispute_001',
  'mission_id': 'mission_001',
  'payment_id': 'payment_001',
  'provider_dispute_id': 'dp_test_123',
  'amount_minor': 8500,
  'currency': 'CAD',
  'reason': 'product_not_received',
  'status': status,
  'evidence_due_at': '2026-09-01T00:00:00.000Z',
  'proof_of_delivery_url': 'https://example.com/pod/mission_001.jpg',
  'created_at': '2026-08-20T10:00:00.000Z',
  'updated_at': '2026-08-21T10:00:00.000Z',
  'resolved_at': null,
  'closed_at': null,
};

void main() {
  group('DisputeInfo.fromJson — mapping exact du schéma DisputeDoc', () {
    test('parse correctement tous les champs (aucun recalcul)', () {
      final dispute = DisputeInfo.fromJson('dispute_001', _fullDisputeJson());

      expect(dispute.disputeId, 'dispute_001');
      expect(dispute.missionId, 'mission_001');
      expect(dispute.paymentId, 'payment_001');
      expect(dispute.providerDisputeId, 'dp_test_123');
      expect(dispute.amountMinor, 8500);
      expect(dispute.currency, 'CAD');
      expect(dispute.reason, 'product_not_received');
      expect(dispute.status, DisputeStatus.opened);
      expect(dispute.evidenceDueAt, DateTime.parse('2026-09-01T00:00:00.000Z'));
      expect(
        dispute.proofOfDeliveryUrl,
        'https://example.com/pod/mission_001.jpg',
      );
      expect(dispute.createdAt, DateTime.parse('2026-08-20T10:00:00.000Z'));
      expect(dispute.updatedAt, DateTime.parse('2026-08-21T10:00:00.000Z'));
      expect(dispute.resolvedAt, isNull);
      expect(dispute.closedAt, isNull);
    });

    test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
      final original = DisputeInfo.fromJson('dispute_001', _fullDisputeJson());
      final roundTripped = DisputeInfo.fromJson(
        'dispute_001',
        original.toJson(),
      );

      expect(roundTripped.missionId, original.missionId);
      expect(roundTripped.paymentId, original.paymentId);
      expect(roundTripped.amountMinor, original.amountMinor);
      expect(roundTripped.status, original.status);
      expect(roundTripped.reason, original.reason);
      expect(roundTripped.evidenceDueAt, original.evidenceDueAt);
    });

    test(
      'chaque valeur DisputeStatuses serveur est reconnue individuellement',
      () {
        const serverValues = [
          'opened',
          'under_review',
          'won',
          'lost',
          'reversed',
          'closed',
        ];
        const expectedEnums = [
          DisputeStatus.opened,
          DisputeStatus.underReview,
          DisputeStatus.won,
          DisputeStatus.lost,
          DisputeStatus.reversed,
          DisputeStatus.closed,
        ];

        for (var i = 0; i < serverValues.length; i++) {
          final dispute = DisputeInfo.fromJson(
            'dispute_x',
            _fullDisputeJson(status: serverValues[i]),
          );
          expect(
            dispute.status,
            expectedEnums[i],
            reason: 'status serveur "${serverValues[i]}"',
          );
        }
      },
    );

    test(
      'provider_metadata (données sensibles) n\'est jamais exposé même si présent dans le JSON source',
      () {
        final json = _fullDisputeJson();
        json['provider_metadata'] = {
          'stripe_secret': 'sk_live_should_never_appear',
          'raw_payload': {'cvc': '123'},
        };
        final dispute = DisputeInfo.fromJson('dispute_001', json);
        final serialized = dispute.toJson();

        expect(serialized.containsKey('provider_metadata'), isFalse);
        expect(serialized.toString().contains('sk_live'), isFalse);
        expect(serialized.toString().contains('cvc'), isFalse);
      },
    );
  });

  group('DisputeInfo — getters dérivés de statut', () {
    test('isOpen est vrai pour opened et underReview, non terminal', () {
      final opened = DisputeInfo.fromJson(
        'd',
        _fullDisputeJson(status: 'opened'),
      );
      final underReview = DisputeInfo.fromJson(
        'd',
        _fullDisputeJson(status: 'under_review'),
      );
      expect(opened.isOpen, isTrue);
      expect(opened.isTerminal, isFalse);
      expect(underReview.isOpen, isTrue);
      expect(underReview.isTerminal, isFalse);
    });

    test('won / lost / reversed / closed sont détectés et terminaux', () {
      final won = DisputeInfo.fromJson('d', _fullDisputeJson(status: 'won'));
      final lost = DisputeInfo.fromJson('d', _fullDisputeJson(status: 'lost'));
      final reversed = DisputeInfo.fromJson(
        'd',
        _fullDisputeJson(status: 'reversed'),
      );
      final closed = DisputeInfo.fromJson(
        'd',
        _fullDisputeJson(status: 'closed'),
      );

      expect(won.isWon, isTrue);
      expect(won.isTerminal, isTrue);
      expect(lost.isLost, isTrue);
      expect(lost.isTerminal, isTrue);
      expect(reversed.isReversed, isTrue);
      expect(reversed.isTerminal, isTrue);
      expect(closed.isClosed, isTrue);
      expect(closed.isTerminal, isTrue);
    });
  });

  group('DisputeInfo.fromJson — rétro-compatibilité (champs absents)', () {
    test('un document minimal (seulement mission_id) ne plante pas', () {
      final dispute = DisputeInfo.fromJson('dispute_old', const {
        'mission_id': 'mission_001',
      });

      expect(dispute.disputeId, 'dispute_old');
      expect(dispute.missionId, 'mission_001');
      expect(dispute.paymentId, '');
      expect(dispute.providerDisputeId, '');
      expect(dispute.amountMinor, 0);
      expect(dispute.currency, 'CAD');
      expect(dispute.reason, '');
      // repli sûr sur le statut le plus prudent (opened) — jamais de
      // crash sur un statut inconnu/absent.
      expect(dispute.status, DisputeStatus.opened);
      expect(dispute.evidenceDueAt, isNull);
      expect(dispute.proofOfDeliveryUrl, isNull);
      expect(dispute.resolvedAt, isNull);
      expect(dispute.closedAt, isNull);
    });

    test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
      final dispute = DisputeInfo.fromJson('dispute_fallback', const {});
      expect(dispute.disputeId, 'dispute_fallback');
      expect(dispute.missionId, '');
      expect(dispute.amountMinor, 0);
      expect(dispute.status, DisputeStatus.opened);
    });
  });
}
