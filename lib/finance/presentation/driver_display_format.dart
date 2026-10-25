// ---------------------------------------------------------------------------
// driver_display_format.dart — formats d'affichage de l'Espace fournisseur
// (revenus, accueil, agenda). Affichage seulement, aucun calcul financier.
//
// Les noms de jours et de mois sont écrits ici plutôt que tirés de `intl` :
// le rendu ne dépend ainsi d'aucune donnée de date chargée au démarrage
// (identique en application, sur le web et dans les tests).
// ---------------------------------------------------------------------------

import 'money_format.dart';

String _lang(String locale) => locale.split(RegExp('[-_]')).first;

const _monthsShort = {
  'fr': [
    'janv.',
    'févr.',
    'mars',
    'avr.',
    'mai',
    'juin',
    'juil.',
    'août',
    'sept.',
    'oct.',
    'nov.',
    'déc.',
  ],
  'en': [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ],
  'es': [
    'ene.',
    'feb.',
    'mar.',
    'abr.',
    'may.',
    'jun.',
    'jul.',
    'ago.',
    'sept.',
    'oct.',
    'nov.',
    'dic.',
  ],
};

const _monthsLong = {
  'fr': [
    'janvier',
    'février',
    'mars',
    'avril',
    'mai',
    'juin',
    'juillet',
    'août',
    'septembre',
    'octobre',
    'novembre',
    'décembre',
  ],
  'en': [
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
  ],
  'es': [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ],
};

/// Lundi = index 0.
const _weekdaysShort = {
  'fr': ['lun.', 'mar.', 'mer.', 'jeu.', 'ven.', 'sam.', 'dim.'],
  'en': ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
  'es': ['lun.', 'mar.', 'mié.', 'jue.', 'vie.', 'sáb.', 'dom.'],
};

/// Initiales des jours, lundi d'abord (en-tête du calendrier).
const _weekdayInitials = {
  'fr': ['L', 'M', 'M', 'J', 'V', 'S', 'D'],
  'en': ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
  'es': ['L', 'M', 'X', 'J', 'V', 'S', 'D'],
};

/// Noms complets des jours, lundi d'abord.
const _weekdaysLong = {
  'fr': ['Lundi', 'Mardi', 'Mercredi', 'Jeudi', 'Vendredi', 'Samedi', 'Dimanche'],
  'en': [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ],
  'es': ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'],
};

List<String> _pick(Map<String, List<String>> table, String locale) =>
    table[_lang(locale)] ?? table['fr']!;

/// « 67,50 $ » en français et en espagnol, « $67.50 » en anglais.
String driverMoney(num amount, String locale) =>
    formatMajorAmount(amount, locale: locale);

/// Même chose depuis des cents.
String driverMoneyMinor(int minor, String locale) =>
    formatMajorAmount(minor / 100, locale: locale);

/// Initiales des jours, lundi d'abord : L M M J V S D.
List<String> driverWeekdayInitials(String locale) =>
    _pick(_weekdayInitials, locale);

/// Jour complet (1 = lundi … 7 = dimanche).
String driverWeekdayName(int weekday, String locale) =>
    _pick(_weekdaysLong, locale)[(weekday - 1) % 7];

/// Jour abrégé (1 = lundi … 7 = dimanche) : « lun. », « Mon ».
String driverWeekdayShort(int weekday, String locale) =>
    _pick(_weekdaysShort, locale)[(weekday - 1) % 7];

/// « octobre 2026 », « October 2026 ».
String driverMonthYear(DateTime date, String locale) {
  final month = _pick(_monthsLong, locale)[date.month - 1];
  final label = '$month ${date.year}';
  return label[0].toUpperCase() + label.substring(1);
}

/// « 23 oct. 2026 », « Oct 23, 2026 ».
String driverShortDate(DateTime date, String locale) {
  final local = date.toLocal();
  final month = _pick(_monthsShort, locale)[local.month - 1];
  if (_lang(locale) == 'en') return '$month ${local.day}, ${local.year}';
  return '${local.day} $month ${local.year}';
}

/// « jeu. 29 oct. », « Thu Oct 29 ».
String driverDayLabel(DateTime date, String locale) {
  final local = date.toLocal();
  final weekday = driverWeekdayShort(local.weekday, locale);
  final month = _pick(_monthsShort, locale)[local.month - 1];
  if (_lang(locale) == 'en') return '$weekday $month ${local.day}';
  return '$weekday ${local.day} $month';
}

/// Heure depuis des minutes après minuit : « 8 h », « 8 h 30 » en français,
/// « 8:00 », « 8:30 » en anglais et en espagnol. 1440 = fin de journée.
String driverClock(int minuteOfDay, String locale) {
  final h = minuteOfDay ~/ 60;
  final m = minuteOfDay % 60;
  if (_lang(locale) == 'fr') {
    return m == 0 ? '$h h' : '$h h ${m.toString().padLeft(2, '0')}';
  }
  return '$h:${m.toString().padLeft(2, '0')}';
}

/// Heure d'un instant : « 9 h 15 », « 9:15 ».
String driverTime(DateTime date, String locale) {
  final local = date.toLocal();
  return driverClock(local.hour * 60 + local.minute, locale);
}

/// « 8 h – 17 h ».
String driverHoursRange(int startMinute, int endMinute, String locale) =>
    '${driverClock(startMinute, locale)} – ${driverClock(endMinute, locale)}';

/// Début de la semaine (lundi 0 h) contenant [date], heure locale.
DateTime driverWeekStart(DateTime date) {
  final local = date.toLocal();
  // Calendar arithmetic (not Duration) so a daylight saving change inside
  // the week never shifts the result to 23 h the day before.
  return DateTime(local.year, local.month, local.day - (local.weekday - 1));
}
