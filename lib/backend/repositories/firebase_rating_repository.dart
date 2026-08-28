// ---------------------------------------------------------------------------
// FirebaseRatingRepository — implémentation RÉELLE de RatingRepository,
// branchée sur Cloud Firestore (Phase 7, Bloc AB, AB-10).
//
// Écriture DIRECTE Firestore (voir en-tête de rating_repository.dart pour la
// justification : la Security Rule `ratings/{ratingId}` autorise déjà
// explicitement ce `create` client, contrairement aux écritures d'état de
// mission qui doivent passer par une Cloud Function).
//
// ID DE DOCUMENT DÉTERMINISTE `${missionId}_customer` : garantit qu'une
// deuxième tentative de notation pour la même mission par le même rôle
// retombe sur le même document -> `update`, toujours refusé par la règle
// (`allow update: if false`) -> `permission-denied` propre, jamais un
// doublon silencieux.
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/mission_rating.dart';
import '../backend_exceptions.dart';
import 'rating_repository.dart';

class FirebaseRatingRepository implements RatingRepository {
  FirebaseRatingRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _ratings =>
      _db.collection('ratings');

  String _customerRatingDocId(String missionId) => '${missionId}_customer';

  @override
  Future<void> submitDriverRating({
    required String missionId,
    required String customerId,
    required int stars,
    String? comment,
  }) async {
    if (stars < 1 || stars > 5) {
      throw ArgumentError.value(stars, 'stars', 'doit être entre 1 et 5.');
    }
    final trimmedComment = comment?.trim();
    try {
      await _ratings.doc(_customerRatingDocId(missionId)).set({
        'mission_id': missionId,
        'rater_id': customerId,
        'rater_role': 'customer',
        'stars': stars,
        if (trimmedComment != null && trimmedComment.isNotEmpty)
          'comment': trimmedComment,
        'created_at': FieldValue.serverTimestamp(),
      });
    } on FirebaseException catch (e) {
      // `permission-denied` attendu si : mission pas `completed`, client pas
      // propriétaire de la mission, ou notation déjà existante pour cette
      // mission (tentative de `update` déguisée en `set` sur le même ID —
      // Firestore route toujours un `.set()` sur un document existant vers
      // la règle `update`, jamais `create`).
      throw CloudFunctionException(
        e.code,
        e.message ?? 'submitDriverRating a échoué.',
      );
    }
  }

  @override
  Future<MissionRating?> getMyRatingForMission({
    required String missionId,
    required String customerId,
  }) async {
    final snap = await _ratings.doc(_customerRatingDocId(missionId)).get();
    if (!snap.exists || snap.data() == null) return null;
    final rating = MissionRating.fromJson(snap.id, snap.data()!);
    // Défense en profondeur : ne renvoyer cette notation que si elle
    // appartient bien au client demandeur (toujours le cas en pratique
    // puisque l'ID est déterministe par mission, mais explicite plutôt
    // qu'implicite).
    if (rating.raterId != customerId) return null;
    return rating;
  }
}
