// ---------------------------------------------------------------------------
// DistanceEstimationService — ESTIMATION PROVISOIRE distance/durée.
//
// ⚠️ DÉCISION ARCHITECTURALE EXPLICITE (Phase 4) :
// `calculateDeliveryQuote` (Cloud Function) exige `distanceKm` et
// `estimatedDurationMinutes` en entrée — le serveur ne calcule QUE le PRIX à
// partir de ces valeurs, jamais la distance elle-même. Aucune intégration de
// cartographie/routage réelle (Google Maps, Mapbox, OSRM, etc.) n'existe
// encore dans ce projet (aucun package `google_maps_flutter`/`geocoding`
// dans pubspec.yaml).
//
// Plutôt que de simuler un résultat "comme si c'était réel", ce service est
// VOLONTAIREMENT isolé et étiqueté comme estimation à vol d'oiseau
// (formule de Haversine) + un facteur de détour routier approximatif, avec
// une vitesse moyenne urbaine/interurbaine raisonnable pour le Québec.
//
// CE N'EST PAS UN CALCUL DE PRIX — le prix reste calculé exclusivement côté
// serveur par `calculateDeliveryQuote`. Ce service fournit uniquement les
// DEUX PARAMÈTRES D'ENTRÉE (distance, durée) qu'un vrai service de routage
// remplacera un jour, sans changer l'interface `MissionRepository`.
//
// TODO (Phase future) : remplacer par un vrai appel à une API de routage
// (Google Distance Matrix, Mapbox Directions, OSRM auto-hébergé, etc.) —
// il suffira de remplacer l'implémentation de `estimate()` ci-dessous, le
// reste de l'application ne dépend que de `DistanceEstimate`.
// ---------------------------------------------------------------------------

import 'dart:math' as math;

class DistanceEstimate {
  final double distanceKm;
  final double estimatedDurationMinutes;

  /// Toujours `true` pour cette implémentation provisoire — l'UI DOIT
  /// afficher une mention explicite indiquant qu'il s'agit d'une estimation,
  /// jamais d'un itinéraire réel.
  final bool isApproximate;

  const DistanceEstimate({
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    this.isApproximate = true,
  });
}

class DistanceEstimationService {
  const DistanceEstimationService();

  /// Vitesse moyenne retenue pour convertir distance -> durée (km/h),
  /// incluant arrêts, feux de circulation et trafic urbain modéré — valeur
  /// prudente pour ne pas sous-estimer la durée (donc ne pas sous-facturer).
  static const double _averageSpeedKmh = 35.0;

  /// Facteur de détour routier appliqué à la distance à vol d'oiseau : une
  /// route réelle est presque toujours plus longue qu'une ligne droite
  /// (rues, ponts, sens uniques). 1.3 est une approximation courante pour
  /// un contexte urbain/suburbain nord-américain.
  static const double _routeDetourFactor = 1.3;

  /// Durée minimale forfaitaire (manutention, stationnement, accès) même
  /// pour une très courte distance.
  static const double _minimumDurationMinutes = 10.0;

  DistanceEstimate estimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) {
    final straightLineKm = _haversineKm(pickupLat, pickupLng, dropoffLat, dropoffLng);
    final roadDistanceKm = straightLineKm * _routeDetourFactor;
    final durationMinutes = math.max(
      _minimumDurationMinutes,
      (roadDistanceKm / _averageSpeedKmh) * 60,
    );

    return DistanceEstimate(
      distanceKm: double.parse(roadDistanceKm.toStringAsFixed(2)),
      estimatedDurationMinutes: double.parse(durationMinutes.toStringAsFixed(1)),
    );
  }

  double _haversineKm(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusKm = 6371.0;
    final dLat = _degToRad(lat2 - lat1);
    final dLng = _degToRad(lng2 - lng1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degToRad(lat1)) *
            math.cos(_degToRad(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degToRad(double deg) => deg * (math.pi / 180.0);
}
