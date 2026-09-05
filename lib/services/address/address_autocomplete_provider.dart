// ---------------------------------------------------------------------------
// AddressAutocompleteProvider — abstraction du fournisseur cartographique
// utilisé pour l'autocomplete d'adresse + le géocodage (résolution
// suggestion -> coordonnées réelles).
//
// RÈGLE D'ARCHITECTURE (MOVI-K — CORRECTION UX LIVRAISON) : AUCUN écran, AUCUN
// widget ne doit jamais appeler directement une API cartographique
// (Google Places, etc.). Tout passe par cette interface, exactement comme
// `MissionRepository`/`BackendLocator` découplent déjà Firebase du reste de
// l'app. Ceci permet :
//   - de brancher un fournisseur réel (Google Places/Geocoding) sans
//     changer un seul widget ;
//   - d'injecter un `FakeAddressAutocompleteProvider` déterministe dans les
//     tests (voir AddressBackendLocator.autocompleteProviderOverride) ;
//   - de basculer plus tard vers un autre fournisseur (Mapbox, etc.) sans
//     casser le contrat.
//
// AUCUN SECRET SERVEUR n'est jamais chargé ici : une implémentation réelle
// (ex: GooglePlacesAddressProvider) n'utilise qu'une clé "publique" côté
// client (restreinte par domaine/application côté Google Cloud Console —
// voir ACTION DANIEL dans le rapport final), jamais une clé serveur.
// ---------------------------------------------------------------------------

import 'address_suggestion.dart';

/// Levée par une implémentation lorsque le fournisseur cartographique est
/// injoignable/indisponible (réseau, quota, service down, clé API absente
/// ou invalide). L'UI doit TOUJOURS attraper cette exception et afficher un
/// message générique traduit (jamais le détail technique brut) — voir
/// `delivery_address_provider_unavailable` dans app_strings.dart.
class AddressProviderUnavailableException implements Exception {
  final String message;
  const AddressProviderUnavailableException(this.message);
  @override
  String toString() => 'AddressProviderUnavailableException: $message';
}

abstract class AddressAutocompleteProvider {
  /// Retourne une liste de suggestions correspondant à la saisie partielle
  /// `query`. Doit renvoyer une liste VIDE (jamais lever d'exception) si
  /// `query` est trop court ou si aucune suggestion ne correspond — seule
  /// l'indisponibilité du fournisseur lui-même (réseau, quota, clé
  /// invalide) doit lever [AddressProviderUnavailableException].
  Future<List<AddressSuggestion>> searchSuggestions(String query);

  /// Résout une suggestion précédemment retournée par [searchSuggestions]
  /// (via son `placeId`) en une adresse complète avec coordonnées. Lève
  /// [AddressProviderUnavailableException] si le fournisseur est
  /// injoignable, ou une exception générique si `placeId` est inconnu/plus
  /// valide (adresse changée entre la recherche et la sélection, etc.).
  Future<ResolvedAddress> resolvePlace(String placeId);
}
