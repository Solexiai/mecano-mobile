// ---------------------------------------------------------------------------
// FirebaseNotificationRepository — implémentation RÉELLE de
// NotificationRepository, branchée sur Cloud Firestore.
//
// Lecture directe (streams) protégée par firestore.rules
// (`users/{userId}/notifications/{notificationId}` : lecture uniquement par
// le propriétaire). `markAsRead`/`markAllAsRead` sont des écritures
// DIRECTES Firestore (pas de Cloud Function) car firestore.rules autorise
// déjà explicitement le propriétaire à modifier UNIQUEMENT `is_read`
// (`request.resource.data.diff(resource.data).affectedKeys().hasOnly(['is_read'])`)
// — cohérent avec `setDriverOnlineStatus` dans FirebaseDriverRepository qui
// suit le même principe pour un champ non sensible.
// ---------------------------------------------------------------------------

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';
import 'notification_repository.dart';

class FirebaseNotificationRepository implements NotificationRepository {
  FirebaseNotificationRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> _notifications(String userId) =>
      _db.collection('users').doc(userId).collection('notifications');

  @override
  Stream<List<AppNotification>> watchNotifications(String userId) {
    // Requête SIMPLE (pas de orderBy composite) : tri en mémoire, cohérent
    // avec la convention du reste du projet (évite tout besoin d'index
    // composite dédié sur cette sous-collection).
    return _notifications(userId).snapshots().map((snap) {
      final items = snap.docs
          .map((d) => AppNotification.fromJson(d.id, userId, d.data()))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    });
  }

  @override
  Stream<int> watchUnreadCount(String userId) {
    return _notifications(userId)
        .where('is_read', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  @override
  Future<void> markAsRead(String userId, String notificationId) async {
    await _notifications(userId).doc(notificationId).update({
      'is_read': true,
    });
  }

  @override
  Future<void> markAllAsRead(String userId) async {
    final unread =
        await _notifications(userId).where('is_read', isEqualTo: false).get();
    if (unread.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in unread.docs) {
      batch.update(doc.reference, {'is_read': true});
    }
    await batch.commit();
  }
}
