// ---------------------------------------------------------------------------
// AddressProviderConfig — configuration CENTRALISÉE de la clé/du
// fournisseur d'autocomplete d'adresse.
//
// Analogue à `firebase_options.dart` pour Firebase : centralise ici tout ce
// qui est "public"/client-side (clé Google Maps/Places RESTREINTE par
// domaine, jamais un secret serveur) plutôt que de le disperser dans les
// écrans. La clé n'est JAMAIS committée en dur dans ce fichier — elle est
// injectée au moment du build via `--dart-define=GOOGLE_MAPS_API_KEY=...`
// (voir scripts/vercel_build.sh) et lue ici avec `String.fromEnvironment`,
// qui compile la valeur en constante à la build — aucun appel réseau, aucun
// fichier de config chargé à l'exécution.
//
// isConfigured == false (clé absente) => `AddressBackendLocator` retombe
// sur `NotConfiguredAddressAutocompleteProvider` (fail closed, jamais une
// simulation de données) — exactement le même principe que
// `BackendBootstrap.status.isConfigured` pour Firebase.
// ---------------------------------------------------------------------------

class AddressProviderConfig {
  AddressProviderConfig._();

  /// Clé "publique" Google Maps/Places, restreinte côté Google Cloud
  /// Console par domaine (Web) / empreinte d'application (Android/iOS) et
  /// par API autorisée (Places API (New), Geocoding API uniquement) — voir
  /// section "ACTION DANIEL" du rapport. Ce n'est PAS un secret serveur.
  static const String googleMapsApiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  static bool get isConfigured => googleMapsApiKey.isNotEmpty;

  /// Domaines Web pour lesquels cette clé doit être restreinte côté Google
  /// Cloud Console (référence documentaire uniquement — la restriction
  /// réelle se configure dans la console Google, pas dans ce code).
  /// Centralisé ici plutôt que dispersé dans plusieurs endroits, afin
  /// qu'ajouter le futur domaine officiel Movi-K soit un seul changement.
  static const List<String> allowedWebDomains = [
    'https://movi-k.com/*',
    'https://www.movi-k.com/*',
    'https://mecano-mobile-delta.vercel.app/*',
    // La restriction réelle se règle dans Google Cloud Console : movi-k.com
    // doit y figurer, sinon l'autocomplétion d'adresse échoue sur le site.
  ];
}
