// ---------------------------------------------------------------------------
// NotificationBell — icône 🔔 réutilisable pour les AppBar des dashboards
// client/chauffeur (Phase 5, partie 3, point 12).
//
// Affiche un badge avec le nombre de notifications non lues
// (NotificationRepository.watchUnreadCount) et ouvre la route
// /{locale}/notifications au tap. Ne fait AUCUNE hypothèse sur le rôle de
// l'utilisateur — fonctionne identiquement pour un customer ou un driver,
// le repository filtre déjà par `userId` (protégé par firestore.rules).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../backend/backend_locator.dart';
import '../providers/locale_provider.dart';

class NotificationBell extends StatelessWidget {
  final String userId;
  const NotificationBell({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    final localeProvider = context.watch<LocaleProvider>();
    final t = localeProvider.t;
    final locale = localeProvider.locale;
    return StreamBuilder<int>(
      stream: BackendLocator.notificationRepository.watchUnreadCount(userId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              key: const Key('notification-bell-button'),
              icon: const Icon(Icons.notifications_outlined),
              tooltip: t('notifications_open_tooltip'),
              onPressed: () => context.push('/$locale/notifications'),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
