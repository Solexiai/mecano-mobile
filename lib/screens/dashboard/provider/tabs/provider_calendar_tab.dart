import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../backend/repositories/driver_agenda_repository.dart';
import '../../../../core/app_colors.dart';
import '../../../../l10n/app_strings.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

class ProviderCalendarTab extends StatefulWidget {
  const ProviderCalendarTab({super.key, this.repository, this.locale});
  final DriverAgendaRepository? repository;
  final String? locale;
  @override
  State<ProviderCalendarTab> createState() => _ProviderCalendarTabState();
}

class _ProviderCalendarTabState extends State<ProviderCalendarTab> {
  DateTime _selected = DateTime.now();
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
            if (m.bookingSnapshot?['load'] is Map &&
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
          Row(
            children: [
              IconButton(
                tooltip: tr('Mois précédent', 'Previous month', 'Mes anterior'),
                onPressed: () => setState(
                  () =>
                      _selected = DateTime(_selected.year, _selected.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  _month(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              IconButton(
                tooltip: tr('Mois suivant', 'Next month', 'Mes siguiente'),
                onPressed: () => setState(
                  () =>
                      _selected = DateTime(_selected.year, _selected.month + 1),
                ),
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
                    return d == null ||
                        (d.year == _selected.year &&
                            d.month == _selected.month);
                  }).toList()..sort(
                    (a, b) => (agendaMissionStart(a) ?? DateTime(2100))
                        .compareTo(agendaMissionStart(b) ?? DateTime(2100)),
                  );
              if (missions.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    tr(
                      'Aucune mission attribuée pour ce mois.',
                      'No assigned missions this month.',
                      'No hay misiones asignadas este mes.',
                    ),
                  ),
                );
              }
              return Column(children: missions.map(_mission).toList());
            },
          ),
          const Divider(height: 32),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              tr(
                'Préparation des disponibilités : vos plages peuvent être enregistrées, mais ne filtrent pas encore les offres. Aucun calendrier externe n’est connecté.',
                'Availability preparation: your periods can be saved, but do not yet filter offers. No external calendar is connected.',
                'Preparación de disponibilidad: puedes guardar períodos, pero todavía no filtran ofertas. No hay calendario externo conectado.',
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
