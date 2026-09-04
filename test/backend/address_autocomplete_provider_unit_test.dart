// ---------------------------------------------------------------------------
// Tests unitaires PURS (sans widget) de la couche d'abstraction
// `AddressAutocompleteProvider` (MOVI-K — CORRECTION UX LIVRAISON — ADRESSES
// RÉELLES + AUTOCOMPLETE + GÉOCODAGE).
//
// Couvre :
//   - `NotConfiguredAddressAutocompleteProvider` : lève TOUJOURS
//     `AddressProviderUnavailableException`, ne simule jamais de données
//     (item o — comportement fail-closed par défaut tant qu'aucune clé
//     fournisseur n'est configurée) ;
//   - `AddressBackendLocator` : retombe sur `NotConfiguredAddressAutocompleteProvider`
//     quand aucun override n'est positionné et qu'aucune clé n'est
//     configurée en environnement de test (`String.fromEnvironment` vide en
//     l'absence de `--dart-define=GOOGLE_MAPS_API_KEY`), et respecte le seam
//     de test `autocompleteProviderOverride` quand positionné ;
//   - `ResolvedAddress.line1` : repli sur `formattedAddress` quand le
//     fournisseur ne distingue pas numéro/rue séparément.
// ---------------------------------------------------------------------------

import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/services/address/address_autocomplete_provider.dart';
import 'package:movik_connect/services/address/address_backend_locator.dart';
import 'package:movik_connect/services/address/address_provider_config.dart';
import 'package:movik_connect/services/address/address_suggestion.dart';
import 'package:movik_connect/services/address/not_configured_address_provider.dart';

class _FakeProvider implements AddressAutocompleteProvider {
  const _FakeProvider();
  @override
  Future<List<AddressSuggestion>> searchSuggestions(String query) async => const [];
  @override
  Future<ResolvedAddress> resolvePlace(String placeId) async =>
      const ResolvedAddress(placeId: 'x', formattedAddress: 'x', lat: 0, lng: 0);
}

void main() {
  tearDown(() {
    AddressBackendLocator.autocompleteProviderOverride = null;
  });

  group('NotConfiguredAddressAutocompleteProvider — fail closed', () {
    const provider = NotConfiguredAddressAutocompleteProvider();

    test('searchSuggestions lève systématiquement AddressProviderUnavailableException', () async {
      expect(
        () => provider.searchSuggestions('527 rue Lacasse'),
        throwsA(isA<AddressProviderUnavailableException>()),
      );
    });

    test('resolvePlace lève systématiquement AddressProviderUnavailableException', () async {
      expect(
        () => provider.resolvePlace('un_place_id_quelconque'),
        throwsA(isA<AddressProviderUnavailableException>()),
      );
    });
  });

  group('AddressProviderConfig', () {
    test(
      'isConfigured est false en environnement de test (aucun --dart-define=GOOGLE_MAPS_API_KEY)',
      () {
        expect(AddressProviderConfig.googleMapsApiKey, isEmpty);
        expect(AddressProviderConfig.isConfigured, isFalse);
      },
    );

    test('allowedWebDomains contient bien le domaine de production actuel', () {
      expect(
        AddressProviderConfig.allowedWebDomains,
        contains('https://mecano-mobile-delta.vercel.app/*'),
      );
    });
  });

  group('AddressBackendLocator', () {
    test(
      'sans override et sans clé configurée -> retombe sur NotConfiguredAddressAutocompleteProvider',
      () {
        expect(
          AddressBackendLocator.autocompleteProvider,
          isA<NotConfiguredAddressAutocompleteProvider>(),
        );
      },
    );

    test('avec override positionné -> retourne EXACTEMENT l\'instance injectée', () {
      const fake = _FakeProvider();
      AddressBackendLocator.autocompleteProviderOverride = fake;
      expect(AddressBackendLocator.autocompleteProvider, same(fake));
    });
  });

  group('ResolvedAddress.line1', () {
    test('combine streetNumber + street quand les deux sont fournis', () {
      const resolved = ResolvedAddress(
        placeId: 'p1',
        formattedAddress: '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
        streetNumber: '527',
        street: 'Rue Lacasse',
        lat: 45.7,
        lng: -73.6,
      );
      expect(resolved.line1, '527 Rue Lacasse');
    });

    test('replie sur formattedAddress quand streetNumber/street sont vides', () {
      const resolved = ResolvedAddress(
        placeId: 'p2',
        formattedAddress: '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
        lat: 45.7,
        lng: -73.6,
      );
      expect(resolved.line1, '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada');
    });
  });
}
