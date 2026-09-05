// ---------------------------------------------------------------------------
// GooglePlacesAddressProvider — implémentation RÉELLE de
// `AddressAutocompleteProvider` basée sur les APIs Google Places (New) :
//   - Place Autocomplete (New) : POST https://places.googleapis.com/v1/places:autocomplete
//   - Place Details (New)     : GET  https://places.googleapis.com/v1/places/{placeId}
//
// Choix technique explicite : appels REST directs via `package:http`
// (déjà présent en dépendance transitive, promu ici en dépendance directe)
// plutôt qu'un package tiers `google_places_flutter`/SDK JS embarqué :
//   - fonctionne IDENTIQUEMENT sur Web et mobile (pas de <script> JS
//     Maps à charger dans web/index.html, pas de plugin natif à
//     configurer côté Android/iOS) ;
//   - contrôle total du contrat de retour (mappé directement vers
//     `AddressSuggestion`/`ResolvedAddress`, jamais un type opaque de SDK) ;
//   - garde l'app testable avec un fake HTTP client sans dépendre d'un
//     mock de SDK tiers.
//
// SÉCURITÉ : la clé utilisée ici (`AddressProviderConfig.googleMapsApiKey`)
// est une clé CLIENT restreinte par domaine/application côté Google Cloud
// Console — ce n'est JAMAIS un secret serveur. Aucun appel ne transite par
// une Cloud Function : cohérent avec la contrainte "no server secrets in
// Flutter" de la directive.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'address_autocomplete_provider.dart';
import 'address_provider_config.dart';
import 'address_suggestion.dart';

class GooglePlacesAddressProvider implements AddressAutocompleteProvider {
  final http.Client _client;
  final String _apiKey;

  GooglePlacesAddressProvider({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = apiKey ?? AddressProviderConfig.googleMapsApiKey;

  static const String _autocompleteUrl = 'https://places.googleapis.com/v1/places:autocomplete';
  String _detailsUrl(String placeId) => 'https://places.googleapis.com/v1/places/$placeId';

  @override
  Future<List<AddressSuggestion>> searchSuggestions(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse(_autocompleteUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Goog-Api-Key': _apiKey,
            },
            body: jsonEncode({'input': trimmed}),
          )
          .timeout(const Duration(seconds: 8));
    } catch (e) {
      throw AddressProviderUnavailableException('Google Places Autocomplete injoignable: $e');
    }

    if (response.statusCode != 200) {
      throw AddressProviderUnavailableException(
        'Google Places Autocomplete a répondu ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = decoded['suggestions'] as List<dynamic>? ?? const [];
    return suggestions
        .map((raw) {
          final placePrediction = (raw as Map<String, dynamic>)['placePrediction'] as Map<String, dynamic>?;
          if (placePrediction == null) return null;
          final placeId = placePrediction['placeId'] as String?;
          final text = (placePrediction['text'] as Map<String, dynamic>?)?['text'] as String?;
          if (placeId == null || text == null) return null;
          return AddressSuggestion(placeId: placeId, description: text);
        })
        .whereType<AddressSuggestion>()
        .toList();
  }

  @override
  Future<ResolvedAddress> resolvePlace(String placeId) async {
    http.Response response;
    try {
      response = await _client.get(
        Uri.parse(_detailsUrl(placeId)),
        headers: {
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask': 'id,formattedAddress,addressComponents,location',
        },
      ).timeout(const Duration(seconds: 8));
    } catch (e) {
      throw AddressProviderUnavailableException('Google Place Details injoignable: $e');
    }

    if (response.statusCode != 200) {
      throw AddressProviderUnavailableException(
        'Google Place Details a répondu ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final formattedAddress = decoded['formattedAddress'] as String? ?? '';
    final location = decoded['location'] as Map<String, dynamic>?;
    final lat = (location?['latitude'] as num?)?.toDouble();
    final lng = (location?['longitude'] as num?)?.toDouble();

    if (lat == null || lng == null) {
      throw AddressProviderUnavailableException(
        'Google Place Details: coordonnées absentes pour placeId=$placeId.',
      );
    }

    final components = decoded['addressComponents'] as List<dynamic>? ?? const [];
    String componentOf(String type) {
      for (final raw in components) {
        final c = raw as Map<String, dynamic>;
        final types = (c['types'] as List<dynamic>? ?? const []).cast<String>();
        if (types.contains(type)) {
          return c['longText'] as String? ?? c['shortText'] as String? ?? '';
        }
      }
      return '';
    }

    return ResolvedAddress(
      placeId: placeId,
      formattedAddress: formattedAddress,
      lat: lat,
      lng: lng,
      streetNumber: componentOf('street_number'),
      street: componentOf('route'),
      city: componentOf('locality').isNotEmpty ? componentOf('locality') : componentOf('postal_town'),
      region: componentOf('administrative_area_level_1'),
      postalCode: componentOf('postal_code'),
      country: componentOf('country'),
    );
  }
}
