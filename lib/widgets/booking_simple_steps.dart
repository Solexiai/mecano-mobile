import 'package:flutter/material.dart';
import '../core/app_colors.dart';

// Simplified booking, one question per screen (owner decision 2026-10-23).
// These helpers only translate the customer's simple answers into the
// existing booking fields; the server still validates and prices everything.

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

/// Owner decision 2026-10-23 (option 2): the stairs question is only asked
/// when the load holds a piece of furniture or an appliance. Boxes alone
/// never ask it and never add a stairs fee.
const bookingLightCategories = {'boxes'};
bool stairsQuestionNeeded(List items) => items.any(
  (item) => !bookingLightCategories.contains((item as Map)['category']),
);

/// 'no' | 'yes' | 'unknown'. "Je ne sais pas" (a seller booking for a buyer)
/// is priced as stairs, so the customer never gets a surprise afterwards.
String? stairsAnswer(Map data, String key) {
  final value = data['${key}_stairs_answer'];
  return const ['no', 'yes', 'unknown'].contains(value) ? value as String : null;
}

void applyStairsAnswer(Map data, String key, String answer) {
  data['${key}_stairs_answer'] = answer;
  final access = data['${key}_access'] as Map;
  final stairs = answer != 'no';
  access['floor'] = stairs ? 1 : 0;
  access['stairs'] = stairs;
  access['elevator'] = false;
  access['details_version'] = 1;
  final fields = List<String>.from(access['confirmed_fields'] as List? ?? []);
  for (final field in ['floor', 'stairs', 'elevator']) {
    if (!fields.contains(field)) fields.add(field);
  }
  access['confirmed_fields'] = fields;
}

/// 'customer_helps' (one driver, the customer gives a hand) or
/// 'two_movers' (two people come and handle everything).
String? helpChoice(Map data) {
  final value = data['help_choice'];
  return const ['customer_helps', 'two_movers'].contains(value)
      ? value as String
      : null;
}

void applyHelpChoice(Map data, String choice) {
  final customerHelps = choice == 'customer_helps';
  data['help_choice'] = choice;
  data['handlers'] = customerHelps ? 1 : 2;
  for (final key in ['pickup_access', 'dropoff_access']) {
    final access = data[key] as Map;
    access['help'] = true;
    access['onsite_help'] = customerHelps ? 'yes' : 'no';
    access['inside'] = true;
    access['details_version'] = 1;
    access.remove('customer_handles_inside');
  }
}

/// Fixed hours (owner decision 2026-10-23), over the 4-day booking window.
const bookingSlotHours = [9, 11, 13, 15, 17, 19];
const bookingSlotLead = Duration(hours: 1);

/// Hours set in the Centre de commande (Où et quand ?, 2026-10-26), sent by
/// getBookingConfiguration; the launch rules above when none were saved.
class BookingHours {
  const BookingHours({
    this.slotHours = bookingSlotHours,
    this.lead = bookingSlotLead,
    this.daysAhead = 4,
    this.openWeekdays = const [1, 2, 3, 4, 5, 6, 7],
  });

  static BookingHours fromJson(Object? raw) {
    if (raw is! Map) return const BookingHours();
    List<int>? ints(Object? v, int min, int max) {
      if (v is! List || v.isEmpty) return null;
      final out = [for (final x in v) if (x is int && x >= min && x <= max) x];
      return out.length == v.length ? (out..sort()) : null;
    }

    final hours = ints(raw['slot_hours'], 0, 23);
    final days = ints(raw['open_weekdays'], 1, 7);
    final lead = raw['lead_minutes'];
    final ahead = raw['days_ahead'];
    return BookingHours(
      slotHours: hours ?? bookingSlotHours,
      lead: lead is int && lead >= 0 && lead <= 1440
          ? Duration(minutes: lead)
          : bookingSlotLead,
      // 2026-11-06 : jusqu'à 30 jours (dépôt à la réservation, solde bloqué à
      // J-4) ; avant, plafond 5 jours (fenêtre d'autorisation Stripe).
      daysAhead: ahead is int && ahead >= 1 && ahead <= 30 ? ahead : 4,
      openWeekdays: days ?? const [1, 2, 3, 4, 5, 6, 7],
    );
  }

  final List<int> slotHours;
  final Duration lead;
  final int daysAhead;
  final List<int> openWeekdays;
}

List<DateTime> bookingSlotDays(
  DateTime now, [
  BookingHours hours = const BookingHours(),
]) => [
  for (var i = 0; i < hours.daysAhead; i++)
    DateTime(now.year, now.month, now.day + i),
].where((day) => hours.slotHours.any((h) => slotOpen(day, h, now, hours))).toList();

bool slotOpen(
  DateTime day,
  int hour,
  DateTime now, [
  BookingHours hours = const BookingHours(),
]) =>
    hours.openWeekdays.contains(day.weekday) &&
    DateTime(day.year, day.month, day.day, hour).isAfter(now.add(hours.lead));

String slotDayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime? slotDayFromKey(String? key) {
  final parts = key?.split('-');
  if (parts == null || parts.length != 3) return null;
  final values = parts.map(int.tryParse).toList();
  if (values.any((v) => v == null)) return null;
  return DateTime(values[0]!, values[1]!, values[2]!);
}

String slotDayLabel(DateTime day, DateTime now, String locale) {
  final today = DateTime(now.year, now.month, now.day);
  final diff = DateTime(day.year, day.month, day.day).difference(today).inDays;
  if (diff == 0) return _tr(locale, 'Aujourd’hui', 'Today', 'Hoy');
  if (diff == 1) return _tr(locale, 'Demain', 'Tomorrow', 'Mañana');
  const fr = ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'];
  const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const es = ['lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.', 'dom.'];
  final names = locale == 'en' ? en : (locale == 'es' ? es : fr);
  return '${names[day.weekday - 1]} ${day.day}';
}

String slotHourLabel(int hour, String locale) =>
    locale == 'en' ? '$hour:00' : '$hour h';

const _monthsFr = ['janvier', 'février', 'mars', 'avril', 'mai', 'juin', 'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'];
const _monthsEn = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
const _monthsEs = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];

String slotMonthLabel(int month, String locale) =>
    (locale == 'en' ? _monthsEn : locale == 'es' ? _monthsEs : _monthsFr)[month - 1];

/// Calendrier de réservation (2026-11-06) : une grille de semaines, du lundi
/// de cette semaine jusqu'au dernier jour réservable (« Jours à l'avance »,
/// jusqu'à 30). Pas de navigation par mois : tout est visible d'un coup.
/// Jours fermés, passés ou sans heure disponible : grisés. Les cellules
/// portent la clé `slot-day-<AAAA-MM-JJ>` comme les anciennes pastilles.
class BookingCalendar extends StatelessWidget {
  const BookingCalendar({
    super.key,
    required this.now,
    required this.hours,
    required this.locale,
    required this.selectedKey,
    required this.onSelected,
    this.keyPrefix = 'slot-day',
  });

  final DateTime now;
  final BookingHours hours;
  final String locale;
  final String? selectedKey;
  final ValueChanged<String> onSelected;
  final String keyPrefix;

  @override
  Widget build(BuildContext context) {
    final today = DateTime(now.year, now.month, now.day);
    final first = DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final last = DateTime(today.year, today.month, today.day + hours.daysAhead - 1);
    final open = {for (final d in bookingSlotDays(now, hours)) slotDayKey(d)};
    final weeks = ((last.difference(first).inDays + 1) / 7).ceil();
    final scheme = Theme.of(context).colorScheme;
    const fr = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const es = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    final names = locale == 'en' ? en : locale == 'es' ? es : fr;
    final monthTitle = today.month == last.month
        ? '${slotMonthLabel(today.month, locale)} ${today.year}'
        : '${slotMonthLabel(today.month, locale)} – ${slotMonthLabel(last.month, locale)} ${last.year}';

    return Semantics(
      container: true,
      label: _tr(locale, 'Calendrier des jours de livraison', 'Delivery day calendar', 'Calendario de días de entrega'),
      child: Container(
        key: const ValueKey('booking-calendar'),
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Text(
              monthTitle[0].toUpperCase() + monthTitle.substring(1),
              key: const ValueKey('booking-calendar-title'),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < 7; i++)
                  Expanded(
                    child: Text(
                      names[i],
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var w = 0; w < weeks; w++)
              Row(
                children: [
                  for (var i = 0; i < 7; i++)
                    Expanded(
                      child: _CalendarCell(
                        day: DateTime(first.year, first.month, first.day + w * 7 + i),
                        today: today,
                        last: last,
                        open: open,
                        locale: locale,
                        selectedKey: selectedKey,
                        keyPrefix: keyPrefix,
                        onSelected: onSelected,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.today,
    required this.last,
    required this.open,
    required this.locale,
    required this.selectedKey,
    required this.keyPrefix,
    required this.onSelected,
  });
  final DateTime day, today, last;
  final Set<String> open;
  final String locale;
  final String? selectedKey;
  final String keyPrefix;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final key = slotDayKey(day);
    final inWindow = !day.isBefore(today) && !day.isAfter(last);
    final enabled = inWindow && open.contains(key);
    final selected = key == selectedKey;
    final isToday = day == today;
    final showMonth = day.day == 1 || day == today;
    final label = _tr(
      locale,
      '${day.day} ${slotMonthLabel(day.month, locale)}',
      '${slotMonthLabel(day.month, locale)} ${day.day}',
      '${day.day} de ${slotMonthLabel(day.month, locale)}',
    );
    return Padding(
      padding: const EdgeInsets.all(2),
      child: Semantics(
        button: true,
        enabled: enabled,
        selected: selected,
        label: label,
        child: Material(
          color: selected
              ? scheme.primary
              : enabled
              ? scheme.primary.withValues(alpha: 0.06)
              : Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isToday && !selected
                ? BorderSide(color: scheme.primary, width: 1.5)
                : BorderSide.none,
          ),
          child: InkWell(
            key: ValueKey('$keyPrefix-$key'),
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? () => onSelected(key) : null,
            child: SizedBox(
              height: 46,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${day.day}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: enabled || selected ? FontWeight.w700 : FontWeight.w400,
                      color: selected
                          ? scheme.onPrimary
                          : enabled
                          ? scheme.onSurface
                          : scheme.onSurface.withValues(alpha: 0.3),
                    ),
                  ),
                  if (showMonth)
                    Text(
                      slotMonthLabel(day.month, locale).substring(0, 3),
                      style: TextStyle(
                        fontSize: 9,
                        color: selected ? scheme.onPrimary : scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Étape 2 sur 7" and a segmented progress bar.
class BookingStepHeader extends StatelessWidget {
  const BookingStepHeader({
    super.key,
    required this.current,
    required this.total,
    required this.locale,
  });
  final int current, total;
  final String locale;
  @override
  Widget build(BuildContext context) {
    final label = _tr(
      locale,
      'Étape $current sur $total',
      'Step $current of $total',
      'Paso $current de $total',
    );
    return Semantics(
      key: const ValueKey('booking-step-header'),
      label: label,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 1; i <= total; i++) ...[
                  if (i > 1) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i <= current
                            ? AppColors.primary
                            : const Color(0xFFD5DBE6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The screen's single question, in large type.
class BookingQuestion extends StatelessWidget {
  const BookingQuestion(this.text, {super.key, this.hint});
  final String text;
  final String? hint;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20, bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            text,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (hint != null) ...[
          const SizedBox(height: 6),
          Text(
            hint!,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}

/// A large tappable card: one of a few mutually exclusive answers.
class BookingBigChoice extends StatelessWidget {
  const BookingBigChoice({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
  });
  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: Material(
        color: selected ? const Color(0xFFE6EDFA) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.border,
            width: 2,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: AppColors.primary, size: 28),
                    const SizedBox(width: 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? AppColors.primary : AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// Large pill buttons on one row (Non / Oui / Je ne sais pas, days, hours).
class BookingPills extends StatelessWidget {
  const BookingPills({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    this.keyPrefix = 'pill',
    this.columns = 3,
  });
  final List<(String, String)> options;
  final String? selected;
  final ValueChanged<String> onSelected;
  final String keyPrefix;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      const gap = 8.0;
      final width = (c.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: gap,
        children: [
          for (final option in options)
            SizedBox(
              width: width.isFinite && width > 0 ? width : null,
              child: Semantics(
                selected: option.$1 == selected,
                inMutuallyExclusiveGroup: true,
                child: option.$1 == selected
                    ? FilledButton(
                        key: ValueKey('$keyPrefix-${option.$1}'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => onSelected(option.$1),
                        child: Text(option.$2, textAlign: TextAlign.center),
                      )
                    : OutlinedButton(
                        key: ValueKey('$keyPrefix-${option.$1}'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 52),
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.textPrimary,
                          side: const BorderSide(
                            color: AppColors.border,
                            width: 2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => onSelected(option.$1),
                        child: Text(option.$2, textAlign: TextAlign.center),
                      ),
              ),
            ),
        ],
      );
    },
  );
}

/// "Des escaliers à cette adresse ?" — Non / Oui / Je ne sais pas.
class BookingStairsQuestion extends StatelessWidget {
  const BookingStairsQuestion({
    super.key,
    required this.prefix,
    required this.answer,
    required this.onAnswer,
    required this.locale,
  });
  final String prefix, locale;
  final String? answer;
  final ValueChanged<String> onAnswer;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _tr(
            locale,
            'Des escaliers à cette adresse ?',
            'Any stairs at this address?',
            '¿Hay escaleras en esta dirección?',
          ),
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
        const SizedBox(height: 8),
        BookingPills(
          keyPrefix: '$prefix-stairs',
          selected: answer,
          onSelected: onAnswer,
          options: [
            ('no', _tr(locale, 'Non', 'No', 'No')),
            ('yes', _tr(locale, 'Oui', 'Yes', 'Sí')),
            (
              'unknown',
              _tr(locale, 'Je ne sais pas', 'I don’t know', 'No lo sé'),
            ),
          ],
        ),
        if (answer == 'unknown') ...[
          const SizedBox(height: 6),
          Text(
            _tr(
              locale,
              'Pas de souci. Le prix inclut les escaliers au cas où.',
              'No problem. The price includes stairs just in case.',
              'No hay problema. El precio incluye escaleras por si acaso.',
            ),
            key: ValueKey('$prefix-stairs-unknown-note'),
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ],
      ],
    ),
  );
}
