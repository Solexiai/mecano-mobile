// ---------------------------------------------------------------------------
// NotificationBell — icône 🔔 réutilisable pour les AppBar des dashboards
// client/chauffeur (Phase 5, partie 3, point 12).
//
// Affiche un badge avec le nombre de notifications non lues
// (NotificationRepository.watchUnreadCount) et ouvre NotificationsScreen au
// tap. Ne fait AUCUNE hypothèse sur le rôle de l'utilisateur — fonctionne
// identiquement pour un customer ou un driver, le repository filtre déjà
// par `userId` (protégé par firestore.rules).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../backend/backend_locator.dart';
import '../screens/notifications/notifications_screen.dart';

class NotificationBell extends StatelessWidget {
  final String userId;
  const NotificationBell({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: BackendLocator.notificationRepository.watchUnreadCount(userId),
      builder: (context, snap) {
        final count = snap.data ?? 0;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NotificationsScreen(userId: userId),
                ),
              ),
            ),
            if (count > 0)
              Positioned(
                right: 6,
                top: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
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
