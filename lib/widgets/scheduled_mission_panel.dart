import 'booking_load_summary.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import '../backend/models/delivery_mission.dart';
import '../services/booking/booking_api.dart';
import 'driver_slot_confirmation.dart';

class ScheduledMissionPanel extends StatefulWidget {
  const ScheduledMissionPanel({
    super.key,
    required this.mission,
    required this.locale,
    this.api,
    this.onStart,
    this.isDriver = false,
  });
  final DeliveryMission mission;
  final String locale;
  final BookingApi? api;
  final Future<void> Function()? onStart;
  final bool isDriver;
  @override
  State<ScheduledMissionPanel> createState() => _ScheduledMissionPanelState();
}

class _ScheduledMissionPanelState extends State<ScheduledMissionPanel> {
  Timer? _timer;
  bool _busy = false;
  String? _error;
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> run(Future<void> Function() task) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await task();
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'La modification n’a pas été confirmée. Rechargez la mission et vérifiez le créneau.',
            'The change was not confirmed. Reload the mission and check the time slot.',
            'El cambio no se confirmó. Recarga la misión y comprueba el período.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.mission, s = m.scheduling!;
    final start = DateTime.parse(s['start'] as String).toLocal(),
        end = DateTime.parse(s['end'] as String).toLocal();
    final now = DateTime.now();
    final paymentReady =
        m.isInternalTest ||
        ['authorized', 'captured'].contains(m.paymentStatus);
    final canStart = paymentReady && !now.isBefore(start) && now.isBefore(end);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.event_available, size: 40),
          Text(
            paymentReady
                ? tr(
                    'Mission programmée',
                    'Scheduled mission',
                    'Misión programada',
                  )
                : tr(
                    'Attribution en cours de validation',
                    'Assignment being validated',
                    'Asignación en validación',
                  ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            '${tr('Créneau réservé', 'Reserved period', 'Período reservado')} : $start → $end',
          ),
          Text(
            '${tr('Durée réservée', 'Reserved duration', 'Duración reservada')} : ${end.difference(start).inMinutes} min',
          ),
          if (!paymentReady)
            Text(
              tr(
                'Le créneau est retenu. La validation du paiement reste à terminer avant le départ.',
                'The slot is held. Payment validation must finish before departure.',
                'El período está retenido. Falta validar el pago antes de salir.',
              ),
            ),
          Text(m.description),
          if (m.bookingSnapshot != null)
            BookingLoadSummary(
              snapshot: m.bookingSnapshot!,
              locale: widget.locale,
            ),
          if (m.pickupAddress != null)
            Text(
              '${tr('Ramassage', 'Pickup', 'Recogida')} : ${m.pickupAddress!.line1}, ${m.pickupAddress!.city}',
            ),
          if (m.dropoffAddress != null)
            Text(
              '${tr('Livraison', 'Delivery', 'Entrega')} : ${m.dropoffAddress!.line1}, ${m.dropoffAddress!.city}',
            ),
          if (m.driverDisplayName != null)
            Text(
              '${tr('Chauffeur attribué', 'Assigned driver', 'Conductor asignado')} : ${m.driverDisplayName}',
            ),
          Text(
            tr(
              'Le suivi de position commencera au départ du chauffeur.',
              'Location tracking will start when the driver departs.',
              'El seguimiento comenzará cuando salga el conductor.',
            ),
          ),
          if (widget.isDriver)
            Text(
              '${tr('Rémunération enregistrée', 'Recorded compensation', 'Remuneración registrada')} : ${m.driverOfferAmount.toStringAsFixed(2)} CAD',
            ),
          if (widget.isDriver) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy || !canStart || widget.onStart == null
                  ? null
                  : () => run(widget.onStart!),
              icon: const Icon(Icons.play_arrow),
              label: Text(
                tr('Démarrer la mission', 'Start mission', 'Iniciar misión'),
              ),
            ),
            if (paymentReady && !canStart)
              Text(
                now.isBefore(start)
                    ? tr(
                        'Le démarrage sera disponible au début du créneau.',
                        'Starting becomes available at the beginning of the slot.',
                        'Podrás iniciar al comienzo del período.',
                      )
                    : tr(
                        'Ce créneau est dépassé. Faites vérifier la réservation avant de démarrer.',
                        'This slot has passed. Have the booking reviewed before starting.',
                        'Este período ha terminado. Solicita la revisión de la reserva antes de iniciar.',
                      ),
              ),
            OutlinedButton(
              onPressed: _busy || widget.api == null
                  ? null
                  : () => run(() async {
                      final next = await confirmDriverSlot(
                        context,
                        locale: widget.locale,
                        preparation: {
                          'requested_at': s['pickup_at'],
                          'policy_version': s['policy_version'],
                          'route_minutes': m.estimatedDurationMinutes,
                          'driver_offer_minor': (m.driverOfferAmount * 100)
                              .round(),
                        },
                      );
                      if (next == null) return;
                      final calendars = await widget.api!.call(
                        'getDriverCalendars',
                      );
                      if ((calendars['connections'] as List? ?? [])
                          .isNotEmpty) {
                        await widget.api!.call('refreshDriverCalendars', {
                          'start': next['start'],
                          'end': next['end'],
                        });
                      }
                      await widget.api!.call('adjustDriverMissionSlot', {
                        'missionId': m.id,
                        'expectedStart': s['start'],
                        'expectedEnd': s['end'],
                        'reservation': next,
                      });
                    }),
              child: Text(
                tr(
                  'Ajuster le temps réservé',
                  'Adjust reserved time',
                  'Ajustar tiempo reservado',
                ),
              ),
            ),
            Text(
              tr(
                'L’heure de ramassage du client reste inchangée. Un autre rendez-vous exige une demande révisée.',
                'The customer’s pickup time remains unchanged. A different appointment requires a revised request.',
                'La hora de recogida no cambia. Otra cita requiere una solicitud revisada.',
              ),
            ),
          ],
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        ],
      ),
    );
  }
}
