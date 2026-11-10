// Écran d'offre plein écran « qui sonne » (2026-11-09, « comme Uber »).
//
// Affiché par l'onglet Demandes quand une nouvelle offre arrive pendant que
// le chauffeur est en service. Il montre en premier ce qui compte (le
// montant), puis le trajet, et un compte à rebours jusqu'à l'expiration de
// l'offre. Sonnerie + vibration en boucle (DriverOfferAlerts.player) au plus
// `DriverOfferAlerts.maxRing`, arrêtées dès la réponse.
//
// Le résultat est rendu à l'appelant, qui réutilise SES chemins d'acceptation
// et de refus existants (dialogues, serveur, erreurs) : cet écran ne parle
// jamais au serveur lui-même.
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../backend/models/delivery_mission.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../services/driver_offer_alerts.dart';

enum DriverOfferAlertChoice { accept, decline, details, expired }

/// Ouvre l'écran d'offre et attend la réponse du chauffeur.
Future<DriverOfferAlertChoice> showDriverOfferAlert(
  BuildContext context, {
  required DeliveryMission mission,
  required String Function(String) t,
  DateTime Function()? now,
}) async {
  final choice = await showGeneralDialog<DriverOfferAlertChoice>(
    context: context,
    barrierDismissible: false,
    barrierLabel: t('driver_offer_new'),
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogContext, animation, secondaryAnimation) => DriverOfferAlert(mission: mission, t: t, now: now),
  );
  return choice ?? DriverOfferAlertChoice.details;
}

class DriverOfferAlert extends StatefulWidget {
  const DriverOfferAlert({super.key, required this.mission, required this.t, this.now});

  final DeliveryMission mission;
  final String Function(String) t;

  /// Horloge injectable (tests).
  final DateTime Function()? now;

  @override
  State<DriverOfferAlert> createState() => _DriverOfferAlertState();
}

class _DriverOfferAlertState extends State<DriverOfferAlert> {
  Timer? _tick;
  Timer? _ringLimit;
  bool _ringing = false;
  bool _closed = false;
  late final DateTime _shownAt;

  DateTime _now() => (widget.now ?? DateTime.now)();

  DateTime? get _expiresAt => widget.mission.offerExpiresAt;

  Duration? get _remaining {
    final exp = _expiresAt;
    if (exp == null) return null;
    final left = exp.difference(_now());
    return left.isNegative ? Duration.zero : left;
  }

  @override
  void initState() {
    super.initState();
    _shownAt = _now();
    _ringing = true;
    DriverOfferAlerts.player.start();
    _ringLimit = Timer(DriverOfferAlerts.maxRing, _stopRinging);
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _remaining;
      if (left != null && left == Duration.zero) {
        _close(DriverOfferAlertChoice.expired);
        return;
      }
      setState(() {});
    });
  }

  void _stopRinging() {
    if (!_ringing) return;
    _ringing = false;
    DriverOfferAlerts.player.stop();
  }

  void _close(DriverOfferAlertChoice choice) {
    if (_closed) return;
    _closed = true;
    _stopRinging();
    _tick?.cancel();
    _ringLimit?.cancel();
    Navigator.of(context).pop(choice);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _ringLimit?.cancel();
    _stopRinging();
    super.dispose();
  }

  String _clock(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final m = widget.mission;
    final hasAmount = m.driverOfferAmount > 0;
    final left = _remaining;
    final exp = _expiresAt;
    final total = exp?.difference(_shownAt);
    final progress = (left == null || total == null || total.inMilliseconds <= 0)
        ? null
        : (left.inMilliseconds / total.inMilliseconds).clamp(0.0, 1.0);

    return Material(
      key: const ValueKey('driver-offer-alert'),
      color: AppColors.primary,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Icon(Icons.notifications_active, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      t('driver_offer_new'),
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (left != null)
                    SizedBox(
                      width: 64,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Toujours déterminé (jamais d'animation infinie).
                          CircularProgressIndicator(
                            value: progress ?? 0,
                            strokeWidth: 5,
                            color: AppColors.success,
                            backgroundColor: Colors.white24,
                          ),
                          Text(
                            _clock(left),
                            key: const ValueKey('driver-offer-alert-countdown'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const Spacer(),
              Text(
                hasAmount ? '${m.driverOfferAmount.toStringAsFixed(2)} \$' : t('driver_offer_alert_amount_pending'),
                key: const ValueKey('driver-offer-alert-amount'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: hasAmount ? 54 : 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                hasAmount ? t('driver_offer_alert_for_you') : t('driver_offer_share_on_accept'),
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: 24),
              _Stats(mission: m, t: t),
              const SizedBox(height: 20),
              if (m.pickupAddress != null && m.dropoffAddress != null) ...[
                _Stop(
                  icon: Icons.trip_origin,
                  label: t('driver_offer_pickup'),
                  value: '${m.pickupAddress!.line1}, ${m.pickupAddress!.city}',
                ),
                const SizedBox(height: 10),
                _Stop(
                  icon: Icons.place,
                  label: t('driver_offer_dropoff'),
                  value: '${m.dropoffAddress!.line1}, ${m.dropoffAddress!.city}',
                ),
              ] else
                Text(
                  t('driver_offer_addresses_pending'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              const Spacer(),
              SizedBox(
                height: 60,
                child: ElevatedButton(
                  key: const ValueKey('driver-offer-alert-accept'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => _close(DriverOfferAlertChoice.accept),
                  child: Text(t('driver_offer_alert_accept')),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('driver-offer-alert-decline'),
                      onPressed: () => _close(DriverOfferAlertChoice.decline),
                      child: Text(t('driver_offer_alert_decline'), style: const TextStyle(color: Colors.white70)),
                    ),
                  ),
                  Expanded(
                    child: TextButton(
                      key: const ValueKey('driver-offer-alert-details'),
                      onPressed: () => _close(DriverOfferAlertChoice.details),
                      child: Text(t('driver_offer_alert_details'), style: const TextStyle(color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stats extends StatelessWidget {
  const _Stats({required this.mission, required this.t});
  final DeliveryMission mission;
  final String Function(String) t;

  @override
  Widget build(BuildContext context) {
    final items = <(String, String)>[
      if (mission.distanceKm != null) (t('driver_offer_trip'), '${mission.distanceKm!.toStringAsFixed(1)} km'),
      if (mission.estimatedDurationMinutes != null)
        (t('driver_offer_duration'), '~${mission.estimatedDurationMinutes!.round()} min'),
      (t('driver_offer_vehicle'), t(mission.requiredVehicleCategory.key)),
    ];
    return Row(
      children: [
        for (final (label, value) in items)
          Expanded(
            child: Column(
              children: [
                Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              ],
            ),
          ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
              Text(
                value.isEmpty ? '—' : value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
