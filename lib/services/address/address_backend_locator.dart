// ---------------------------------------------------------------------------
// AddressBackendLocator — fournit l'implémentation d'
// `AddressAutocompleteProvider` à utiliser dans toute l'application.
//
// Suit EXACTEMENT le même pattern que `BackendLocator` (voir
// lib/backend/backend_locator.dart) :
//   - tant qu'aucune clé fournisseur n'est configurée
//     (`AddressProviderConfig.isConfigured == false`), retourne
//     `NotConfiguredAddressAutocompleteProvider` (fail closed, jamais de
//     données simulées) ;
//   - `autocompleteProviderOverride` est un seam de test `@visibleForTesting`
//     permettant d'injecter un `FakeAddressAutocompleteProvider`
//     déterministe (suggestions/coordonnées connues) sans dépendre d'une
//     clé Google réelle ni d'un accès réseau. Ne JAMAIS positionner en
//     dehors de `test/`. Doit être remis à `null` dans `tearDown`.
// ---------------------------------------------------------------------------

import 'package:flutter/foundation.dart';

import 'address_autocomplete_provider.dart';
import 'address_provider_config.dart';
import 'google_places_address_provider.dart';
import 'not_configured_address_provider.dart';

class AddressBackendLocator {
  @visibleForTesting
  static AddressAutocompleteProvider? autocompleteProviderOverride;

  static AddressAutocompleteProvider get autocompleteProvider {
    final override = autocompleteProviderOverride;
    if (override != null) return override;
    if (!AddressProviderConfig.isConfigured) {
      return const NotConfiguredAddressAutocompleteProvider();
    }
    return GooglePlacesAddressProvider();
  }
}
