// ---------------------------------------------------------------------------
// parseFirestoreDate — utilitaire partagé de désérialisation de date.
//
// CONTEXTE CRITIQUE : les Cloud Functions écrivent systématiquement les
// champs de date via `admin.firestore.Timestamp.now()` (voir
// functions/src/lib/admin.ts + tous les fichiers functions/src/functions/*.ts),
// qui arrive côté client Flutter comme un objet `Timestamp` natif du SDK
// `cloud_firestore` (avec `.toDate()`), JAMAIS une chaîne ISO8601. Les
// modèles Dart de ce projet ont été initialement écrits avec
// `DateTime.parse(json['x'] as String)`, ce qui plante
// (`type 'Timestamp' is not a subtype of type 'String'`) dès qu'on lit un
// VRAI document Firestore créé par une Cloud Function.
//
// Ce parseur accepte les trois formes possibles : `Timestamp` (SDK
// Firestore), `DateTime` (déjà converti), ou `String` (ISO8601 — conservé
// pour compatibilité avec `toJson()` local / tests unitaires qui
// sérialisent en String). Voir aussi `DriverProfileV2._parseDate` (pattern
// identique, dupliqué ici car ce fichier vit dans `lib/backend/models/`
// tandis que `driver_profile_v2.dart` a son propre parseur privé).
// ---------------------------------------------------------------------------

DateTime? parseFirestoreDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is DateTime) return raw;
  if (raw is String) {
    try {
      return DateTime.parse(raw);
    } catch (_) {
      return null;
    }
  }
  // Objet Timestamp du SDK cloud_firestore (ou tout objet exposant .toDate()).
  try {
    return (raw as dynamic).toDate() as DateTime;
  } catch (_) {
    return null;
  }
}
