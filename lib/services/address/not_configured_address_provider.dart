// ---------------------------------------------------------------------------
// NotConfiguredAddressAutocompleteProvider — implémentation FAIL-CLOSED
// utilisée tant qu'aucune clé fournisseur (`AddressProviderConfig
// .isConfigured == false`) n'est disponible.
//
// Symétrique de `NotConfiguredMissionRepository` (Firebase) : ne simule
// JAMAIS de suggestions ni de coordonnées fictives — lève systématiquement
// `AddressProviderUnavailableException`, que l'UI traduit vers le message
// générique "service cartographique indisponible" (jamais un faux succès
// avec des coordonnées inventées).
// ---------------------------------------------------------------------------

import 'address_autocomplete_provider.dart';
import 'address_suggestion.dart';

class NotConfiguredAddressAutocompleteProvider implements AddressAutocompleteProvider {
  const NotConfiguredAddressAutocompleteProvider();

  @override
  Future<List<AddressSuggestion>> searchSuggestions(String query) {
    throw const AddressProviderUnavailableException(
      'searchSuggestions: fournisseur cartographique non configuré (clé absente).',
    );
  }

  @override
  Future<ResolvedAddress> resolvePlace(String placeId) {
    throw const AddressProviderUnavailableException(
      'resolvePlace: fournisseur cartographique non configuré (clé absente).',
    );
  }
}
