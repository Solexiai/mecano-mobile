// ---------------------------------------------------------------------------
// MissionRating (Firestore-ready) — collection `ratings/{ratingId}`.
//
// Phase 7, Bloc AB (AB-10) : requirement produit initial de Movi-K —
// "après une livraison terminée, le client peut évaluer le chauffeur de 1 à
// 5 étoiles avec commentaire optionnel" — confirmé absent de tout code
// applicatif (aucune Cloud Function, aucun repository, aucune UI) malgré
// une Security Rule déjà bien conçue pour `ratings/{ratingId}` (Phase 2/3,
// commit 3af089f). Ce modèle est le miroir Dart exact de ce que cette règle
// autorise déjà à écrire.
//
// Schéma (voir firestore.rules, match /ratings/{ratingId}) :
//   - rater_id      : uid de l'auteur de la notation (== uid() côté règle)
//   - rater_role    : 'customer' | 'driver' — seul 'customer' est écrit par
//                      ce tour (le client note le chauffeur) ; le champ
//                      existe côté règle pour un futur usage bidirectionnel
//                      (chauffeur note client), non demandé par AB-10.
//   - mission_id    : doit référencer une mission `delivery_requests`
//                      existante et `status == 'completed'`.
//   - stars         : entier 1-5 (validé également côté Flutter avant
//                      tentative d'écriture, en plus de la règle serveur).
//   - comment       : optionnel, texte libre.
//   - created_at    : horodatage serveur (FieldValue.serverTimestamp()).
//
// ID DE DOCUMENT DÉTERMINISTE (`${missionId}_customer`) : voir
// `RatingRepository.submitDriverRating` — permet d'empêcher tout double
// rating PAR CONSTRUCTION, sans modifier la règle existante (une seconde
// tentative d'écriture sur le même ID est un `update` Firestore, refusé par
// `allow update: if false`).
// ---------------------------------------------------------------------------

import 'firestore_date.dart';

class MissionRating {
  final String id;
  final String missionId;
  final String raterId;
  final String raterRole; // 'customer' | 'driver'
  final int stars;
  final String? comment;
  final DateTime? createdAt;

  const MissionRating({
    required this.id,
    required this.missionId,
    required this.raterId,
    required this.raterRole,
    required this.stars,
    this.comment,
    this.createdAt,
  });

  factory MissionRating.fromJson(String id, Map<String, dynamic> json) {
    return MissionRating(
      id: id,
      missionId: json['mission_id'] as String? ?? '',
      raterId: json['rater_id'] as String? ?? '',
      raterRole: json['rater_role'] as String? ?? '',
      stars: (json['stars'] as num?)?.toInt() ?? 0,
      comment: json['comment'] as String?,
      createdAt: parseFirestoreDate(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'mission_id': missionId,
        'rater_id': raterId,
        'rater_role': raterRole,
        'stars': stars,
        if (comment != null) 'comment': comment,
        'created_at': createdAt?.toIso8601String(),
      };
}
