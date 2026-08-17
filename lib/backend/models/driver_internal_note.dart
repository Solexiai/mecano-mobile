// ---------------------------------------------------------------------------
// DriverInternalNote (Firestore-ready) — collection `driver_internal_notes/{id}`.
//
// Notes internes analyste/admin sur un dossier chauffeur. JAMAIS visibles au
// chauffeur (firestore.rules: lecture analyst/admin/super_admin uniquement).
// Immuables : écrites exclusivement via la Cloud Function
// `addDriverInternalNote` (jamais de update/delete, voir firestore.rules).
// ---------------------------------------------------------------------------

class DriverInternalNote {
  final String id;
  final String driverId;
  final String authorUserId;
  final String authorRole;
  final String text;
  final DateTime createdAt;

  const DriverInternalNote({
    required this.id,
    required this.driverId,
    required this.authorUserId,
    required this.authorRole,
    required this.text,
    required this.createdAt,
  });

  factory DriverInternalNote.fromJson(String id, Map<String, dynamic> json) {
    final rawCreatedAt = json['created_at'];
    DateTime createdAt;
    if (rawCreatedAt == null) {
      createdAt = DateTime.now();
    } else if (rawCreatedAt is DateTime) {
      createdAt = rawCreatedAt;
    } else {
      // Firestore Timestamp exposes toDate() via cloud_firestore's Timestamp.
      try {
        createdAt = (rawCreatedAt as dynamic).toDate() as DateTime;
      } catch (_) {
        createdAt = DateTime.now();
      }
    }
    return DriverInternalNote(
      id: id,
      driverId: json['driver_id'] as String? ?? '',
      authorUserId: json['author_user_id'] as String? ?? '',
      authorRole: json['author_role'] as String? ?? '',
      text: json['text'] as String? ?? '',
      createdAt: createdAt,
    );
  }
}
