// ---------------------------------------------------------------------------
// DriverMonthAvailability — calendrier du mois de l'Agenda chauffeur.
//
// Chaque journée est colorée selon la disponibilité réelle (horaire habituel,
// exceptions, plages et blocages) : vert = disponible, gris = pas
// disponible. Un camion signale une mission. Le chauffeur touche plusieurs
// journées puis choisit une seule action pour toutes : « Disponible de … à
// … », « Pas disponible » ou « Horaire habituel ». Les journées passées ne se
// sélectionnent pas.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../backend/models/delivery_mission.dart';
import '../backend/repositories/driver_agenda_repository.dart';
import '../core/app_colors.dart';
import '../finance/presentation/driver_display_format.dart';
import '../services/driver_agenda_editing.dart';
import 'driver_weekly_hours_card.dart' show AgendaTimeDropdown;

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

class DriverMonthAvailability extends StatefulWidget {
  const DriverMonthAvailability({
    super.key,
    required this.agenda,
    required this.month,
    required this.missions,
    required this.locale,
    required this.onChanged,
    this.enabled = true,
    this.now,
  });

  final DriverAgenda agenda;

  /// N'importe quel jour du mois affiché.
  final DateTime month;
  final List<DeliveryMission> missions;
  final String locale;
  final bool enabled;
  final ValueChanged<DriverAgenda> onChanged;

  /// Horloge injectable pour les tests.
  final DateTime? now;

  @override
  State<DriverMonthAvailability> createState() =>
      _DriverMonthAvailabilityState();
}

class _DriverMonthAvailabilityState extends State<DriverMonthAvailability> {
  final Set<String> _selected = {};
  int _start = 8 * 60;
  int _end = 17 * 60;

  String tr(String fr, String en, String es) => _tr(widget.locale, fr, en, es);

  DateTime get _today => agendaDayStart(widget.now ?? DateTime.now());

  @override
  void didUpdateWidget(covariant DriverMonthAvailability old) {
    super.didUpdateWidget(old);
    if (old.month.year != widget.month.year ||
        old.month.month != widget.month.month) {
      _selected.clear();
    }
  }

  List<DateTime> get _selectedDays {
    final days = _selected.map(DateTime.parse).toList()..sort();
    return days;
  }

  void _toggle(DateTime day) => setState(() {
    final key = agendaDateKey(day);
    if (!_selected.remove(key)) {
      _selected.add(key);
      if (_selected.length == 1) {
        // Propose the hours this day already has (or the usual ones).
        final info = agendaDayInfo(widget.agenda, day);
        final source = info.windows.isNotEmpty
            ? info.windows
            : weeklyWindows(widget.agenda, day.weekday);
        if (source.isNotEmpty) {
          _start = (source.first.start ~/ 30) * 30;
          _end = ((source.last.end + 29) ~/ 30) * 30;
          if (_end > 1440) _end = 1440;
        }
      }
    }
  });

  void _apply(DriverAgenda Function(DriverAgenda a, List<DateTime> d) op) {
    final days = _selectedDays;
    if (days.isEmpty) return;
    widget.onChanged(op(widget.agenda, days));
    setState(_selected.clear);
  }

  bool _hasMission(DateTime day) {
    for (final m in widget.missions) {
      final start = agendaMissionStart(m);
      if (start != null && agendaDateKey(start) == agendaDateKey(day)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final first = DateTime(widget.month.year, widget.month.month);
    final count = DateTime(widget.month.year, widget.month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = <DateTime?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= count; d++)
        DateTime(widget.month.year, widget.month.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final selectedDays = _selectedDays;
    final single = selectedDays.length == 1 ? selectedDays.single : null;
    final valid = _end > _start;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final name in driverWeekdayInitials(locale))
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            children: [
              for (final day in cells.sublist(row * 7, row * 7 + 7))
                Expanded(child: _cell(context, day)),
            ],
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _Legend(
              color: AppColors.success,
              label: tr('Disponible', 'Available', 'Disponible'),
            ),
            _Legend(
              color: AppColors.textSecondary,
              label: tr('Pas disponible', 'Not available', 'No disponible'),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_shipping, size: 14),
                const SizedBox(width: 4),
                Flexible(child: Text(tr('Mission', 'Job', 'Misión'))),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (selectedDays.isEmpty)
          Text(
            tr(
              'Touchez une ou plusieurs journées pour changer leur disponibilité.',
              'Tap one or more days to change their availability.',
              'Toque uno o varios días para cambiar su disponibilidad.',
            ),
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else
          Container(
            key: const ValueKey('agenda-selection-panel'),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        single != null
                            ? driverDayLabel(single, locale)
                            : tr(
                                '${selectedDays.length} jours sélectionnés',
                                '${selectedDays.length} days selected',
                                '${selectedDays.length} días seleccionados',
                              ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: Text(tr('Effacer', 'Clear', 'Borrar')),
                    ),
                  ],
                ),
                if (single != null) _dayDetail(single),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 16,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    AgendaTimeDropdown(
                      key: const ValueKey('day-start'),
                      label: tr('De', 'From', 'De'),
                      value: _start,
                      min: 0,
                      max: 1410,
                      locale: locale,
                      enabled: widget.enabled,
                      onChanged: (v) => setState(() => _start = v),
                    ),
                    AgendaTimeDropdown(
                      key: const ValueKey('day-end'),
                      label: tr('à', 'to', 'a'),
                      value: _end,
                      min: 30,
                      max: 1440,
                      locale: locale,
                      enabled: widget.enabled,
                      onChanged: (v) => setState(() => _end = v),
                    ),
                  ],
                ),
                if (!valid)
                  Text(
                    tr(
                      'L’heure de fin doit suivre l’heure de début.',
                      'End time must be after start time.',
                      'La hora de fin debe ser posterior a la de inicio.',
                    ),
                    style: const TextStyle(color: AppColors.error),
                  ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton(
                      key: const ValueKey('days-available'),
                      onPressed: widget.enabled && valid
                          ? () => _apply(
                              (a, d) => setDaysAvailable(a, d, _start, _end),
                            )
                          : null,
                      child: Text(tr('Disponible', 'Available', 'Disponible')),
                    ),
                    OutlinedButton(
                      key: const ValueKey('days-unavailable'),
                      onPressed: widget.enabled
                          ? () => _apply(setDaysUnavailable)
                          : null,
                      child: Text(
                        tr('Pas disponible', 'Not available', 'No disponible'),
                      ),
                    ),
                    TextButton(
                      key: const ValueKey('days-regular'),
                      onPressed: widget.enabled ? () => _apply(resetDays) : null,
                      child: Text(
                        tr(
                          'Horaire habituel',
                          'Usual hours',
                          'Horario habitual',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _dayDetail(DateTime day) {
    final info = agendaDayInfo(widget.agenda, day);
    final locale = widget.locale;
    final state = info.isAvailable
        ? '${tr('Disponible', 'Available', 'Disponible')} '
              '${info.windows.map((w) => driverHoursRange(w.start, w.end, locale)).join(', ')}'
        : tr('Pas disponible', 'Not available', 'No disponible');
    final source = info.source == AgendaDaySource.regular
        ? tr('horaire habituel', 'usual hours', 'horario habitual')
        : tr('changé pour ce jour', 'changed for this day', 'cambiado para este día');
    return Text(
      '$state · $source',
      style: const TextStyle(color: AppColors.textSecondary),
    );
  }

  Widget _cell(BuildContext context, DateTime? day) {
    if (day == null) return const SizedBox(height: 46);
    final past = day.isBefore(_today);
    final isToday = agendaDateKey(day) == agendaDateKey(_today);
    final info = agendaDayInfo(widget.agenda, day);
    final selected = _selected.contains(agendaDateKey(day));
    final mission = _hasMission(day);
    final base = info.isAvailable ? AppColors.success : AppColors.textSecondary;
    final background = selected
        ? AppColors.primary.withValues(alpha: .18)
        : base.withValues(alpha: past ? .05 : (info.isAvailable ? .16 : .08));
    final label = driverDayLabel(day, widget.locale);
    final stateLabel = info.isAvailable
        ? tr('disponible', 'available', 'disponible')
        : tr('pas disponible', 'not available', 'no disponible');

    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: !past,
        selected: selected,
        label: '$label, $stateLabel',
        excludeSemantics: true,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            key: ValueKey('agenda-day-${agendaDateKey(day)}'),
            borderRadius: BorderRadius.circular(8),
            onTap: past || !widget.enabled ? null : () => _toggle(day),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? Border.all(color: AppColors.primary, width: 2)
                    : isToday
                    ? Border.all(color: AppColors.textSecondary)
                    : null,
              ),
              // Scales down with very large text instead of overflowing the
              // fixed-height cell.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                      color: past ? AppColors.textSecondary : null,
                    ),
                  ),
                  if (mission) const Icon(Icons.local_shipping, size: 12),
                ],
              ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color.withValues(alpha: .25),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(width: 4),
      Flexible(child: Text(label)),
    ],
  );
}
