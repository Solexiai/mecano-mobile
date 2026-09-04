// ---------------------------------------------------------------------------
// AddressSuggestion / ResolvedAddress — modèles de la couche d'abstraction
// "adresse réelle" (MOVI-K — CORRECTION UX LIVRAISON, adresses réelles +
// autocomplete + géocodage).
//
// Ces deux classes forment le CONTRAT STABLE entre l'UI (champ d'adresse
// avec suggestions) et n'importe quel fournisseur cartographique/geocoding
// (`AddressAutocompleteProvider`, voir address_autocomplete_provider.dart) :
//   - `AddressSuggestion` : un résultat de recherche partielle (le client
//     tape "527 rue Lacasse, Terrebonne", le fournisseur renvoie une liste
//     de suggestions, chacune identifiée par un `placeId` opaque).
//   - `ResolvedAddress` : le détail COMPLET d'une adresse après sélection
//     d'une suggestion (adresse formatée, composants structurés, lat/lng).
//     C'est la SEULE forme sous laquelle une adresse peut alimenter
//     `MissionAddress`/`CreateMissionRequest` — jamais une saisie libre non
//     résolue, jamais une latitude/longitude tapée manuellement.
//
// Ce fichier ne dépend d'AUCUN SDK/fournisseur externe (Google, etc.) —
// c'est volontaire : l'abstraction doit rester remplaçable sans jamais
// modifier l'UI ni le reste de l'application.
// ---------------------------------------------------------------------------

/// Une suggestion d'adresse retournée pendant la frappe (autocomplete).
/// `placeId` est un identifiant OPAQUE propre au fournisseur (ex: Google
/// Place ID) — ne doit jamais être interprété/parsé par l'UI, seulement
/// réutilisé pour appeler `AddressAutocompleteProvider.resolvePlace()`.
class AddressSuggestion {
  final String placeId;

  /// Texte complet à afficher dans la liste de suggestions (ex: "527 Rue
  /// Lacasse, Terrebonne, QC J6W 4Y7, Canada").
  final String description;

  const AddressSuggestion({required this.placeId, required this.description});
}

/// Une adresse COMPLÈTEMENT résolue (après sélection d'une suggestion ou
/// géocodage direct) — seule forme acceptée pour construire une
/// `MissionAddress` réelle. Tous les champs structurés sont fournis en
/// meilleur effort par le fournisseur (peuvent être vides si le fournisseur
/// ne les distingue pas), mais `formattedAddress`/`placeId`/`lat`/`lng` sont
/// TOUJOURS renseignés — c'est la garantie fail-closed de cette classe.
class ResolvedAddress {
  final String placeId;
  final String formattedAddress;
  final String streetNumber;
  final String street;
  final String city;
  final String region; // province/état
  final String postalCode;
  final String country;
  final double lat;
  final double lng;

  const ResolvedAddress({
    required this.placeId,
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.streetNumber = '',
    this.street = '',
    this.city = '',
    this.region = '',
    this.postalCode = '',
    this.country = '',
  });

  /// `line1` denormalisé pour rester compatible avec `MissionAddress.line1`
  /// (numéro + rue), avec repli sur `formattedAddress` si le fournisseur ne
  /// distingue pas numéro/rue séparément.
  String get line1 {
    final combined = [streetNumber, street].where((s) => s.trim().isNotEmpty).join(' ');
    return combined.trim().isNotEmpty ? combined.trim() : formattedAddress;
  }
}
