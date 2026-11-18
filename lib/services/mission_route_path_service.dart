// ---------------------------------------------------------------------------
// MissionRoutePathService — itinéraire PAR LA ROUTE d'une mission (2026-11-18).
//
// Daniel : « les chauffeurs voient la map à vol d'oiseau ». La carte de suivi
// (chauffeur et client) dessine le trajet ramassage → livraison en suivant
// les routes. Le tracé vient de la Cloud Function `getMissionRoutePath`
// (service d'itinéraire OpenStreetMap appelé côté serveur, réservé aux
// participants de la mission) ; l'application ne contacte jamais ce service
// directement.
//
// Aucune erreur ne remonte : sans tracé (fonction pas encore déployée, panne
// du service, mission sans coordonnées), la carte s'affiche comme avant, sans
// itinéraire — jamais une ligne droite inventée.
// ---------------------------------------------------------------------------

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:latlong2/latlong.dart' as ll;

import '../backend/backend_bootstrap.dart';

/// Source du tracé, injectable pour les tests.
typedef MissionRoutePathLoader =
    Future<List<ll.LatLng>> Function(String missionId);

/// Décode un tracé encodé (algorithme « polyline », précision 5 par défaut).
///
/// Calcul arithmétique seulement, sans opérateurs binaires : compilés pour
/// le web, `~` et `>>` travaillent sur 32 bits non signés et donneraient des
/// coordonnées fausses pour tout déplacement vers le sud ou vers l'ouest.
/// Un tracé invalide ou tronqué donne une liste vide, jamais un tracé partiel.
List<ll.LatLng> decodeRoutePolyline(String encoded, {int precision = 5}) {
  var factor = 1.0;
  for (var i = 0; i < precision; i++) {
    factor *= 10;
  }
  final points = <ll.LatLng>[];
  var index = 0;
  var lat = 0;
  var lng = 0;

  // Lit une valeur signée ; `null` si le tracé est invalide ou tronqué.
  int? readDelta() {
    var result = 0;
    var multiplier = 1;
    var chunks = 0;
    while (true) {
      if (index >= encoded.length || chunks >= 7) return null;
      final chunk = encoded.codeUnitAt(index) - 63;
      index++;
      chunks++;
      if (chunk < 0 || chunk > 63) return null;
      result += (chunk % 32) * multiplier;
      multiplier *= 32;
      if (chunk < 32) break;
    }
    return result.isOdd ? -(result ~/ 2) - 1 : result ~/ 2;
  }

  while (index < encoded.length) {
    final deltaLat = readDelta();
    if (deltaLat == null) return const [];
    final deltaLng = readDelta();
    if (deltaLng == null) return const [];
    lat += deltaLat;
    lng += deltaLng;
    final latitude = lat / factor;
    final longitude = lng / factor;
    if (latitude < -90 || latitude > 90 || longitude < -180 || longitude > 180) {
      return const [];
    }
    points.add(ll.LatLng(latitude, longitude));
  }
  return points;
}

class MissionRoutePathService {
  MissionRoutePathService._();

  @visibleForTesting
  static MissionRoutePathLoader? loaderOverride;

  // Les extrémités d'une mission ne changent pas : un tracé obtenu reste
  // valable pour la session. Un échec n'est pas retenu (nouvel essai à la
  // prochaine ouverture de la carte).
  static final Map<String, List<ll.LatLng>> _cache = {};
  static const int _maxCachedMissions = 20;

  @visibleForTesting
  static void resetForTest() {
    loaderOverride = null;
    _cache.clear();
  }

  /// Tracé routier de la mission, ou liste vide s'il n'est pas disponible.
  static Future<List<ll.LatLng>> load(String missionId) async {
    if (missionId.isEmpty) return const [];
    final cached = _cache[missionId];
    if (cached != null) return cached;
    try {
      final points = await (loaderOverride ?? _loadFromServer)(missionId);
      if (points.length < 2) return const [];
      if (_cache.length >= _maxCachedMissions) _cache.clear();
      final stored = List<ll.LatLng>.unmodifiable(points);
      _cache[missionId] = stored;
      return stored;
    } catch (_) {
      return const [];
    }
  }

  static Future<List<ll.LatLng>> _loadFromServer(String missionId) async {
    if (!BackendBootstrap.status.isConfigured) return const [];
    final result = await FirebaseFunctions.instance
        .httpsCallable(
          'getMissionRoutePath',
          options: HttpsCallableOptions(timeout: const Duration(seconds: 15)),
        )
        .call(<String, dynamic>{'missionId': missionId});
    final data = result.data;
    if (data is! Map) return const [];
    final encoded = data['encodedPolyline'];
    if (encoded is! String || encoded.isEmpty) return const [];
    final precision = data['precision'];
    return decodeRoutePolyline(
      encoded,
      precision: precision is num && precision >= 1 && precision <= 7
          ? precision.toInt()
          : 5,
    );
  }
}
