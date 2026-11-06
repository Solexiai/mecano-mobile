// ---------------------------------------------------------------------------
// DriverHomeHero — en-tête de l'accueil chauffeur « style Uber » (2026-11-06).
//
// Un seul geste pour commencer sa journée : le gros bouton GO. L'état de
// service (hors service / en service / en mission) est dit en toutes
// lettres, avec la prochaine action attendue. Le Switch de l'AppBar reste
// en place : ce widget appelle exactement la même bascule
// (`setDriverOnlineStatus`), il n'ajoute aucune règle.
//
// Pas de ElevatedButton ici : les tests de l'onglet Accueil comptent les
// ElevatedButton pour retrouver le bouton « Accepter » d'une offre. Pas de
// CircularProgressIndicator non plus : une animation infinie empêcherait
// `pumpAndSettle` de se stabiliser pendant une bascule en cours.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';

class DriverHomeHero extends StatelessWidget {
  const DriverHomeHero({
    super.key,
    required this.profile,
    required this.t,
    required this.onToggle,
    this.toggling = false,
  });

  /// Profil courant (null tant que le flux n'a rien émis).
  final DriverProfileV2? profile;
  final String Function(String) t;

  /// Même bascule que le Switch de l'AppBar (`true` = passer en service).
  final ValueChanged<bool> onToggle;
  final bool toggling;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final status = p?.onlineStatus ?? DriverOnlineStatus.offline;
    final canGoOnline = p?.status.canGoOnline ?? false;
    final online = status == DriverOnlineStatus.online;
    final onMission = status == DriverOnlineStatus.onMission;

    final String title;
    final String subtitle;
    if (onMission) {
      title = t('driver_home_on_mission_title');
      subtitle = t('driver_home_on_mission_subtitle');
    } else if (online) {
      title = t('driver_home_online_title');
      subtitle = t('driver_home_online_subtitle');
    } else {
      title = t('driver_home_offline_title');
      subtitle = canGoOnline
          ? t('driver_home_offline_subtitle')
          : t('driver_home_not_approved_subtitle');
    }

    final dotColor = onMission
        ? AppColors.warning
        : online
        ? AppColors.glowGreen
        : AppColors.textOnDarkSecondary;

    return Container(
      key: const ValueKey('driver-home-hero'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: dotColor,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  key: const ValueKey('driver-home-hero-title'),
                  style: const TextStyle(
                    color: AppColors.textOnDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textOnDarkSecondary,
              fontSize: 13.5,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          Center(
            child: onMission
                ? const SizedBox.shrink()
                : online
                ? _OfflinePill(
                    label: t('driver_home_go_offline'),
                    busy: toggling,
                    onTap: toggling ? null : () => onToggle(false),
                  )
                : _GoButton(
                    label: t('driver_home_go'),
                    busy: toggling,
                    onTap: (toggling || !canGoOnline)
                        ? null
                        : () => onToggle(true),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Gros bouton rond vert « GO » (Uber-like). Grisé si le dossier n'est pas
/// approuvé : le serveur refuse de toute façon un chauffeur non approuvé.
class _GoButton extends StatelessWidget {
  const _GoButton({required this.label, required this.onTap, this.busy = false});
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? AppColors.success : AppColors.borderDark,
        shape: const CircleBorder(),
        elevation: enabled ? 6 : 0,
        shadowColor: AppColors.success.withValues(alpha: 0.6),
        child: InkWell(
          key: const ValueKey('driver-home-go-button'),
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 96,
            height: 96,
            child: Center(
              // Pas de spinner animé : pendant la bascule, le bouton est
              // simplement désactivé (les tests du shell attendent que
              // l'écran se stabilise après un tap sur le Switch).
              child: busy
                  ? const Icon(
                      Icons.hourglass_top,
                      key: ValueKey('driver-home-go-busy'),
                      color: Colors.white,
                      size: 30,
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: enabled
                            ? Colors.white
                            : AppColors.textOnDarkSecondary,
                        fontWeight: FontWeight.w800,
                        fontSize: 28,
                        letterSpacing: 1,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Pilule « Passer hors service » affichée quand le chauffeur est en ligne.
class _OfflinePill extends StatelessWidget {
  const _OfflinePill({
    required this.label,
    required this.onTap,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(26),
      child: InkWell(
        key: const ValueKey('driver-home-offline-button'),
        borderRadius: BorderRadius.circular(26),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (busy)
                const Icon(
                  Icons.hourglass_top,
                  size: 18,
                  color: AppColors.textSecondary,
                )
              else
                const Icon(
                  Icons.power_settings_new,
                  size: 18,
                  color: AppColors.error,
                ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
