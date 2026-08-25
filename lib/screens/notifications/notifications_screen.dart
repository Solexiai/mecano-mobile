// ---------------------------------------------------------------------------
// NotificationsScreen — liste des notifications de l'utilisateur courant
// (Phase 5, partie 3, point 12).
//
// Simple mais réellement fonctionnel : compteur non lu, liste triée
// (récent -> ancien), état lu/non-lu visuellement distinct, date/heure,
// message traduit (résolu via titleKey/bodyKey + LocaleProvider.t()),
// tap -> markAsRead + navigation vers la mission liée si `missionId` est
// présent. La destination de navigation dépend du rôle de l'utilisateur
// courant (client -> suivi mission, chauffeur -> mission active).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../backend/backend_locator.dart';
import '../../backend/models/app_notification.dart';
import '../../core/app_colors.dart';
import '../../models/enums.dart';
import '../../providers/firebase_auth_provider.dart';
import '../../providers/locale_provider.dart';

class NotificationsScreen extends StatelessWidget {
  final String userId;
  const NotificationsScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;
    final auth = context.watch<FirebaseAuthProvider>();
    final isDriver = auth.hasRole(PlatformRole.driver);

    return Scaffold(
      appBar: AppBar(
        title: Text(t('notifications_title')),
        actions: [
          TextButton(
            onPressed: () =>
                BackendLocator.notificationRepository.markAllAsRead(userId),
            child: Text(
              t('notifications_mark_all_read'),
              style: const TextStyle(fontSize: 12.5),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<AppNotification>>(
          stream: BackendLocator.notificationRepository.watchNotifications(userId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(t('notifications_loading')),
                  ],
                ),
              );
            }
            if (snap.hasError) {
              return Center(child: Text(t('notifications_error')));
            }
            final items = snap.data ?? const [];
            if (items.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.notifications_none, size: 44, color: AppColors.textSecondary),
                      const SizedBox(height: 16),
                      Text(t('notifications_empty'), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final n = items[i];
                return _NotificationTile(
                  notification: n,
                  t: t,
                  onTap: () {
                    if (!n.isRead) {
                      // Phase 7, Bloc G (gap G-4) : `markAsRead()` est une
                      // écriture Firestore directe (pas de Cloud Function)
                      // qui peut échouer (réseau, permission transitoire).
                      // AVANT ce correctif, l'échec remontait comme
                      // exception non gérée (Future rejetée jamais
                      // catchée) et faisait planter le test/l'app. Le
                      // marquage lu/non-lu est un confort UX secondaire :
                      // son échec ne doit JAMAIS bloquer la navigation vers
                      // la mission liée, qui reste l'action principale de
                      // ce tap.
                      BackendLocator.notificationRepository
                          .markAsRead(userId, n.id)
                          .catchError((_) {});
                    }
                    final missionId = n.missionId;
                    if (missionId == null || missionId.isEmpty) return;
                    if (isDriver) {
                      context.go('/$locale/fournisseur/mission/$missionId');
                    } else {
                      context.go('/$locale/livraison/suivi/$missionId');
                    }
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final AppNotification notification;
  final String Function(String) t;
  final VoidCallback onTap;
  const _NotificationTile({
    required this.notification,
    required this.t,
    required this.onTap,
  });

  String _formatDateTime(DateTime dt) {
    final local = dt.toLocal();
    final now = DateTime.now();
    if (now.difference(local).inMinutes < 1) return t('notifications_just_now');
    final d = local.day.toString().padLeft(2, '0');
    final m = local.month.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$d/$m à $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread
              ? AppColors.info.withValues(alpha: 0.08)
              : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread ? AppColors.info.withValues(alpha: 0.35) : AppColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 5),
              decoration: BoxDecoration(
                color: unread ? AppColors.info : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t(notification.titleKey),
                    style: TextStyle(
                      fontWeight: unread ? FontWeight.w800 : FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    t(notification.bodyKey),
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDateTime(notification.createdAt),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            if (notification.missionId != null)
              const Icon(Icons.chevron_right, color: AppColors.textSecondary, size: 20),
          ],
        ),
      ),
    );
  }
}
