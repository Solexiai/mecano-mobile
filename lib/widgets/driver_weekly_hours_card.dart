// ---------------------------------------------------------------------------
// DriverWeeklyHoursCard — « Mon horaire habituel » (Agenda chauffeur).
//
// Plusieurs jours à la fois : le chauffeur coche ses jours (ou un raccourci
// « Semaine », « Fin de semaine », « Tous les jours »), choisit ses heures une
// seule fois, puis applique. Remplace les 3 fenêtres par jour de l'ancien
// éditeur (jour, début, fin).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../backend/repositories/driver_agenda_repository.dart';
import '../core/app_colors.dart';
import '../finance/presentation/driver_display_format.dart';
import '../services/driver_agenda_editing.dart';

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

/// Choix d'une heure par pas de 30 minutes (pas de fenêtre de dialogue).
class AgendaTimeDropdown extends StatelessWidget {
  const AgendaTimeDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.locale,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final String locale;
  final bool enabled;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final options = [for (var m = min; m <= max; m += 30) m];
    final current = options.contains(value) ? value : options.first;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        const SizedBox(width: 6),
        DropdownButton<int>(
          value: current,
          onChanged: enabled
              ? (v) {
                  if (v != null) onChanged(v);
                }
              : null,
          items: [
            for (final m in options)
              DropdownMenuItem(value: m, child: Text(driverClock(m, locale))),
          ],
        ),
      ],
    );
  }
}

/// Résumé lisible de l'horaire habituel : « lun. – ven. · 8 h – 17 h ».
String weeklyGroupLabel(WeeklyGroup group, String locale) {
  final days = group.weekdays;
  final dayText = days.length >= 3
      ? '${driverWeekdayShort(days.first, locale)} – ${driverWeekdayShort(days.last, locale)}'
      : days.map((d) => driverWeekdayShort(d, locale)).join(', ');
  final hours = group.windows
      .map((w) => driverHoursRange(w.start, w.end, locale))
      .join(', ');
  return '$dayText · $hours';
}

class DriverWeeklyHoursCard extends StatefulWidget {
  const DriverWeeklyHoursCard({
    super.key,
    required this.agenda,
    required this.locale,
    required this.onChanged,
    this.enabled = true,
  });

  final DriverAgenda agenda;
  final String locale;
  final bool enabled;
  final ValueChanged<DriverAgenda> onChanged;

  @override
  State<DriverWeeklyHoursCard> createState() => _DriverWeeklyHoursCardState();
}

class _DriverWeeklyHoursCardState extends State<DriverWeeklyHoursCard> {
  final Set<int> _days = {};
  int _start = 8 * 60;
  int _end = 17 * 60;

  String tr(String fr, String en, String es) => _tr(widget.locale, fr, en, es);

  void _preset(Set<int> days) => setState(
    () => _days
      ..clear()
      ..addAll(days),
  );

  void _toggle(int day) => setState(() {
    if (!_days.remove(day)) {
      _days.add(day);
      // A day that already has hours proposes them, to edit them quickly.
      if (_days.length == 1) {
        final existing = weeklyWindows(widget.agenda, day);
        if (existing.length == 1) {
          _start = existing.single.start;
          _end = existing.single.end;
        }
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    final locale = widget.locale;
    final groups = weeklyGroups(widget.agenda);
    final valid = _end > _start;
    final canApply = widget.enabled && _days.isNotEmpty && valid;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr('Mon horaire habituel', 'My usual hours', 'Mi horario habitual'),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        if (groups.isEmpty)
          Text(
            tr(
              'Aucun horaire habituel. Cochez vos jours et vos heures ci-dessous.',
              'No usual hours yet. Pick your days and hours below.',
              'Sin horario habitual. Elija sus días y horas abajo.',
            ),
            style: const TextStyle(color: AppColors.textSecondary),
          )
        else
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Row(
                children: [
                  const Icon(
                    Icons.event_available,
                    size: 18,
                    color: AppColors.success,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      weeklyGroupLabel(g, locale),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var d = 1; d <= 7; d++)
              FilterChip(
                key: ValueKey('weekly-day-$d'),
                label: Text(driverWeekdayShort(d, locale)),
                selected: _days.contains(d),
                onSelected: widget.enabled ? (_) => _toggle(d) : null,
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            ActionChip(
              label: Text(tr('Semaine', 'Weekdays', 'Entre semana')),
              onPressed: widget.enabled ? () => _preset({1, 2, 3, 4, 5}) : null,
            ),
            ActionChip(
              label: Text(tr('Fin de semaine', 'Weekend', 'Fin de semana')),
              onPressed: widget.enabled ? () => _preset({6, 7}) : null,
            ),
            ActionChip(
              label: Text(tr('Tous les jours', 'Every day', 'Todos los días')),
              onPressed: widget.enabled
                  ? () => _preset({1, 2, 3, 4, 5, 6, 7})
                  : null,
            ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            AgendaTimeDropdown(
              key: const ValueKey('weekly-start'),
              label: tr('De', 'From', 'De'),
              value: _start,
              min: 0,
              max: 1410,
              locale: locale,
              enabled: widget.enabled,
              onChanged: (v) => setState(() => _start = v),
            ),
            AgendaTimeDropdown(
              key: const ValueKey('weekly-end'),
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
            FilledButton.tonal(
              key: const ValueKey('weekly-apply'),
              onPressed: canApply
                  ? () {
                      widget.onChanged(
                        setWeeklyHours(widget.agenda, {..._days}, _start, _end),
                      );
                      setState(_days.clear);
                    }
                  : null,
              child: Text(
                tr(
                  'Appliquer à ces jours',
                  'Apply to these days',
                  'Aplicar a estos días',
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('weekly-clear'),
              onPressed: widget.enabled && _days.isNotEmpty
                  ? () {
                      widget.onChanged(
                        clearWeeklyHours(widget.agenda, {..._days}),
                      );
                      setState(_days.clear);
                    }
                  : null,
              child: Text(
                tr(
                  'Ces jours : pas disponible',
                  'These days: not available',
                  'Estos días: no disponible',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
