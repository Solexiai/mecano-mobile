// ---------------------------------------------------------------------------
// AppNotification — notification métier destinée à UN utilisateur, stockée
// dans `users/{uid}/notifications/{notificationId}` (voir
// docs/FIRESTORE_ARCHITECTURE.md #19 et
// functions/src/functions/onMissionStatusChangeNotifyCustomer.ts).
//
// Le texte affiché n'est JAMAIS stocké en clair côté serveur : `titleKey`
// et `bodyKey` sont des clés i18n (voir lib/l10n/app_strings.dart, préfixe
// `notif_*`) résolues côté client selon la langue active
// (LocaleProvider.t()), pour garantir FR/EN/ES sans dépendre de la langue
// active du serveur au moment de la création.
// ---------------------------------------------------------------------------

import 'firestore_date.dart';

class AppNotification {
  final String id;
  final String userId;
  final String type; // ex: 'driver_assigned', 'completed', 'cancelled'…
  final String titleKey;
  final String bodyKey;
  final String? missionId;
  final DateTime createdAt;
  final DateTime? readAt;
  final bool isRead;
  final Map<String, dynamic> metadata;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.titleKey,
    required this.bodyKey,
    this.missionId,
    required this.createdAt,
    this.readAt,
    this.isRead = false,
    this.metadata = const {},
  });

  factory AppNotification.fromJson(
    String id,
    String userId,
    Map<String, dynamic> json,
  ) {
    return AppNotification(
      id: id,
      userId: userId,
      type: json['type'] as String? ?? '',
      titleKey: json['title_key'] as String? ?? '',
      bodyKey: json['body_key'] as String? ?? '',
      missionId: json['related_mission_id'] as String?,
      createdAt: parseFirestoreDate(json['created_at']) ?? DateTime.now(),
      readAt: parseFirestoreDate(json['read_at']),
      isRead: json['is_read'] as bool? ?? false,
      metadata: json['metadata'] is Map
          ? Map<String, dynamic>.from(json['metadata'] as Map)
          : const {},
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title_key': titleKey,
        'body_key': bodyKey,
        'related_mission_id': missionId,
        'created_at': createdAt.toIso8601String(),
        'read_at': readAt?.toIso8601String(),
        'is_read': isRead,
        'metadata': metadata,
      };
}
