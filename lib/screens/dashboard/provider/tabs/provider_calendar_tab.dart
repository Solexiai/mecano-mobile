import '../../../../widgets/driver_availability_preview.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/booking/booking_api.dart';
import '../../../../widgets/driver_recurrence_editor.dart';
import '../../../../widgets/driver_calendars_panel.dart';
import 'package:provider/provider.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../backend/repositories/driver_agenda_repository.dart';
import '../../../../core/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

class ProviderCalendarTab extends StatefulWidget {
  const ProviderCalendarTab({
    super.key,
    this.repository,
    this.locale,
    this.bookingApi,
  });
  final DriverAgendaRepository? repository;
  final String? locale;
  final BookingApi? bookingApi;
  @override
  State<ProviderCalendarTab> createState() => _ProviderCalendarTabState();
}

class _ProviderCalendarTabState extends State<ProviderCalendarTab> {
  DateTime _selected = DateTime.now();
  String _view = 'month';
  BookingApi? _calendarApi;
  DriverAgendaRepository? _repository;
  String? _uid;
  Stream<List<DeliveryMission>>? _missions;
  DriverAgenda? _agenda;
  bool _loading = true, _saving = false, _dirty = false;
  String? _error;
  String _locale = 'fr';
  int _generation = 0;
  String tr(String fr, String en, String es) => _locale == 'en'
      ? en
      : _locale == 'es'
      ? es
      : fr;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _locale = widget.locale ?? context.read<LocaleProvider>().locale;
    final uid = widget.repository != null
        ? 'injected'
        : context.watch<FirebaseAuthProvider>().effectiveUid;
    if (_repository == null || _uid != uid) {
      _uid = uid;
      _calendarApi =
          widget.bookingApi ??
          (uid != null && uid != 'injected' ? FirebaseBookingApi(uid) : null);
      _repository =
          widget.repository ??
          (uid == null
              ? const UnavailableDriverAgendaRepository()
              : driverAgendaRepository(uid));
      _missions = _repository!.watchMissions();
      _agenda = null;
      _saving = false;
      _dirty = false;
      _load();
    }
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final agenda = await _repository!.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _agenda = agenda;
        _dirty = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = tr(
            'Impossible de charger les disponibilités. Réessayez.',
            'Unable to load availability. Try again.',
            'No se pudo cargar la disponibilidad. Inténtalo de nuevo.',
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    if (_agenda == null || _saving) return;
    final generation = _generation;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final saved = await _repository!.save(_agenda!);
      if (!mounted || generation != _generation) return;
      setState(() {
        _agenda = saved;
        _dirty = false;
      });
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error = tr(
            'Enregistrement impossible. Vos modifications sont conservées. Si l’agenda a changé ailleurs, rechargez-le.',
            'Could not save. Your edits are kept. If the calendar changed elsewhere, reload it.',
            'No se pudo guardar. Se conservan los cambios. Si el calendario cambió en otro dispositivo, vuelve a cargarlo.',
          ),
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _saving = false);
    }
  }

  void _setSlots(bool blocked, List<AgendaInterval> slots) {
    final a = _agenda!;
    setState(() {
      _agenda = DriverAgenda(
        revision: a.revision,
        configured: a.configured,
        recurrence: a.recurrence,
        dispatchConnected: a.dispatchConnected,
        windows: blocked ? a.windows : slots,
        blocked: blocked ? slots : a.blocked,
      );
      _dirty = true;
    });
  }

  Future<DateTime?> _pickInstant(String help, DateTime initial) async {
    final day = await showDatePicker(
      context: context,
      helpText: help,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (day == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      helpText: help,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (time == null) return null;
    return DateTime(day.year, day.month, day.day, time.hour, time.minute);
  }

  Future<void> _add(bool blocked) async {
    final generation = _generation;
    final start = await _pickInstant(
      tr('Début de la plage', 'Start of period', 'Inicio del período'),
      DateTime.now(),
    );
    if (start == null || !mounted || generation != _generation) return;
    final end = await _pickInstant(
      tr('Fin de la plage', 'End of period', 'Fin del período'),
      start,
    );
    if (end == null || !mounted || generation != _generation) return;
    if (!end.isAfter(start)) {
      setState(
        () => _error = tr(
          'La fin doit suivre le début.',
          'End must be after start.',
          'El fin debe ser posterior al inicio.',
        ),
      );
      return;
    }
    _setSlots(blocked, [
      ...(blocked ? _agenda!.blocked : _agenda!.windows),
      AgendaInterval(start, end),
    ]);
  }

  String _date(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  Widget _slots(bool blocked) {
    final slots = blocked ? _agenda!.blocked : _agenda!.windows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          blocked
              ? tr(
                  'Périodes bloquées',
                  'Blocked periods',
                  'Períodos bloqueados',
                )
              : tr(
                  'Mes plages disponibles',
                  'My available periods',
                  'Mis períodos disponibles',
                ),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        for (var i = 0; i < slots.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${_date(slots[i].start)} → ${_date(slots[i].end)}'),
            trailing: IconButton(
              tooltip: tr(
                'Retirer cette plage',
                'Remove period',
                'Eliminar período',
              ),
              onPressed: _saving
                  ? null
                  : () => _setSlots(blocked, [...slots]..removeAt(i)),
              icon: const Icon(Icons.delete_outline),
            ),
          ),
        OutlinedButton.icon(
          onPressed: _saving || slots.length >= 200
              ? null
              : () => _add(blocked),
          icon: Icon(blocked ? Icons.event_busy : Icons.add),
          label: Text(
            blocked
                ? tr(
                    'Bloquer une période',
                    'Block a period',
                    'Bloquear un período',
                  )
                : tr(
                    'Ajouter une disponibilité',
                    'Add availability',
                    'Añadir disponibilidad',
                  ),
          ),
        ),
      ],
    );
  }

  DateTime get _periodStart => _view == 'month'
      ? DateTime(_selected.year, _selected.month)
      : _view == 'week'
      ? DateTime(
          _selected.year,
          _selected.month,
          _selected.day - (_selected.weekday - 1),
        )
      : DateTime(_selected.year, _selected.month, _selected.day);
  DateTime get _periodEnd => _view == 'month'
      ? DateTime(_selected.year, _selected.month + 1)
      : DateTime(
          _periodStart.year,
          _periodStart.month,
          _periodStart.day + (_view == 'week' ? 7 : 1),
        );
  void _move(int direction) => setState(
    () => _selected = _view == 'month'
        ? DateTime(_selected.year, _selected.month + direction)
        : DateTime(
            _selected.year,
            _selected.month,
            _selected.day + direction * (_view == 'week' ? 7 : 1),
          ),
  );
  bool _intersects(DateTime start, DateTime end) =>
      start.isBefore(_periodEnd) && end.isAfter(_periodStart);
  Widget _dateGrid(List<DeliveryMission> missions) => LayoutBuilder(
    builder: (context, c) {
      final first = DateTime(_selected.year, _selected.month);
      final count = DateTime(_selected.year, _selected.month + 1, 0).day;
      return Wrap(
        children: [
          for (final name
              in (_locale == 'en'
                  ? ['M', 'T', 'W', 'T', 'F', 'S', 'S']
                  : _locale == 'es'
                  ? ['L', 'M', 'X', 'J', 'V', 'S', 'D']
                  : ['L', 'M', 'M', 'J', 'V', 'S', 'D']))
            SizedBox(
              width: c.maxWidth / 7,
              height: 28,
              child: Center(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          for (int i = 0; i < first.weekday - 1; i++)
            SizedBox(width: c.maxWidth / 7, height: 48),
          for (int d = 1; d <= count; d++)
            SizedBox(
              width: c.maxWidth / 7,
              child: TextButton(
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 48),
                  padding: const EdgeInsets.all(2),
                ),
                onPressed: () => setState(() {
                  _selected = DateTime(_selected.year, _selected.month, d);
                  _view = 'day';
                }),
                child: Column(
                  children: [
                    Text(
                      '$d',
                      semanticsLabel: _date(
                        DateTime(_selected.year, _selected.month, d),
                      ),
                      style: const TextStyle(fontSize: 12),
                    ),
                    if (missions.any((m) => agendaMissionStart(m)?.day == d))
                      const Icon(Icons.local_shipping, size: 14),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
  String _month() {
    const fr = [
      'Janvier',
      'Février',
      'Mars',
      'Avril',
      'Mai',
      'Juin',
      'Juillet',
      'Août',
      'Septembre',
      'Octobre',
      'Novembre',
      'Décembre',
    ];
    const en = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const es = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return '${(_locale == 'en'
        ? en
        : _locale == 'es'
        ? es
        : fr)[_selected.month - 1]} ${_selected.year}';
  }

  Widget _mission(DeliveryMission m) {
    final start = agendaMissionStart(m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              m.description.isEmpty
                  ? tr(
                      'Mission attribuée',
                      'Assigned mission',
                      'Misión asignada',
                    )
                  : m.description,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              start == null
                  ? tr(
                      'Horaire à préciser',
                      'Time to be specified',
                      'Horario por precisar',
                    )
                  : _date(start),
            ),
            Text(
              '${tr('Statut', 'Status', 'Estado')} : ${AppStrings.t(m.status.key, _locale)}',
            ),
            if (m.scheduling?['end'] is String)
              Text(
                '${tr('Fin prévue', 'Planned end', 'Fin previsto')} : ${_date(DateTime.parse(m.scheduling!['end'] as String).toLocal())}',
              ),
            if (m.pickupAddress != null)
              Text(
                '${tr('Ramassage', 'Pickup', 'Recogida')} : ${m.pickupAddress!.line1}, ${m.pickupAddress!.city}',
              ),
            if (m.dropoffAddress != null)
              Text(
                '${tr('Livraison', 'Delivery', 'Entrega')} : ${m.dropoffAddress!.line1}, ${m.dropoffAddress!.city}',
              ),
            Text(AppStrings.t(m.requiredVehicleCategory.key, _locale)),
            if (m.hasAssignedDriver)
              Text(
                '${tr('Rémunération enregistrée', 'Recorded compensation', 'Remuneración registrada')} : ${m.driverOfferAmount.toStringAsFixed(2)} CAD',
              ),
            TextButton(
              onPressed: () =>
                  context.push('/$_locale/provider/mission/${m.id}'),
              child: Text(
                tr(
                  'Détails et suivi',
                  'Details and tracking',
                  'Detalles y seguimiento',
                ),
              ),
            ),
            if (m.scheduling == null &&
                m.bookingSnapshot?['load'] is Map &&
                (m.bookingSnapshot!['load'] as Map)['requested_at'] != null)
              Text(
                tr(
                  'Horaire demandé par le client · fin à préciser.',
                  'Time requested by customer · end time to be specified.',
                  'Horario solicitado por el cliente · fin por precisar.',
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.locale == null) _locale = context.watch<LocaleProvider>().locale;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr('Mon agenda', 'My calendar', 'Mi calendario'),
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in [
                ('day', tr('Jour', 'Day', 'Día')),
                ('week', tr('Semaine', 'Week', 'Semana')),
                ('month', tr('Mois', 'Month', 'Mes')),
              ])
                ChoiceChip(
                  label: Text(v.$2),
                  selected: _view == v.$1,
                  onSelected: (_) => setState(() => _view = v.$1),
                ),
              TextButton(
                onPressed: () => setState(() => _selected = DateTime.now()),
                child: Text(tr('Aujourd’hui', 'Today', 'Hoy')),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                tooltip: _view == 'month'
                    ? tr('Mois précédent', 'Previous month', 'Mes anterior')
                    : _view == 'week'
                    ? tr(
                        'Semaine précédente',
                        'Previous week',
                        'Semana anterior',
                      )
                    : tr('Jour précédent', 'Previous day', 'Día anterior'),
                onPressed: () => _move(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _view == 'month' ? _month() : _date(_periodStart),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: _view == 'month'
                    ? tr('Mois suivant', 'Next month', 'Mes siguiente')
                    : _view == 'week'
                    ? tr('Semaine suivante', 'Next week', 'Semana siguiente')
                    : tr('Jour suivant', 'Next day', 'Día siguiente'),
                onPressed: () => _move(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Text(
            tr(
              'Heures affichées dans le fuseau de cet appareil.',
              'Times use this device’s time zone.',
              'Las horas usan la zona horaria de este dispositivo.',
            ),
          ),
          const SizedBox(height: 12),
          StreamBuilder<List<DeliveryMission>>(
            stream: _missions,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Text(
                  tr(
                    'Impossible de charger les missions.',
                    'Unable to load missions.',
                    'No se pudieron cargar las misiones.',
                  ),
                );
              }
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final missions =
                  snapshot.data!.where((m) {
                    final d = agendaMissionStart(m);
                    final end = DateTime.tryParse(
                      m.scheduling?['end'] as String? ?? '',
                    )?.toLocal();
                    return d == null ||
                        _intersects(
                          d,
                          end ?? d.add(const Duration(minutes: 1)),
                        );
                  }).toList()..sort(
                    (a, b) => (agendaMissionStart(a) ?? DateTime(2100))
                        .compareTo(agendaMissionStart(b) ?? DateTime(2100)),
                  );
              if (missions.isEmpty && _view != 'month') {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    tr(
                      'Aucune mission attribuée pour cette période.',
                      'No assigned missions in this period.',
                      'No hay misiones asignadas en este período.',
                    ),
                  ),
                );
              }
              return Column(
                children: [
                  if (_view == 'month') _dateGrid(missions),
                  if (missions.isEmpty)
                    Text(
                      tr(
                        'Aucune mission attribuée pour ce mois.',
                        'No assigned missions this month.',
                        'No hay misiones asignadas este mes.',
                      ),
                    ),
                  ...missions.map(_mission),
                ],
              );
            },
          ),
          if (_calendarApi != null && _agenda != null)
            DriverAvailabilityPreview(
              api: _calendarApi!,
              agenda: _agenda!,
              from: _periodStart,
              to: _periodEnd,
              locale: _locale,
            ),
          const Divider(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _agenda?.dispatchConnected == true
                  ? tr(
                      'Vos disponibilités sont contrôlées avant l’attribution. Un calendrier externe doit être à jour pour accepter.',
                      'Availability is checked before assignment. Connected calendars must be up to date to accept.',
                      'Se comprueba la disponibilidad antes de asignar. Los calendarios conectados deben estar actualizados para aceptar.',
                    )
                  : tr(
                      'Préparation des disponibilités : vos plages peuvent être enregistrées, mais ne filtrent pas encore les offres. Les connexions externes se gèrent ci-dessous.',
                      'Availability preparation: your periods can be saved, but do not yet filter offers. External connections are managed below.',
                      'Preparación de disponibilidad: puedes guardar períodos, pero todavía no filtran ofertas. Las conexiones externas se gestionan abajo.',
                    ),
            ),
          ),
          const SizedBox(height: 16),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _agenda != null) ...[
            if (!_agenda!.configured)
              Text(
                tr(
                  'Aucune disponibilité déclarée.',
                  'No availability declared.',
                  'No hay disponibilidad declarada.',
                ),
              ),
            Text(
              tr('Mes disponibilités', 'My availability', 'Mi disponibilidad'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            DriverRecurrenceEditor(
              value: _agenda!.recurrence,
              locale: _locale,
              enabled: !_saving,
              onChanged: (value) {
                final a = _agenda!;
                setState(() {
                  _agenda = DriverAgenda(
                    revision: a.revision,
                    configured: a.configured,
                    windows: a.windows,
                    blocked: a.blocked,
                    recurrence: value,
                    dispatchConnected: a.dispatchConnected,
                  );
                  _dirty = true;
                });
              },
            ),
            _slots(false),
            const SizedBox(height: 16),
            _slots(true),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: !_dirty || _saving ? null : _save,
                  child: Text(
                    _saving
                        ? tr('Enregistrement…', 'Saving…', 'Guardando…')
                        : tr(
                            'Enregistrer mes disponibilités',
                            'Save availability',
                            'Guardar disponibilidad',
                          ),
                  ),
                ),
                if (_dirty)
                  Text(
                    tr(
                      'Modifications non enregistrées',
                      'Unsaved changes',
                      'Cambios sin guardar',
                    ),
                  ),
              ],
            ),
          ],
          if (_calendarApi != null)
            DriverCalendarsPanel(api: _calendarApi!, locale: _locale),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            TextButton(
              onPressed: _saving
                  ? null
                  : () async {
                      if (_dirty) {
                        final discard = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: Text(
                              tr(
                                'Abandonner les modifications ?',
                                'Discard changes?',
                                '¿Descartar cambios?',
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: Text(
                                  tr('Conserver', 'Keep', 'Conservar'),
                                ),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: Text(
                                  tr('Recharger', 'Reload', 'Recargar'),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (discard != true) return;
                      }
                      if (mounted) await _load();
                    },
              child: Text(tr('Recharger', 'Reload', 'Recargar')),
            ),
          ],
        ],
      ),
    );
  }
}
