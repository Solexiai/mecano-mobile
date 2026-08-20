// ---------------------------------------------------------------------------
// Tests unitaires — ReconciliationAnomaly & ReconciliationReport (Bloc L)
//
// Couvre : mapping exact des champs Firestore réels (`ReconciliationReportDoc`
// / `ReconciliationAnomaly`, voir functions/src/lib/types.ts), l'index
// dérivé de la position dans le tableau `anomalies` (jamais un champ
// Firestore natif), tous les statuts/sévérités serveur, compteurs dérivés
// du rapport, parsing de timestamps robuste, et rétro-compatibilité avec un
// document partiellement absent ou un tableau `anomalies` malformé.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/reconciliation_report.dart';
import 'package:movik_connect/models/enums.dart';

Map<String, dynamic> _anomalyJson({
  String severity = 'critical',
  String status = 'open',
}) => {
  'severity': severity,
  'type': 'amount_mismatch',
  'mission_id': 'mission_001',
  'payment_id': 'payment_001',
  'payout_id': null,
  'refund_id': null,
  'expected_amount_minor': 5000,
  'actual_amount_minor': 4500,
  'description': 'Montant du paiement ne correspond pas au ledger',
  'detected_at': '2026-08-20T10:00:00.000Z',
  'status': status,
  'resolution_notes': null,
};

Map<String, dynamic> _fullReportJson({List<Map<String, dynamic>>? anomalies}) =>
    {
      'report_id': 'report_001',
      'period_start': '2026-08-19T00:00:00.000Z',
      'period_end': '2026-08-20T00:00:00.000Z',
      'status': 'anomaly',
      'anomalies': anomalies ?? [_anomalyJson()],
      'total_payments_checked': 120,
      'total_payouts_checked': 45,
      'total_refunds_checked': 8,
      'reconciliation_difference_minor': 500,
      'created_at': '2026-08-20T11:00:00.000Z',
      'last_reconciled_at': '2026-08-20T11:05:00.000Z',
    };

void main() {
  group('ReconciliationAnomaly.fromJson — mapping exact du schéma', () {
    test('parse correctement tous les champs (index dérivé fourni)', () {
      final anomaly = ReconciliationAnomaly.fromJson(2, _anomalyJson());

      expect(anomaly.index, 2);
      expect(anomaly.severity, ReconciliationAnomalySeverity.critical);
      expect(anomaly.type, 'amount_mismatch');
      expect(anomaly.missionId, 'mission_001');
      expect(anomaly.paymentId, 'payment_001');
      expect(anomaly.payoutId, isNull);
      expect(anomaly.refundId, isNull);
      expect(anomaly.expectedAmountMinor, 5000);
      expect(anomaly.actualAmountMinor, 4500);
      expect(
        anomaly.description,
        'Montant du paiement ne correspond pas au ledger',
      );
      expect(anomaly.detectedAt, DateTime.parse('2026-08-20T10:00:00.000Z'));
      expect(anomaly.status, ReconciliationAnomalyStatus.open);
      expect(anomaly.resolutionNotes, isNull);
    });

    test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
      final original = ReconciliationAnomaly.fromJson(0, _anomalyJson());
      final roundTripped = ReconciliationAnomaly.fromJson(0, original.toJson());

      expect(roundTripped.severity, original.severity);
      expect(roundTripped.status, original.status);
      expect(roundTripped.expectedAmountMinor, original.expectedAmountMinor);
      expect(roundTripped.actualAmountMinor, original.actualAmountMinor);
      expect(roundTripped.description, original.description);
    });

    test(
      'chaque valeur de sévérité et de statut serveur est reconnue individuellement',
      () {
        const severities = ['info', 'warning', 'critical'];
        const expectedSeverities = [
          ReconciliationAnomalySeverity.info,
          ReconciliationAnomalySeverity.warning,
          ReconciliationAnomalySeverity.critical,
        ];
        for (var i = 0; i < severities.length; i++) {
          final anomaly = ReconciliationAnomaly.fromJson(
            0,
            _anomalyJson(severity: severities[i]),
          );
          expect(
            anomaly.severity,
            expectedSeverities[i],
            reason: 'sévérité serveur "${severities[i]}"',
          );
        }

        const statuses = ['open', 'acknowledged', 'resolved'];
        const expectedStatuses = [
          ReconciliationAnomalyStatus.open,
          ReconciliationAnomalyStatus.acknowledged,
          ReconciliationAnomalyStatus.resolved,
        ];
        for (var i = 0; i < statuses.length; i++) {
          final anomaly = ReconciliationAnomaly.fromJson(
            0,
            _anomalyJson(status: statuses[i]),
          );
          expect(
            anomaly.status,
            expectedStatuses[i],
            reason: 'statut serveur "${statuses[i]}"',
          );
        }
      },
    );
  });

  group('ReconciliationAnomaly — getters dérivés', () {
    test('isOpen / isCritical corrects pour une anomalie ouverte critique', () {
      final anomaly = ReconciliationAnomaly.fromJson(
        0,
        _anomalyJson(severity: 'critical', status: 'open'),
      );
      expect(anomaly.isOpen, isTrue);
      expect(anomaly.isCritical, isTrue);
      expect(anomaly.isAcknowledged, isFalse);
      expect(anomaly.isResolved, isFalse);
      expect(anomaly.isWarning, isFalse);
    });

    test(
      'isResolved / isWarning corrects pour une anomalie résolue warning',
      () {
        final anomaly = ReconciliationAnomaly.fromJson(
          0,
          _anomalyJson(severity: 'warning', status: 'resolved'),
        );
        expect(anomaly.isResolved, isTrue);
        expect(anomaly.isWarning, isTrue);
        expect(anomaly.isOpen, isFalse);
        expect(anomaly.isCritical, isFalse);
      },
    );
  });

  group(
    'ReconciliationAnomaly.fromJson — rétro-compatibilité (champs absents)',
    () {
      test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
        final anomaly = ReconciliationAnomaly.fromJson(0, const {});
        expect(anomaly.index, 0);
        expect(anomaly.severity, ReconciliationAnomalySeverity.info);
        expect(anomaly.type, 'unknown');
        expect(anomaly.missionId, isNull);
        expect(anomaly.expectedAmountMinor, isNull);
        expect(anomaly.description, '');
        expect(anomaly.status, ReconciliationAnomalyStatus.open);
        expect(anomaly.resolutionNotes, isNull);
      });
    },
  );

  group(
    'ReconciliationReport.fromJson — mapping exact du schéma ReconciliationReportDoc',
    () {
      test(
        'parse correctement tous les champs et le tableau anomalies imbriqué',
        () {
          final report = ReconciliationReport.fromJson(
            'report_001',
            _fullReportJson(),
          );

          expect(report.reportId, 'report_001');
          expect(
            report.periodStart,
            DateTime.parse('2026-08-19T00:00:00.000Z'),
          );
          expect(report.periodEnd, DateTime.parse('2026-08-20T00:00:00.000Z'));
          expect(report.status, ReconciliationStatus.anomaly);
          expect(report.anomalies, hasLength(1));
          expect(report.anomalies.first.index, 0);
          expect(
            report.anomalies.first.severity,
            ReconciliationAnomalySeverity.critical,
          );
          expect(report.totalPaymentsChecked, 120);
          expect(report.totalPayoutsChecked, 45);
          expect(report.totalRefundsChecked, 8);
          expect(report.reconciliationDifferenceMinor, 500);
          expect(report.createdAt, DateTime.parse('2026-08-20T11:00:00.000Z'));
          expect(
            report.lastReconciledAt,
            DateTime.parse('2026-08-20T11:05:00.000Z'),
          );
        },
      );

      test(
        'index des anomalies dérivé strictement de la position dans le tableau',
        () {
          final report = ReconciliationReport.fromJson(
            'report_001',
            _fullReportJson(
              anomalies: [
                _anomalyJson(severity: 'critical', status: 'open'),
                _anomalyJson(severity: 'warning', status: 'resolved'),
                _anomalyJson(severity: 'info', status: 'acknowledged'),
              ],
            ),
          );

          expect(report.anomalies, hasLength(3));
          expect(report.anomalies[0].index, 0);
          expect(report.anomalies[1].index, 1);
          expect(report.anomalies[2].index, 2);
        },
      );

      test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
        final original = ReconciliationReport.fromJson(
          'report_001',
          _fullReportJson(),
        );
        final roundTripped = ReconciliationReport.fromJson(
          'report_001',
          original.toJson(),
        );

        expect(roundTripped.status, original.status);
        expect(roundTripped.anomalies.length, original.anomalies.length);
        expect(
          roundTripped.reconciliationDifferenceMinor,
          original.reconciliationDifferenceMinor,
        );
      });

      test(
        'chaque valeur ReconciliationStatuses serveur est reconnue individuellement',
        () {
          const serverValues = ['ok', 'anomaly', 'pending'];
          const expectedEnums = [
            ReconciliationStatus.ok,
            ReconciliationStatus.anomaly,
            ReconciliationStatus.pending,
          ];
          for (var i = 0; i < serverValues.length; i++) {
            final json = _fullReportJson();
            json['status'] = serverValues[i];
            final report = ReconciliationReport.fromJson('r', json);
            expect(
              report.status,
              expectedEnums[i],
              reason: 'status serveur "${serverValues[i]}"',
            );
          }
        },
      );
    },
  );

  group('ReconciliationReport — compteurs dérivés', () {
    test(
      'openAnomaliesCount / criticalAnomaliesCount / warningAnomaliesCount / resolvedAnomaliesCount',
      () {
        final report = ReconciliationReport.fromJson(
          'report_001',
          _fullReportJson(
            anomalies: [
              _anomalyJson(severity: 'critical', status: 'open'),
              _anomalyJson(severity: 'warning', status: 'open'),
              _anomalyJson(severity: 'critical', status: 'resolved'),
              _anomalyJson(severity: 'warning', status: 'resolved'),
              _anomalyJson(severity: 'info', status: 'acknowledged'),
            ],
          ),
        );

        expect(report.openAnomaliesCount, 2);
        expect(report.criticalAnomaliesCount, 1); // critical + non résolue
        expect(report.warningAnomaliesCount, 1); // warning + non résolue
        expect(report.resolvedAnomaliesCount, 2);
        expect(report.hasAnomalies, isTrue);
      },
    );

    test('hasAnomalies est faux pour un tableau vide', () {
      final report = ReconciliationReport.fromJson(
        'report_clean',
        _fullReportJson(anomalies: []),
      );
      expect(report.hasAnomalies, isFalse);
      expect(report.openAnomaliesCount, 0);
    });
  });

  group(
    'ReconciliationReport.fromJson — rétro-compatibilité (champs absents)',
    () {
      test('un document minimal (seulement report_id) ne plante pas', () {
        final report = ReconciliationReport.fromJson('report_old', const {});

        expect(report.reportId, 'report_old');
        expect(report.status, ReconciliationStatus.pending);
        expect(report.anomalies, isEmpty);
        expect(report.totalPaymentsChecked, 0);
        expect(report.totalPayoutsChecked, 0);
        expect(report.totalRefundsChecked, 0);
        expect(report.reconciliationDifferenceMinor, 0);
      });

      test(
        'un champ anomalies malformé (non-liste) retombe sur liste vide',
        () {
          final report = ReconciliationReport.fromJson('report_bad', {
            'report_id': 'report_bad',
            'anomalies': 'not_a_list',
          });
          expect(report.anomalies, isEmpty);
        },
      );

      test(
        'des éléments non-Map dans le tableau anomalies sont ignorés sans planter',
        () {
          final report = ReconciliationReport.fromJson('report_mixed', {
            'report_id': 'report_mixed',
            'anomalies': [_anomalyJson(), 'invalid_entry', 42, null],
          });
          expect(report.anomalies, hasLength(1));
        },
      );

      test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
        final report = ReconciliationReport.fromJson(
          'report_fallback',
          const {},
        );
        expect(report.reportId, 'report_fallback');
        expect(report.anomalies, isEmpty);
        expect(report.status, ReconciliationStatus.pending);
      });
    },
  );
}
