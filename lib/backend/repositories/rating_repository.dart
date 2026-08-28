// ---------------------------------------------------------------------------
// RatingRepository — interface abstraite pour la notation client -> chauffeur
// après une livraison complétée (Phase 7, Bloc AB, AB-10).
//
// RÈGLE RESPECTÉE (miroir de la Security Rule `ratings/{ratingId}`, voir
// firestore.rules) : `submitDriverRating()` écrit DIRECTEMENT dans Firestore
// (pas de Cloud Function) — contrairement à `MissionRepository` où toute
// écriture d'état/financière DOIT passer par une Cloud Function, la règle
// `ratings/{ratingId}` autorise explicitement un `create` client tant que :
//   - rater_id == uid() de l'appelant ;
//   - stars entre 1 et 5 ;
//   - mission_id référence une mission `completed` ;
//   - rater_role == 'customer' ET customer_id de la mission == uid().
// Il n'existe donc aucune raison d'ajouter une Cloud Function ici (aucun
// calcul serveur, aucune donnée financière, aucun effet secondaire sensible)
// — "minimum cohérent sans architecture excessive" (consigne AB-10).
//
// DOUBLE RATING : la règle autorise UNIQUEMENT `create` (jamais `update`),
// donc une seconde écriture sur le MÊME identifiant de document échoue déjà
// côté serveur. `submitDriverRating()` utilise un ID déterministe
// (`${missionId}_customer`) pour qu'une deuxième tentative retombe
// systématiquement sur ce même ID (donc refusée en `update`), sans dépendre
// uniquement d'une vérification préalable côté client (défense en
// profondeur, cohérent avec le reste du projet — voir
// `customer_tracking_cross_customer_test.dart`).
// ---------------------------------------------------------------------------

import '../models/mission_rating.dart';
import '../backend_exceptions.dart';

abstract class RatingRepository {
  /// Soumet une notation 1-5 étoiles (+ commentaire optionnel) de
  /// `customerId` vers le chauffeur de `missionId`. `customerId` est passé
  /// explicitement par l'appelant (cohérent avec
  /// `watchCustomerMissions(customerId)`/`NotificationRepository.markAsRead(userId, ...)`
  /// — aucun repository de ce projet ne lit `FirebaseAuth.instance`
  /// directement) et DOIT être le client connecté : la Security Rule
  /// serveur revérifie de toute façon que `rater_id == uid()`, donc toute
  /// valeur incohérente échoue avec `permission-denied`.
  ///
  /// `missionId` DOIT référencer une mission déjà `completed` — sinon la
  /// Security Rule serveur refuse l'écriture (`permission-denied`), propagé
  /// ici comme `CloudFunctionException` pour rester cohérent avec le
  /// pattern d'erreurs déjà utilisé par le reste du repository layer (voir
  /// `backend_exceptions.dart`).
  ///
  /// Lève `ArgumentError` si `stars` n'est pas dans [1, 5] (garde côté
  /// client, en plus de la règle serveur).
  Future<void> submitDriverRating({
    required String missionId,
    required String customerId,
    required int stars,
    String? comment,
  });

  /// Vérifie si `customerId` a déjà noté le chauffeur de cette mission —
  /// utilisé pour masquer le CTA de notation / afficher l'état "déjà noté"
  /// sans jamais permettre un second envoi incohérent.
  Future<MissionRating?> getMyRatingForMission({
    required String missionId,
    required String customerId,
  });
}

class NotConfiguredRatingRepository implements RatingRepository {
  const NotConfiguredRatingRepository();

  @override
  Future<void> submitDriverRating({
    required String missionId,
    required String customerId,
    required int stars,
    String? comment,
  }) {
    throw BackendNotConfiguredException(
      'submitDriverRating: backend Firebase non configuré.',
    );
  }

  @override
  Future<MissionRating?> getMyRatingForMission({
    required String missionId,
    required String customerId,
  }) async =>
      null;
}
