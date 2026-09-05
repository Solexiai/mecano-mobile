// ---------------------------------------------------------------------------
// FakeAddressAutocompleteProvider — double de test PARTAGÉ pour
// `AddressAutocompleteProvider` (MOVI-K — CORRECTION UX LIVRAISON — ADRESSES
// RÉELLES + AUTOCOMPLETE + GÉOCODAGE).
//
// Injecté via `AddressBackendLocator.autocompleteProviderOverride` (seam de
// test `@visibleForTesting`, exactement comme
// `BackendLocator.missionRepositoryOverride`). Permet de piloter tous les
// widget tests qui traversent `_Step2Addresses`/`AddressAutocompleteField`
// SANS dépendre d'une clé Google réelle ni d'un accès réseau :
//   - une recherche renvoie TOUJOURS une suggestion unique dérivée
//     déterministiquement du texte tapé (`query`) — donc deux requêtes avec
//     un texte différent (ex: adresse pickup vs adresse dropoff) produisent
//     des `ResolvedAddress` DIFFÉRENTES (lat/lng distincts), ce qui permet de
//     prouver l'indépendance pickup/dropoff dans les tests ;
//   - `searchUnavailable`/`resolveUnavailable` simulent un fournisseur
//     cartographique injoignable (`AddressProviderUnavailableException`) ;
//   - `emptySuggestions` simule une adresse sans aucune suggestion connue.
//
// `typeAndSelectAddress()` est l'helper d'INTERACTION partagé : tape un
// texte dans le `TextField` situé à l'index `fieldIndex` parmi
// `find.byType(TextField)`, attend le debounce (350ms par défaut dans
// `AddressAutocompleteField`) + la résolution de la `Future` du fake
// provider, puis tape sur la suggestion affichée pour la sélectionner —
// reproduisant exactement le geste réel d'un client dans
// `DeliveryRequestFlowScreen`.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:movik_connect/services/address/address_autocomplete_provider.dart';
import 'package:movik_connect/services/address/address_suggestion.dart';
import 'package:movik_connect/widgets/address_autocomplete_field.dart';

class FakeAddressAutocompleteProvider implements AddressAutocompleteProvider {
  /// Si vrai, `searchSuggestions` lève `AddressProviderUnavailableException`
  /// (simule un fournisseur cartographique injoignable pendant la recherche).
  bool searchUnavailable = false;

  /// Si vrai, `resolvePlace` lève `AddressProviderUnavailableException`
  /// (simule un fournisseur injoignable pendant la résolution — après que
  /// des suggestions aient pourtant été affichées).
  bool resolveUnavailable = false;

  /// Si vrai, `searchSuggestions` renvoie toujours une liste VIDE (simule une
  /// adresse pour laquelle le fournisseur ne trouve aucune suggestion).
  bool emptySuggestions = false;

  int searchCallCount = 0;
  int resolveCallCount = 0;

  final Map<String, ResolvedAddress> _resolvedByPlaceId = {};

  @override
  Future<List<AddressSuggestion>> searchSuggestions(String query) async {
    searchCallCount++;
    if (searchUnavailable) {
      throw const AddressProviderUnavailableException('fake: searchSuggestions indisponible (test).');
    }
    if (emptySuggestions) return const [];

    // Dérive un placeId + un ResolvedAddress DÉTERMINISTES à partir du texte
    // tapé, pour que deux queries différentes (pickup vs dropoff) produisent
    // toujours des coordonnées différentes, sans jamais renvoyer de
    // coordonnées "1,2" placeholder.
    final hash = query.hashCode.abs() % 5000;
    final placeId = 'fake_place_${query.hashCode}';
    final resolved = ResolvedAddress(
      placeId: placeId,
      formattedAddress: '$query (adresse résolue), FakeVille, QC, Canada',
      streetNumber: '',
      street: query,
      city: 'FakeVille',
      region: 'QC',
      postalCode: 'H0H 0H0',
      country: 'Canada',
      lat: 45.0 + hash / 10000,
      lng: -73.0 - hash / 10000,
    );
    _resolvedByPlaceId[placeId] = resolved;
    return [AddressSuggestion(placeId: placeId, description: resolved.formattedAddress)];
  }

  @override
  Future<ResolvedAddress> resolvePlace(String placeId) async {
    resolveCallCount++;
    if (resolveUnavailable) {
      throw const AddressProviderUnavailableException('fake: resolvePlace indisponible (test).');
    }
    final resolved = _resolvedByPlaceId[placeId];
    if (resolved == null) {
      throw Exception('fake: placeId inconnu ($placeId) — resolvePlace appelé sans searchSuggestions préalable ?');
    }
    return resolved;
  }
}

/// Tape [query] dans le `TextField` situé à l'index [fieldIndex] parmi
/// `find.byType(TextField)` (0 = adresse d'enlèvement, 1 = adresse de
/// livraison dans `_Step2Addresses`), laisse le debounce de
/// `AddressAutocompleteField` se déclencher, puis sélectionne la première
/// suggestion affichée (`ListTile`). Reproduit le parcours RÉEL d'un client :
/// jamais de coordonnées injectées directement, toujours via la sélection
/// d'une suggestion retournée par le provider (fake ici, Google en prod).
Future<void> typeAndSelectAddress(
  WidgetTester tester,
  int fieldIndex,
  String query,
) async {
  // Cible le `AddressAutocompleteField` lui-même (pas juste le n-ième
  // `TextField` de l'écran entier) : plus robuste si d'autres `ListTile`
  // existent ailleurs dans l'arbre (ex: tiroir de navigation `AppShell`),
  // et documente explicitement QUEL champ d'adresse (pickup=0, dropoff=1)
  // est manipulé.
  final addressFieldFinder = find.byType(AddressAutocompleteField).at(fieldIndex);
  final field = find.descendant(of: addressFieldFinder, matching: find.byType(TextField));
  await tester.ensureVisible(field);
  await tester.enterText(field, query);
  // Laisse le Timer de debounce (350ms) se déclencher puis la Future du fake
  // provider se résoudre et le widget se stabiliser (liste de suggestions
  // affichée).
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pumpAndSettle();

  final suggestionTile = find
      .descendant(of: addressFieldFinder, matching: find.byType(ListTile))
      .first;
  await tester.ensureVisible(suggestionTile);
  await tester.tap(suggestionTile);
  await tester.pumpAndSettle();
}
