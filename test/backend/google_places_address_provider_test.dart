// ---------------------------------------------------------------------------
// GooglePlacesAddressProvider — tests de câblage de la clé API réelle.
//
// CONTEXTE (MOVI-K — BRANCHER GOOGLE_MAPS_API_KEY DANS LE BUILD VERCEL)
//   `AddressProviderConfig.googleMapsApiKey` est une constante COMPILE-TIME
//   (`String.fromEnvironment`) : sa valeur ne peut pas être modifiée
//   dynamiquement pendant un run `flutter test` (aucun --dart-define n'est
//   passé ici, donc elle vaut toujours '' dans ce process). On ne peut donc
//   PAS prouver ici que "la clé Vercel réelle" est utilisée en production —
//   ça, c'est le rôle de scripts/vercel_build.sh (qui passe
//   --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY au build Flutter
//   Web) et ne peut être vérifié que par inspection du script + déploiement
//   réel Vercel.
//
//   Ce que CE fichier prouve, en revanche, de façon 100% déterministe et
//   sans dépendre du compile-time define ni du réseau : que
//   `GooglePlacesAddressProvider`, lorsqu'on lui fournit une clé (via son
//   constructeur `apiKey:` — le même paramètre que
//   `AddressProviderConfig.googleMapsApiKey` alimente en production),
//   l'utilise BIEN dans l'en-tête `X-Goog-Api-Key` de CHAQUE requête HTTP
//   sortante (autocomplete ET détails de lieu), et qu'aucune clé n'est
//   codée en dur ailleurs. Combiné à la lecture du code source de
//   `GooglePlacesAddressProvider` (qui n'a AUCUNE valeur par défaut non
//   vide et délègue uniquement à `AddressProviderConfig.googleMapsApiKey`),
//   ceci garantit que la vraie clé Vercel, une fois injectée au build via
//   --dart-define, sera effectivement celle envoyée à l'API Google Places.
// ---------------------------------------------------------------------------

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:movik_connect/services/address/google_places_address_provider.dart';

void main() {
  const fakeKey = 'FAKE_TEST_KEY_never_a_real_secret';

  group('GooglePlacesAddressProvider — la clé API injectée est bien transmise', () {
    test('searchSuggestions envoie la clé dans l\'en-tête X-Goog-Api-Key', () async {
      String? capturedApiKeyHeader;
      Uri? capturedUri;

      final mockClient = MockClient((request) async {
        capturedApiKeyHeader = request.headers['X-Goog-Api-Key'];
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'suggestions': [
              {
                'placePrediction': {
                  'placeId': 'place_123',
                  'text': {'text': '527 Rue Lacasse, Terrebonne, QC'},
                },
              },
            ],
          }),
          200,
        );
      });

      final provider = GooglePlacesAddressProvider(client: mockClient, apiKey: fakeKey);
      final results = await provider.searchSuggestions('527 rue Lacasse');

      expect(capturedApiKeyHeader, fakeKey);
      expect(capturedUri.toString(), 'https://places.googleapis.com/v1/places:autocomplete');
      expect(results, hasLength(1));
      expect(results.first.placeId, 'place_123');
    });

    test('resolvePlace envoie la clé dans l\'en-tête X-Goog-Api-Key', () async {
      String? capturedApiKeyHeader;
      Uri? capturedUri;

      final mockClient = MockClient((request) async {
        capturedApiKeyHeader = request.headers['X-Goog-Api-Key'];
        capturedUri = request.url;
        return http.Response(
          jsonEncode({
            'formattedAddress': '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada',
            'location': {'latitude': 45.7, 'longitude': -73.6},
            'addressComponents': <dynamic>[],
          }),
          200,
        );
      });

      final provider = GooglePlacesAddressProvider(client: mockClient, apiKey: fakeKey);
      final resolved = await provider.resolvePlace('place_123');

      expect(capturedApiKeyHeader, fakeKey);
      expect(capturedUri.toString(), 'https://places.googleapis.com/v1/places/place_123');
      expect(resolved.formattedAddress, '527 Rue Lacasse, Terrebonne, QC J6W 4Y7, Canada');
      expect(resolved.lat, 45.7);
      expect(resolved.lng, -73.6);
    });

    test('deux instances avec des clés différentes envoient chacune LEUR PROPRE clé (pas de fuite croisée)', () async {
      String? capturedKeyA;
      String? capturedKeyB;

      final clientA = MockClient((request) async {
        capturedKeyA = request.headers['X-Goog-Api-Key'];
        return http.Response(jsonEncode({'suggestions': <dynamic>[]}), 200);
      });
      final clientB = MockClient((request) async {
        capturedKeyB = request.headers['X-Goog-Api-Key'];
        return http.Response(jsonEncode({'suggestions': <dynamic>[]}), 200);
      });

      final providerA = GooglePlacesAddressProvider(client: clientA, apiKey: 'key-A');
      final providerB = GooglePlacesAddressProvider(client: clientB, apiKey: 'key-B');

      await providerA.searchSuggestions('adresse test');
      await providerB.searchSuggestions('adresse test');

      expect(capturedKeyA, 'key-A');
      expect(capturedKeyB, 'key-B');
    });

    test('sans apiKey explicite, retombe sur AddressProviderConfig.googleMapsApiKey (vide en test)', () async {
      String? capturedApiKeyHeader;
      final mockClient = MockClient((request) async {
        capturedApiKeyHeader = request.headers['X-Goog-Api-Key'];
        return http.Response(jsonEncode({'suggestions': <dynamic>[]}), 200);
      });

      // Pas de --dart-define dans ce run de test => googleMapsApiKey == ''.
      // Ceci prouve qu'il n'y a AUCUNE clé codée en dur en repli : le
      // provider transmet fidèlement ce qu'il reçoit de la config, jamais
      // une valeur par défaut fabriquée.
      final provider = GooglePlacesAddressProvider(client: mockClient);
      await provider.searchSuggestions('adresse test');

      expect(capturedApiKeyHeader, isEmpty);
    });
  });
}
