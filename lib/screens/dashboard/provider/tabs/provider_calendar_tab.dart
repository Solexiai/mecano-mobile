import '../../../../widgets/driver_availability_preview.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../services/booking/booking_api.dart';
import '../../../../widgets/driver_recurrence_editor.dart';
import '../../../../widgets/driver_calendars_panel.dart';
import '../../../../widgets/driver_month_availability.dart';
import '../../../../widgets/driver_weekly_hours_card.dart';
import '../../../../finance/presentation/driver_display_format.dart';
import '../../../../services/driver_agenda_editing.dart';
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
  // Any day of the month shown in the calendar.
  DateTime _selected = DateTime.now();
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
      final saved = await _repository!.save(
        pruneAgenda(_agenda!, DateTime.now()),
      );
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

  void _setAgenda(DriverAgenda value) => setState(() {
    _agenda = value;
    _dirty = true;
  });

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
      '${driverDayLabel(d, _locale)} · ${driverTime(d, _locale)}';
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

  DateTime get _periodStart => DateTime(_selected.year, _selected.month);
  DateTime get _periodEnd => DateTime(_selected.year, _selected.month + 1);
  void _move(int direction) => setState(
    () => _selected = DateTime(_selected.year, _selected.month + direction),
  );
  bool _intersects(DateTime start, DateTime end) =>
      start.isBefore(_periodEnd) && end.isAfter(_periodStart);
  String _month() => driverMonthYear(_selected, _locale);

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
                '${tr('Rémunération enregistrée', 'Recorded compensation', 'Remuneración registrada')} : ${driverMoney(m.driverOfferAmount, _locale)}',
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

  Widget _card(Widget child) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: child,
  );

  Widget _intro() => Text(
    _agenda?.dispatchConnected == true
        ? tr(
            'Vos disponibilités sont contrôlées avant l’attribution. Un calendrier externe doit être à jour pour accepter.',
            'Availability is checked before assignment. Connected calendars must be up to date to accept.',
            'Se comprueba la disponibilidad antes de asignar. Los calendarios conectados deben estar actualizados para aceptar.',
          )
        : tr(
            'Indiquez quand vous êtes habituellement disponible. Pour l’instant, vos disponibilités ne filtrent pas encore les offres : vous recevez les demandes quand vous êtes « En service ».',
            'Tell us when you’re usually available. For now, your availability does not yet filter offers: you receive requests while you’re “On duty”.',
            'Indique cuándo suele estar disponible. Por ahora, su disponibilidad todavía no filtra las ofertas: recibe solicitudes mientras está «En servicio».',
          ),
    style: const TextStyle(color: AppColors.textSecondary),
  );

  Widget _missionsSection() => StreamBuilder<List<DeliveryMission>>(
    stream: _missions,
    builder: (context, snapshot) {
      // The availability calendar stays usable even when missions cannot
      // be read: only the missions list reports the problem.
      final missions =
          (snapshot.data ?? const <DeliveryMission>[]).where((m) {
            final d = agendaMissionStart(m);
            final end = DateTime.tryParse(
              m.scheduling?['end'] as String? ?? '',
            )?.toLocal();
            return d == null ||
                _intersects(d, end ?? d.add(const Duration(minutes: 1)));
          }).toList()..sort(
            (a, b) => (agendaMissionStart(a) ?? DateTime(2100)).compareTo(
              agendaMissionStart(b) ?? DateTime(2100),
            ),
          );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _card(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: tr(
                          'Mois précédent',
                          'Previous month',
                          'Mes anterior',
                        ),
                        onPressed: () => _move(-1),
                        icon: const Icon(Icons.chevron_left),
                      ),
                      Expanded(
                        child: Text(
                          _month(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: tr(
                          'Mois suivant',
                          'Next month',
                          'Mes siguiente',
                        ),
                        onPressed: () => _move(1),
                        icon: const Icon(Icons.chevron_right),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () =>
                          setState(() => _selected = DateTime.now()),
                      child: Text(tr('Aujourd’hui', 'Today', 'Hoy')),
                    ),
                  ),
                  if (_agenda != null)
                    DriverMonthAvailability(
                      agenda: _agenda!,
                      month: _selected,
                      missions: missions,
                      locale: _locale,
                      enabled: !_saving,
                      onChanged: _setAgenda,
                    ),
                ],
              ),
            ),
          Text(
            tr(
              'Mes missions ce mois-ci',
              'My jobs this month',
              'Mis misiones este mes',
            ),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (snapshot.hasError)
            Text(
              tr(
                'Impossible de charger les missions.',
                'Unable to load missions.',
                'No se pudieron cargar las misiones.',
              ),
            )
          else if (!snapshot.hasData)
            const LinearProgressIndicator()
          else if (missions.isEmpty)
            Text(
              tr(
                'Aucune mission attribuée pour ce mois.',
                'No assigned missions this month.',
                'No hay misiones asignadas este mes.',
              ),
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ...missions.map(_mission),
        ],
      );
    },
  );

  Widget _advanced() => ExpansionTile(
    key: const ValueKey('agenda-advanced'),
    tilePadding: EdgeInsets.zero,
    title: Text(
      tr('Réglages avancés', 'Advanced settings', 'Ajustes avanzados'),
      style: const TextStyle(fontWeight: FontWeight.w700),
    ),
    subtitle: Text(
      tr(
        'Plusieurs plages par jour, fuseau horaire, pauses, calendriers connectés',
        'Several periods per day, time zone, breaks, connected calendars',
        'Varios períodos por día, zona horaria, pausas, calendarios conectados',
      ),
    ),
    childrenPadding: const EdgeInsets.only(bottom: 12),
    expandedCrossAxisAlignment: CrossAxisAlignment.start,
    children: [
      DriverRecurrenceEditor(
        value: _agenda!.recurrence,
        locale: _locale,
        enabled: !_saving,
        onChanged: (value) {
          final a = _agenda!;
          _setAgenda(
            DriverAgenda(
              revision: a.revision,
              configured: a.configured,
              windows: a.windows,
              blocked: a.blocked,
              recurrence: value,
              dispatchConnected: a.dispatchConnected,
            ),
          );
        },
      ),
      const SizedBox(height: 8),
      _slots(false),
      const SizedBox(height: 16),
      _slots(true),
      if (_calendarApi != null) ...[
        const SizedBox(height: 8),
        DriverAvailabilityPreview(
          api: _calendarApi!,
          agenda: _agenda!,
          from: _periodStart,
          to: _periodEnd,
          locale: _locale,
        ),
        DriverCalendarsPanel(api: _calendarApi!, locale: _locale),
      ],
    ],
  );

  Widget _saveBar() => Material(
    key: const ValueKey('agenda-save-bar'),
    elevation: 8,
    color: Theme.of(context).cardTheme.color,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              tr(
                'Modifications non enregistrées',
                'Unsaved changes',
                'Cambios sin guardar',
              ),
            ),
            FilledButton(
              onPressed: _saving ? null : _save,
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
          ],
        ),
      ),
    ),
  );

  Widget _errorBlock() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
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
                          child: Text(tr('Conserver', 'Keep', 'Conservar')),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(tr('Recharger', 'Reload', 'Recargar')),
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
  );

  @override
  Widget build(BuildContext context) {
    if (widget.locale == null) _locale = context.watch<LocaleProvider>().locale;
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('Mon agenda', 'My calendar', 'Mi calendario'),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                _intro(),
                const SizedBox(height: 16),
                if (_loading) const LinearProgressIndicator(),
                if (!_loading && _agenda != null)
                  _card(
                    DriverWeeklyHoursCard(
                      agenda: _agenda!,
                      locale: _locale,
                      enabled: !_saving,
                      onChanged: _setAgenda,
                    ),
                  ),
                // Keyed: the usual-hours card appears above it once the agenda
                // is loaded. Without a key the StreamBuilder would be
                // recreated and subscribe a second time to the missions
                // stream (single-subscription with Firestore).
                KeyedSubtree(
                  key: const ValueKey('agenda-missions'),
                  child: _missionsSection(),
                ),
                if (!_loading && _agenda != null) ...[
                  const SizedBox(height: 16),
                  _advanced(),
                ],
                if (_error != null) _errorBlock(),
              ],
            ),
          ),
        ),
        if (_dirty && _agenda != null) _saveBar(),
      ],
    );
  }
}
