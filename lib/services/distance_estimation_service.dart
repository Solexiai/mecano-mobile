// ---------------------------------------------------------------------------
// DistanceEstimationService — itinéraire routier réel.
//
// Le navigateur appelle la Cloud Function authentifiée calculateRoute.
// Le serveur interroge Google Routes API et renvoie uniquement la distance
// routière et la durée. Aucun calcul à vol d'oiseau n'est utilisé.
// ---------------------------------------------------------------------------

import 'package:cloud_functions/cloud_functions.dart';

class DistanceEstimate {
  final double distanceKm;
  final double estimatedDurationMinutes;
  final bool isApproximate;

  const DistanceEstimate({
    required this.distanceKm,
    required this.estimatedDurationMinutes,
    required this.isApproximate,
  });
}

class DistanceEstimationService {
  const DistanceEstimationService();

  Future<DistanceEstimate> estimate({
    required double pickupLat,
    required double pickupLng,
    required double dropoffLat,
    required double dropoffLng,
  }) async {
    final callable = FirebaseFunctions.instanceFor(
      region: 'us-central1',
    ).httpsCallable('calculateRoute');

    final result = await callable.call(<String, dynamic>{
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
    });
    final data = Map<String, dynamic>.from(result.data as Map);
    final distance = (data['distanceKm'] as num?)?.toDouble();
    final duration = (data['estimatedDurationMinutes'] as num?)?.toDouble();

    if (distance == null ||
        duration == null ||
        !distance.isFinite ||
        !duration.isFinite ||
        distance <= 0 ||
        duration <= 0) {
      throw StateError(
        'Le service de routage n\'a retourné aucun itinéraire valide.',
      );
    }

    return DistanceEstimate(
      distanceKm: distance,
      estimatedDurationMinutes: duration,
      isApproximate: data['isApproximate'] == true,
    );
  }
}
