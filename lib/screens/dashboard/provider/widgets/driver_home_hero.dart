// ---------------------------------------------------------------------------
// DriverHomeHero — en-tête de l'accueil chauffeur « style Uber » (2026-11-06).
//
// Un seul geste pour commencer sa journée : le gros bouton GO. L'état de
// service (hors service / en service / en mission) est dit en toutes
// lettres, avec la prochaine action attendue. Le Switch de l'AppBar reste
// en place : ce widget appelle exactement la même bascule
// (`setDriverOnlineStatus`), il n'ajoute aucune règle.
//
// Phase 3 (2026-11-06) : quand le profil a une adresse de base géolocalisée,
// la carte OpenStreetMap de la zone de service (rayon du chauffeur) sert de
// fond, comme sur Uber. Carte figée (pas de zoom/déplacement) : c'est un
// décor qui situe le chauffeur, pas un outil de navigation.
//
// 2026-11-07 (demande de Daniel, « comme Uber ») : point bleu « Vous êtes
// ici » = dernière position GPS connue (driver_locations/{uid}). Quand le
// chauffeur est hors de sa zone (à Terrebonne avec une base à Granby), la
// carte s'élargit pour montrer la zone ET le chauffeur, sinon elle reste
// centrée sur la zone. La position n'est pas une règle : le serveur décide
// seul du dispatch (GPS frais, sinon adresse de base).
//
// Pas de ElevatedButton ici : les tests de l'onglet Accueil comptent les
// ElevatedButton pour retrouver le bouton « Accepter » d'une offre. Pas de
// CircularProgressIndicator non plus : une animation infinie empêcherait
// `pumpAndSettle` de se stabiliser pendant une bascule en cours.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

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
    this.livePosition,
  });

  /// Dernière position GPS connue (null = inconnue ou trop ancienne).
  final ll.LatLng? livePosition;

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

    final Widget action = onMission
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
            onTap: (toggling || !canGoOnline) ? null : () => onToggle(true),
          );

    final base = (p?.baseLat != null && p?.baseLng != null)
        ? ll.LatLng(p!.baseLat!, p.baseLng!)
        : null;

    if (base != null) {
      return _MapHero(
        center: base,
        livePosition: livePosition,
        youAreHere: t('driver_home_you_are_here'),
        radiusKm: p!.serviceRadiusKm,
        online: online,
        dotColor: dotColor,
        title: title,
        subtitle: subtitle,
        action: action,
      );
    }

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
          _StatusLine(dotColor: dotColor, title: title, subtitle: subtitle),
          const SizedBox(height: 18),
          Center(child: action),
        ],
      ),
    );
  }
}

/// Carte de la zone de service en fond, état et bouton par-dessus.
class _MapHero extends StatelessWidget {
  const _MapHero({
    required this.center,
    required this.livePosition,
    required this.youAreHere,
    required this.radiusKm,
    required this.online,
    required this.dotColor,
    required this.title,
    required this.subtitle,
    required this.action,
  });

  final ll.LatLng center;
  final ll.LatLng? livePosition;
  final String youAreHere;
  final double radiusKm;
  final bool online;
  final Color dotColor;
  final String title;
  final String subtitle;
  final Widget action;

  /// Zoom qui montre à peu près le rayon de service.
  double get _zoom => radiusKm <= 10
      ? 11
      : radiusKm <= 20
      ? 10
      : radiusKm <= 45
      ? 9
      : 8;

  /// Hors zone = plus loin que le rayon de service (vol d'oiseau).
  bool get _outsideZone {
    final live = livePosition;
    if (live == null) return false;
    return const ll.Distance().as(ll.LengthUnit.Kilometer, center, live) > radiusKm;
  }

  /// La carte est figée : on ne la recadre qu'en changeant sa clé, et
  /// seulement quand le chauffeur entre ou sort de sa zone (pas à chaque
  /// relevé GPS, qui ferait clignoter les tuiles).
  String get _mapKey => _outsideZone ? 'driver-home-map-wide' : 'driver-home-map';

  @override
  Widget build(BuildContext context) {
    final zoneColor = online ? AppColors.success : AppColors.primary;
    final live = livePosition;
    final outside = _outsideZone;
    return ClipRRect(
      key: const ValueKey('driver-home-hero'),
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        height: 300,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FlutterMap(
              key: ValueKey(_mapKey),
              options: MapOptions(
                initialCenter: center,
                initialZoom: _zoom,
                // Hors zone : on montre la zone et le chauffeur ensemble.
                initialCameraFit: outside && live != null
                    ? CameraFit.bounds(
                        bounds: LatLngBounds(center, live),
                        padding: const EdgeInsets.fromLTRB(40, 110, 40, 90),
                      )
                    : null,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.movik.movik_connect',
                ),
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: center,
                      radius: radiusKm * 1000,
                      useRadiusInMeter: true,
                      color: zoneColor.withValues(alpha: 0.12),
                      borderColor: zoneColor.withValues(alpha: 0.55),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: center,
                      width: 22,
                      height: 22,
                      child: Container(
                        decoration: BoxDecoration(
                          color: zoneColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                      ),
                    ),
                    if (live != null)
                      Marker(
                        point: live,
                        width: 140,
                        height: 64,
                        alignment: Alignment.topCenter,
                        child: Column(
                          key: const ValueKey('driver-home-live-dot'),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: AppColors.info,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 3),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                youAreHere,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            // État en haut, sur un bandeau lisible quelle que soit la carte.
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      AppColors.primaryDark.withValues(alpha: 0.92),
                      AppColors.primaryDark.withValues(alpha: 0.0),
                    ],
                  ),
                ),
                child: _StatusLine(
                  dotColor: dotColor,
                  title: title,
                  subtitle: subtitle,
                ),
              ),
            ),
            Positioned(left: 0, right: 0, bottom: 18, child: Center(child: action)),
          ],
        ),
      ),
    );
  }
}

/// Point d'état + titre + sous-titre, sur fond sombre.
class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.dotColor,
    required this.title,
    required this.subtitle,
  });
  final Color dotColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
      ],
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
