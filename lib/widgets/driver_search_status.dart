import 'package:flutter/material.dart';
import '../services/booking/booking_api.dart';

class DriverSearchStatus extends StatefulWidget {
  const DriverSearchStatus({
    super.key,
    required this.missionId,
    required this.state,
    required this.locale,
    required this.api,
  });
  final String missionId, state, locale;
  final BookingApi api;
  @override
  State<DriverSearchStatus> createState() => _DriverSearchStatusState();
}

class _DriverSearchStatusState extends State<DriverSearchStatus> {
  bool _busy = false;
  String? _error;
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  @override
  Widget build(BuildContext context) {
    final unavailable = widget.state == 'no_driver_available';
    final review = widget.state == 'schedule_requires_review';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(unavailable ? Icons.event_busy : Icons.search, size: 40),
          Text(
            unavailable
                ? tr(
                    'Aucun chauffeur disponible actuellement',
                    'No driver available at this time',
                    'No hay conductor disponible en este momento',
                  )
                : review
                ? tr(
                    'Horaire à vérifier',
                    'Schedule needs review',
                    'Horario por revisar',
                  )
                : tr(
                    'Recherche de chauffeur en cours',
                    'Searching for a driver',
                    'Buscando conductor',
                  ),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            tr(
              'Votre créneau n’est pas confirmé tant qu’un chauffeur admissible n’a pas accepté.',
              'Your time slot is not confirmed until an eligible driver accepts.',
              'Tu horario no se confirma hasta que acepte un conductor apto.',
            ),
          ),
          if (unavailable)
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() {
                        _busy = true;
                        _error = null;
                      });
                      try {
                        await widget.api.call('retryDriverSearch', {
                          'missionId': widget.missionId,
                        });
                      } catch (_) {
                        if (mounted) {
                          setState(
                            () => _error = tr(
                              'La recherche n’a pas pu être relancée. Réessayez.',
                              'Unable to restart the search. Try again.',
                              'No se pudo reiniciar la búsqueda. Reintenta.',
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _busy = false);
                      }
                    },
              child: Text(
                tr('Relancer la recherche', 'Search again', 'Buscar de nuevo'),
              ),
            ),
          if (review || unavailable)
            SelectableText(
              tr(
                'Pour modifier le rendez-vous, contactez info@movi-k.com ou préparez une demande révisée.',
                'To change the appointment, contact info@movi-k.com or prepare a revised request.',
                'Para cambiar la cita, contacta con info@movi-k.com o prepara una solicitud revisada.',
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          if (_error != null) Semantics(liveRegion: true, child: Text(_error!)),
        ],
      ),
    );
  }
}
