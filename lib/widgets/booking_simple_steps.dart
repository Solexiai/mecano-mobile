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

List<DateTime> bookingSlotDays(DateTime now) => [
  for (var i = 0; i < 4; i++) DateTime(now.year, now.month, now.day + i),
].where((day) => bookingSlotHours.any((h) => slotOpen(day, h, now))).toList();

bool slotOpen(DateTime day, int hour, DateTime now) => DateTime(
  day.year,
  day.month,
  day.day,
  hour,
).isAfter(now.add(bookingSlotLead));

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
