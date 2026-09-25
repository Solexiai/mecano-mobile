import 'package:flutter/material.dart';
import '../backend/models/delivery_mission.dart';
import '../backend/models/delivery_offer.dart';
import '../backend/repositories/mission_repository.dart';

/// One visual offer. The owner manages lifecycle, deduplication and expiry.
/// All mutations are delegated to the existing repository/server boundary.
class DriverOfferAlert extends StatefulWidget {
  final DeliveryOffer offer;
  final DeliveryMission mission;
  final int secondsRemaining;
  final String Function(String) t;
  final Future<AcceptMissionResult> Function() onAccept;
  final Future<void> Function() onDecline;
  final VoidCallback onAccepted;
  final VoidCallback onDismiss;
  const DriverOfferAlert({super.key, required this.offer, required this.mission,
    required this.secondsRemaining, required this.t, required this.onAccept,
    required this.onDecline, required this.onAccepted, required this.onDismiss});
  @override
  State<DriverOfferAlert> createState() => _DriverOfferAlertState();
}

class _DriverOfferAlertState extends State<DriverOfferAlert> {
  bool _busy = false;
  bool _details = false;
  bool _failed = false;
  Future<void> _respond(bool accept) async {
    if (_busy || widget.secondsRemaining <= 0) return;
    setState(() { _busy = true; _failed = false; });
    try {
      if (accept) {
        final result = await widget.onAccept();
        if (!mounted) return;
        if (result.success) { widget.onAccepted(); return; }
        setState(() => _failed = true);
      } else {
        await widget.onDecline();
        if (mounted) widget.onDismiss();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final m = widget.mission;
    final disabled = _busy || widget.secondsRemaining <= 0;
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(t('notif_delivery_offer_title'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(t(m.itemCategoryKey)),
            Text('${m.pickupAddress?.city ?? ""} → ${m.dropoffAddress?.city ?? ""}'),
            const SizedBox(height: 8),
            Text('${t('driver_offer_time_left')} ${widget.secondsRemaining} s'),
            if (widget.offer.pickupDistanceKm != null)
              Text('${t('driver_offer_distance')} ${widget.offer.pickupDistanceKm!.toStringAsFixed(1)} km'),
            if (_details) ...[
              const Divider(),
              Text(m.description),
              Text('${t('driver_active_mission_pickup')} : ${m.pickupAddress?.line1 ?? ""}'),
              Text('${t('driver_active_mission_dropoff')} : ${m.dropoffAddress?.line1 ?? ""}'),
            ],
            TextButton(onPressed: _busy ? null : () => setState(() => _details = !_details),
              child: Text(t('driver_offer_details'))),
            if (_failed) Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Text(t('driver_offer_action_error'), style: TextStyle(color: Theme.of(context).colorScheme.error))),
            Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [
              TextButton(onPressed: _busy ? null : widget.onDismiss, child: Text(t('driver_offer_close'))),
              OutlinedButton(onPressed: disabled ? null : () => _respond(false), child: Text(t('driver_offer_decline'))),
              FilledButton(onPressed: disabled ? null : () => _respond(true), child: _busy
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t('driver_offer_accept'))),
            ]),
          ]),
        ),
      ),
    );
  }
}
