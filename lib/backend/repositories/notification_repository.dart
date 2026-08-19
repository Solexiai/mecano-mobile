// ---------------------------------------------------------------------------
// NotificationRepository — interface abstraite pour les notifications
// utilisateur (Phase 5, partie 3).
//
// RÈGLE CRITIQUE (miroir de mission_repository.dart) : les notifications ne
// sont JAMAIS créées depuis Flutter — seul le trigger serveur
// `onMissionStatusChangeNotifyCustomer` (ou d'autres futurs triggers
// équivalents) écrit dans `users/{uid}/notifications/{id}` (voir
// firestore.rules : `allow create: if false`). Ce repository n'expose donc
// que de la LECTURE et le marquage lu/non-lu (seul champ mutable côté
// client, `is_read`, conformément à la règle `update`).
// ---------------------------------------------------------------------------

import '../models/app_notification.dart';
import '../backend_exceptions.dart';

abstract class NotificationRepository {
  /// Flux temps réel des notifications de l'utilisateur courant, triées
  /// des plus récentes aux plus anciennes.
  Stream<List<AppNotification>> watchNotifications(String userId);

  /// Flux temps réel du nombre de notifications non lues.
  Stream<int> watchUnreadCount(String userId);

  /// Marque UNE notification comme lue (met à jour `is_read`/`read_at`).
  Future<void> markAsRead(String userId, String notificationId);

  /// Marque TOUTES les notifications non lues de l'utilisateur comme lues.
  Future<void> markAllAsRead(String userId);
}

/// Implémentation sûre utilisée quand Firebase n'est pas configuré. Ne
/// simule aucune donnée réelle : flux vides, échec explicite sur écriture.
class NotConfiguredNotificationRepository implements NotificationRepository {
  const NotConfiguredNotificationRepository();

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) =>
      Stream.value(const []);

  @override
  Stream<int> watchUnreadCount(String userId) => Stream.value(0);

  @override
  Future<void> markAsRead(String userId, String notificationId) {
    throw BackendNotConfiguredException(
        'markAsRead: Firebase Firestore non configuré.');
  }

  @override
  Future<void> markAllAsRead(String userId) {
    throw BackendNotConfiguredException(
        'markAllAsRead: Firebase Firestore non configuré.');
  }
}
