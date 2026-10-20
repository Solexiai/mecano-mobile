import 'package:flutter/material.dart';
import '../backend/repositories/driver_agenda_repository.dart';
import '../services/booking/booking_api.dart';

class DriverAvailabilityPreview extends StatefulWidget {
  const DriverAvailabilityPreview({
    super.key,
    required this.api,
    required this.agenda,
    required this.from,
    required this.to,
    required this.locale,
  });
  final BookingApi api;
  final DriverAgenda agenda;
  final DateTime from, to;
  final String locale;
  @override
  State<DriverAvailabilityPreview> createState() =>
      _DriverAvailabilityPreviewState();
}

class _DriverAvailabilityPreviewState extends State<DriverAvailabilityPreview> {
  late Future<Map<String, dynamic>> _result;
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void didUpdateWidget(covariant DriverAvailabilityPreview old) {
    super.didUpdateWidget(old);
    if (old.api != widget.api ||
        old.agenda != widget.agenda ||
        old.from != widget.from ||
        old.to != widget.to) {
      load();
    }
  }

  void load() {
    _result = widget.api.call('previewDriverAvailability', {
      'period': {
        'start': widget.from.toUtc().toIso8601String(),
        'end': widget.to.toUtc().toIso8601String(),
      },
      'agenda': {
        'windows': widget.agenda.windows.map((s) => s.toJson()).toList(),
        'blocked': widget.agenda.blocked.map((s) => s.toJson()).toList(),
        'recurrence': widget.agenda.recurrence,
      },
    });
  }

  String date(dynamic s) {
    final d = DateTime.parse(s as String).toLocal();
    return '${d.day}/${d.month} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _result,
    builder: (context, s) {
      if (s.hasError) {
        return TextButton(
          onPressed: () => setState(load),
          child: Text(
            tr(
              'Recharger les périodes et conflits',
              'Reload periods and conflicts',
              'Recargar períodos y conflictos',
            ),
          ),
        );
      }
      if (!s.hasData) return const LinearProgressIndicator();
      final data = s.data!;
      return ExpansionTile(
        initiallyExpanded: true,
        title: Text(
          tr(
            'Disponibilités de la période',
            'Availability for this period',
            'Disponibilidad del período',
          ),
        ),
        children: [
          for (final category in [
            (
              'windows',
              tr('Disponible', 'Available', 'Disponible'),
              Icons.event_available,
            ),
            (
              'blocked',
              tr('Blocage manuel', 'Manual block', 'Bloqueo manual'),
              Icons.event_busy,
            ),
            (
              'external_busy',
              tr(
                'Calendrier externe occupé',
                'External calendar busy',
                'Calendario externo ocupado',
              ),
              Icons.lock_clock,
            ),
            (
              'occupied',
              tr('Mission réservée', 'Reserved mission', 'Misión reservada'),
              Icons.local_shipping,
            ),
          ])
            for (final period in data[category.$1] as List? ?? [])
              ListTile(
                leading: Icon(
                  period['conflict'] == true
                      ? Icons.warning_amber
                      : category.$3,
                ),
                title: Text(
                  period['conflict'] == true
                      ? tr(
                          'Conflit à vérifier',
                          'Conflict to review',
                          'Conflicto por revisar',
                        )
                      : category.$2,
                ),
                subtitle: Text(
                  '${date(period['start'])} → ${date(period['end'])}',
                ),
              ),
          if ((data['windows'] as List).isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                tr(
                  'Aucune plage disponible déclarée sur cette période.',
                  'No declared availability in this period.',
                  'No hay disponibilidad declarada en este período.',
                ),
              ),
            ),
        ],
      );
    },
  );
}
