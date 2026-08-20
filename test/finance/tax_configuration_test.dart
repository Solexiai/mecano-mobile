// ---------------------------------------------------------------------------
// Tests unitaires — TaxConfiguration (Bloc L)
//
// Couvre : mapping exact des champs Firestore réels (`TaxConfigDoc`, voir
// functions/src/lib/types.ts), tous les `TaxTypes` serveur, taux exprimé en
// fraction (aucun recalcul/pourcentage présumé), `isOpenEnded`, parsing de
// timestamps robuste, et rétro-compatibilité avec un document partiellement
// absent. Ce modèle ne mappe QUE les documents de version réels (pas les
// alias `is_alias: true`) — voir note d'en-tête du modèle ; ce filtrage est
// une responsabilité du repository et n'est pas testé ici (test de modèle
// pur).
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/finance/models/tax_configuration.dart';
import 'package:movik_connect/models/enums.dart';

Map<String, dynamic> _fullTaxConfigJson({
  String taxType = 'gst',
  String? effectiveUntil,
}) => {
  'jurisdiction': 'CA-QC',
  'tax_code': 'gst',
  'tax_type': taxType,
  'display_name': 'TPS',
  'rate': 0.05,
  'taxable_components': ['transport_fee', 'service_fee'],
  'applies_to_transport': true,
  'applies_to_platform_fees': false,
  'effective_from': '2026-01-01T00:00:00.000Z',
  'effective_until': effectiveUntil,
  'enabled': true,
  'version': 3,
  'is_active': true,
  'tax_registration_owner': 'platform',
  'created_at': '2026-01-01T00:00:00.000Z',
  'updated_at': '2026-01-15T00:00:00.000Z',
  'updated_by_user_id': 'admin_user_001',
};

void main() {
  group('TaxConfiguration.fromJson — mapping exact du schéma TaxConfigDoc', () {
    test(
      'parse correctement tous les champs (aucune valeur fiscale présumée)',
      () {
        final config = TaxConfiguration.fromJson(
          'CA-QC_gst_v3',
          _fullTaxConfigJson(),
        );

        expect(config.docId, 'CA-QC_gst_v3');
        expect(config.jurisdiction, 'CA-QC');
        expect(config.taxCode, 'gst');
        expect(config.taxType, TaxType.gst);
        expect(config.displayName, 'TPS');
        expect(config.rate, 0.05);
        expect(config.taxableComponents, ['transport_fee', 'service_fee']);
        expect(config.appliesToTransport, isTrue);
        expect(config.appliesToPlatformFees, isFalse);
        expect(
          config.effectiveFrom,
          DateTime.parse('2026-01-01T00:00:00.000Z'),
        );
        expect(config.effectiveUntil, isNull);
        expect(config.enabled, isTrue);
        expect(config.version, 3);
        expect(config.isActive, isTrue);
        expect(config.taxRegistrationOwner, 'platform');
        expect(config.createdAt, DateTime.parse('2026-01-01T00:00:00.000Z'));
        expect(config.updatedAt, DateTime.parse('2026-01-15T00:00:00.000Z'));
        expect(config.updatedByUserId, 'admin_user_001');
      },
    );

    test('round-trip toJson()/fromJson() préserve les champs essentiels', () {
      final original = TaxConfiguration.fromJson(
        'CA-QC_gst_v3',
        _fullTaxConfigJson(),
      );
      final roundTripped = TaxConfiguration.fromJson(
        'CA-QC_gst_v3',
        original.toJson(),
      );

      expect(roundTripped.taxType, original.taxType);
      expect(roundTripped.rate, original.rate);
      expect(roundTripped.taxableComponents, original.taxableComponents);
      expect(roundTripped.version, original.version);
      expect(roundTripped.taxRegistrationOwner, original.taxRegistrationOwner);
    });

    test('chaque valeur TaxTypes serveur est reconnue individuellement', () {
      const serverValues = ['gst', 'qst', 'hst', 'other_tax', 'tax_exempt'];
      const expectedEnums = [
        TaxType.gst,
        TaxType.qst,
        TaxType.hst,
        TaxType.otherTax,
        TaxType.taxExempt,
      ];

      for (var i = 0; i < serverValues.length; i++) {
        final config = TaxConfiguration.fromJson(
          'doc_x',
          _fullTaxConfigJson(taxType: serverValues[i]),
        );
        expect(
          config.taxType,
          expectedEnums[i],
          reason: 'tax_type serveur "${serverValues[i]}"',
        );
      }
    });

    test('effective_until présent est correctement parsé (fenêtre fermée)', () {
      final config = TaxConfiguration.fromJson(
        'doc_closed',
        _fullTaxConfigJson(effectiveUntil: '2026-12-31T23:59:59.000Z'),
      );
      expect(config.effectiveUntil, DateTime.parse('2026-12-31T23:59:59.000Z'));
    });
  });

  group('TaxConfiguration — getters dérivés', () {
    test('isOpenEnded est vrai quand effective_until est null', () {
      final config = TaxConfiguration.fromJson(
        'doc',
        _fullTaxConfigJson(effectiveUntil: null),
      );
      expect(config.isOpenEnded, isTrue);
    });

    test('isOpenEnded est faux quand effective_until est fourni', () {
      final config = TaxConfiguration.fromJson(
        'doc',
        _fullTaxConfigJson(effectiveUntil: '2026-12-31T23:59:59.000Z'),
      );
      expect(config.isOpenEnded, isFalse);
    });
  });

  group('TaxConfiguration.fromJson — rétro-compatibilité (champs absents)', () {
    test('un document minimal (seulement jurisdiction) ne plante pas', () {
      final config = TaxConfiguration.fromJson('doc_old', const {
        'jurisdiction': 'CA-QC',
      });

      expect(config.docId, 'doc_old');
      expect(config.jurisdiction, 'CA-QC');
      expect(config.taxCode, '');
      // repli sûr : type de taxe le plus neutre (otherTax) — jamais de
      // crash sur un tax_type inconnu/absent, et jamais de présomption
      // GST/QST par défaut (directive Bloc L point 17).
      expect(config.taxType, TaxType.otherTax);
      expect(config.displayName, '');
      expect(config.rate, 0.0);
      expect(config.taxableComponents, isEmpty);
      expect(config.appliesToTransport, isFalse);
      expect(config.appliesToPlatformFees, isFalse);
      expect(config.enabled, isFalse);
      expect(config.version, 1);
      expect(config.isActive, isFalse);
      expect(config.taxRegistrationOwner, 'not_applicable');
      expect(config.updatedByUserId, '');
    });

    test('taxable_components malformé (non-liste) retombe sur liste vide', () {
      final json = _fullTaxConfigJson();
      json['taxable_components'] = 'not_a_list';
      final config = TaxConfiguration.fromJson('doc_bad', json);
      expect(config.taxableComponents, isEmpty);
    });

    test('un JSON totalement vide ne plante jamais (fail-safe absolu)', () {
      final config = TaxConfiguration.fromJson('doc_fallback', const {});
      expect(config.docId, 'doc_fallback');
      expect(config.jurisdiction, '');
      expect(config.rate, 0.0);
      expect(config.taxType, TaxType.otherTax);
      expect(config.enabled, isFalse);
    });
  });
}
