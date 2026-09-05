// ---------------------------------------------------------------------------
// MissionAddress — rétrocompatibilité historique (MOVI-K — CORRECTION UX
// LIVRAISON — ADRESSES RÉELLES + AUTOCOMPLETE + GÉOCODAGE, item (f)/(n)).
//
// `formattedAddress`/`placeId` ont été ajoutés en OPTIONNEL (nullable) sur
// `MissionAddress` pour tracer l'adresse formatée réelle et l'identifiant
// fournisseur ayant permis de générer `lat`/`lng`. Ce fichier prouve :
//   - qu'un document HISTORIQUE (créé avant cette extension, donc SANS
//     `formatted_address`/`place_id`) se désérialise toujours sans exception
//     avec `lat`/`lng` corrects et les deux nouveaux champs `null` ;
//   - qu'un document RÉCENT (avec les deux nouveaux champs) round-trip
//     correctement (toJson -> fromJson) ;
//   - qu'aucun consommateur existant (quote engine, GPS, routing, dispatch,
//     distance, ETA) qui ne lit que `lat`/`lng`/`line1`/`city`/`postalCode`
//     n'est impacté par cette extension : ces champs restent inchangés dans
//     leur type et leur position.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/backend/models/mission_address.dart';

void main() {
  group('MissionAddress — rétrocompatibilité champs historiques', () {
    test(
      'document Firestore HISTORIQUE (sans formatted_address/place_id) -> '
      'désérialisation sans exception, nouveaux champs null, anciens champs intacts',
      () {
        final legacyJson = <String, dynamic>{
          'line1': '527 Rue Lacasse',
          'city': 'Terrebonne',
          'postal_code': 'J6W 4Y7',
          'lat': 45.7,
          'lng': -73.6,
          // Volontairement ABSENTS : formatted_address, place_id.
        };

        MissionAddress? address;
        expect(() => address = MissionAddress.fromJson(legacyJson), returnsNormally);

        final a = address!;
        expect(a.line1, '527 Rue Lacasse');
        expect(a.city, 'Terrebonne');
        expect(a.postalCode, 'J6W 4Y7');
        expect(a.lat, 45.7);
        expect(a.lng, -73.6);
        expect(a.formattedAddress, isNull);
        expect(a.placeId, isNull);
      },
    );

    test(
      'document Firestore RÉCENT (avec formatted_address/place_id) -> '
      'round-trip toJson/fromJson complet, rien perdu',
      () {
        const address = MissionAddress(
          line1: '527 Rue Lacasse',
          city: 'Terrebonne',
          postalCode: 'J6W 4Y7',
          lat: 45.7,
          lng: -73.6,
          formattedAddress: '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
          placeId: 'ChIJ_fake_place_id_123',
        );

        final json = address.toJson();
        expect(json['formatted_address'], '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada');
        expect(json['place_id'], 'ChIJ_fake_place_id_123');

        final roundTripped = MissionAddress.fromJson(json);
        expect(roundTripped.line1, address.line1);
        expect(roundTripped.city, address.city);
        expect(roundTripped.postalCode, address.postalCode);
        expect(roundTripped.lat, address.lat);
        expect(roundTripped.lng, address.lng);
        expect(roundTripped.formattedAddress, address.formattedAddress);
        expect(roundTripped.placeId, address.placeId);
      },
    );

    test(
      'toJson() sur une adresse SANS formatted_address/place_id (ex: '
      'construite par un autre chemin de code que AddressAutocompleteField) '
      "-> les clés ne sont PAS présentes du tout (jamais 'formatted_address': null)",
      () {
        const address = MissionAddress(
          line1: '10 rue Simple',
          city: 'Laval',
          postalCode: 'H7X 1Y1',
          lat: 45.6,
          lng: -73.7,
        );

        final json = address.toJson();
        expect(json.containsKey('formatted_address'), isFalse);
        expect(json.containsKey('place_id'), isFalse);
      },
    );

    test(
      'document Firestore complètement vide (Map vide) -> defaults sains, jamais une exception',
      () {
        MissionAddress? address;
        expect(() => address = MissionAddress.fromJson(const {}), returnsNormally);
        final a = address!;
        expect(a.line1, '');
        expect(a.city, '');
        expect(a.postalCode, '');
        expect(a.lat, 0);
        expect(a.lng, 0);
        expect(a.formattedAddress, isNull);
        expect(a.placeId, isNull);
      },
    );
  });
}
