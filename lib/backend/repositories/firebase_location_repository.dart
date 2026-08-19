// ---------------------------------------------------------------------------
// FirebaseLocationRepository — implémentation RÉELLE de LocationRepository.
//
// RÈGLE RESPECTÉE : `reportDriverLocation()` n'écrit JAMAIS directement
// Firestore. Elle appelle la Cloud Function `recordTrackingPoint()`, qui est
// le SEUL point d'entrée autorisé (voir en-tête de recordTrackingPoint.ts —
// dénormalise driver_profiles.current_geohash et gère l'historique
// conditionnel selon mission active).
//
// MAPPING DE SIGNATURE : l'interface `LocationRepository.reportDriverLocation`
// prend un objet `DriverLocation` complet (incluant `driverId`), alors que la
// Cloud Function `recordTrackingPoint` ne prend QUE
// {latitude, longitude, accuracy?, heading?, speed?} — l'identité du
// chauffeur est TOUJOURS déduite de `ctx.uid` côté serveur (jamais un
// paramètre client). Ce repository ignore donc volontairement
// `location.driverId` lors de l'appel (aucune confiance faite à cette
// valeur), et ne l'utilise que pour un contrôle défensif optionnel côté UI
// (non fait ici, car cette classe ne connaît pas l'UID de l'utilisateur
// courant — c'est à l'appelant de garantir qu'il construit bien un
// `DriverLocation` pour lui-même).
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

import '../models/driver_location.dart';
import '../models/driver_location_history_point.dart';
import '../backend_exceptions.dart';
import 'location_repository.dart';

class FirebaseLocationRepository implements LocationRepository {
  FirebaseLocationRepository({FirebaseFirestore? firestore, FirebaseFunctions? functions})
      : _db = firestore ?? FirebaseFirestore.instance,
        _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  CollectionReference<Map<String, dynamic>> get _locations =>
      _db.collection('driver_locations');

  @override
  Future<void> reportDriverLocation(DriverLocation location) async {
    try {
      await _functions.httpsCallable('recordTrackingPoint').call({
        'latitude': location.latitude,
        'longitude': location.longitude,
        if (location.accuracy != null) 'accuracy': location.accuracy,
        if (location.heading != null) 'heading': location.heading,
        if (location.speed != null) 'speed': location.speed,
      });
    } on FirebaseFunctionsException catch (e) {
      throw CloudFunctionException(e.code, e.message ?? 'recordTrackingPoint a échoué.');
    } catch (e) {
      throw BackendNotConfiguredException('reportDriverLocation a échoué: $e');
    }
  }

  @override
  Stream<DriverLocation?> watchDriverLocation(String driverId) {
    // Protégé par firestore.rules (match /driver_locations/{driverId}) :
    // lisible uniquement par le chauffeur lui-même, un analyste/admin, ou un
    // client ayant une mission active avec ce chauffeur.
    return _locations.doc(driverId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return DriverLocation.fromJson(snap.data()!);
    });
  }

  @override
  Stream<List<DriverLocationHistoryPoint>> watchDriverLocationHistory(
    String driverId,
  ) {
    // Requête SIMPLE (pas de where/orderBy composite) : lit toute la
    // sous-collection `history` de ce chauffeur — protégée par
    // firestore.rules (driver lui-même / analyste-admin / client avec
    // mission active dont delivery_id correspond). Tri + filtrage par
    // mission active courante effectués côté appelant, conformément à la
    // convention "requête simple + tri en mémoire" du projet (évite tout
    // besoin d'index composite dédié sur cette sous-collection).
    return _locations.doc(driverId).collection('history').snapshots().map((
      snap,
    ) {
      return snap.docs
          .map((d) => DriverLocationHistoryPoint.fromJson(d.data()))
          .toList();
    });
  }
}
