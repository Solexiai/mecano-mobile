// ---------------------------------------------------------------------------
// driver_agenda_editing.dart — modifications de l'agenda chauffeur par
// journées entières (écran Agenda, 25 octobre 2026).
//
// Le format enregistré ne change pas (saveDriverAgenda) :
//   - `recurrence.weekly`     : horaire habituel par jour de la semaine ;
//   - `recurrence.exceptions` : une date précise remplace l'horaire habituel
//                               (liste vide = pas disponible ce jour-là) ;
//   - `windows` / `blocked`   : plages ponctuelles et blocages datés.
//
// Côté serveur (driverAgenda.intervalIsAvailable) : disponible = plages
// ponctuelles ∪ horaire du jour, puis les blocages l'emportent toujours.
// Choisir l'état d'une journée la définit donc entièrement : les plages et
// blocages ponctuels qui touchent ce jour sont retirés pour ce jour-là
// seulement (les intervalles qui débordent sont coupés, jamais supprimés en
// entier), puis :
//   - « Disponible de A à B » : exception [A, B] ;
//   - « Pas disponible »      : exception vide + blocage de la journée
//                               (le blocage couvre aussi une plage
//                               ponctuelle ajoutée plus tard par erreur) ;
//   - « Horaire habituel »    : plus d'exception, la semaine type s'applique.
// ---------------------------------------------------------------------------

import '../backend/repositories/driver_agenda_repository.dart';

const String kDefaultAgendaTimeZone = 'America/Toronto';

/// Clé de date `AAAA-MM-JJ` (jour local).
String agendaDateKey(DateTime day) {
  final d = day.toLocal();
  return '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Minuit local du jour de [date].
DateTime agendaDayStart(DateTime date) {
  final d = date.toLocal();
  return DateTime(d.year, d.month, d.day);
}

/// Minuit local du lendemain (arithmétique de calendrier : un changement
/// d'heure ne décale jamais la fin de journée).
DateTime agendaDayEnd(DateTime date) {
  final d = date.toLocal();
  return DateTime(d.year, d.month, d.day + 1);
}

class MinuteWindow {
  const MinuteWindow(this.start, this.end);
  final int start;
  final int end;

  Map<String, dynamic> toJson() => {'start_minute': start, 'end_minute': end};

  static MinuteWindow? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final s = raw['start_minute'];
    final e = raw['end_minute'];
    if (s is! num || e is! num) return null;
    final start = s.toInt(), end = e.toInt();
    if (start < 0 || end > 1440 || end <= start) return null;
    return MinuteWindow(start, end);
  }

  @override
  bool operator ==(Object other) =>
      other is MinuteWindow && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);
}

enum AgendaDayKind { available, unavailable }

/// Où vient l'état affiché d'une journée.
enum AgendaDaySource { regular, custom }

class AgendaDayInfo {
  const AgendaDayInfo({
    required this.kind,
    required this.source,
    required this.windows,
  });

  final AgendaDayKind kind;
  final AgendaDaySource source;

  /// Plages disponibles de la journée, en minutes locales, triées.
  final List<MinuteWindow> windows;

  bool get isAvailable => kind == AgendaDayKind.available;
}

DriverAgenda _copy(
  DriverAgenda a, {
  Map<String, dynamic>? recurrence,
  List<AgendaInterval>? windows,
  List<AgendaInterval>? blocked,
}) => DriverAgenda(
  revision: a.revision,
  configured: a.configured,
  dispatchConnected: a.dispatchConnected,
  recurrence: recurrence ?? a.recurrence,
  windows: windows ?? a.windows,
  blocked: blocked ?? a.blocked,
);

Map<String, dynamic> _recurrence(DriverAgenda a) {
  final r = a.recurrence;
  return {
    'time_zone': (r?['time_zone'] as String?) ?? kDefaultAgendaTimeZone,
    'weekly': List<dynamic>.from(r?['weekly'] as List? ?? const []),
    'exceptions': List<dynamic>.from(r?['exceptions'] as List? ?? const []),
    'pause_before_minutes': (r?['pause_before_minutes'] as num?)?.toInt() ?? 0,
    'pause_after_minutes': (r?['pause_after_minutes'] as num?)?.toInt() ?? 0,
  };
}

/// Plages habituelles d'un jour de la semaine (1 = lundi … 7 = dimanche).
List<MinuteWindow> weeklyWindows(DriverAgenda a, int weekday) {
  final weekly = a.recurrence?['weekly'] as List? ?? const [];
  final result = <MinuteWindow>[];
  for (final raw in weekly) {
    if (raw is Map && (raw['day'] as num?)?.toInt() == weekday) {
      final w = MinuteWindow.fromJson(raw);
      if (w != null) result.add(w);
    }
  }
  result.sort((x, y) => x.start.compareTo(y.start));
  return result;
}

/// Exception de la date, ou `null` si la journée suit l'horaire habituel.
List<MinuteWindow>? exceptionWindows(DriverAgenda a, DateTime day) {
  final key = agendaDateKey(day);
  final exceptions = a.recurrence?['exceptions'] as List? ?? const [];
  for (final raw in exceptions) {
    if (raw is Map && raw['date'] == key) {
      final windows = (raw['windows'] as List? ?? const [])
          .map(MinuteWindow.fromJson)
          .whereType<MinuteWindow>()
          .toList()
        ..sort((x, y) => x.start.compareTo(y.start));
      return windows;
    }
  }
  return null;
}

int _minuteOf(DateTime dayStart, DateTime instant) {
  final minutes = instant.toLocal().difference(dayStart).inMinutes;
  return minutes.clamp(0, 1440).toInt();
}

List<MinuteWindow> _clip(List<AgendaInterval> intervals, DateTime day) {
  final start = agendaDayStart(day), end = agendaDayEnd(day);
  final result = <MinuteWindow>[];
  for (final i in intervals) {
    if (!i.start.isBefore(end) || !i.end.isAfter(start)) continue;
    final s = _minuteOf(start, i.start.isBefore(start) ? start : i.start);
    final e = i.end.isAfter(end) ? 1440 : _minuteOf(start, i.end);
    if (e > s) result.add(MinuteWindow(s, e));
  }
  return result;
}

List<MinuteWindow> _union(List<MinuteWindow> windows) {
  final sorted = [...windows]..sort((x, y) => x.start.compareTo(y.start));
  final merged = <MinuteWindow>[];
  for (final w in sorted) {
    if (merged.isNotEmpty && w.start <= merged.last.end) {
      final last = merged.removeLast();
      merged.add(MinuteWindow(last.start, w.end > last.end ? w.end : last.end));
    } else {
      merged.add(w);
    }
  }
  return merged;
}

List<MinuteWindow> _subtract(List<MinuteWindow> from, List<MinuteWindow> cut) {
  var result = _union(from);
  for (final c in _union(cut)) {
    final next = <MinuteWindow>[];
    for (final w in result) {
      if (c.end <= w.start || c.start >= w.end) {
        next.add(w);
        continue;
      }
      if (c.start > w.start) next.add(MinuteWindow(w.start, c.start));
      if (c.end < w.end) next.add(MinuteWindow(c.end, w.end));
    }
    result = next;
  }
  return result;
}

/// État d'une journée tel que le serveur l'évaluerait (affichage).
AgendaDayInfo agendaDayInfo(DriverAgenda a, DateTime day) {
  final exception = exceptionWindows(a, day);
  final oneOff = _clip(a.windows, day);
  final blocked = _clip(a.blocked, day);
  final base = exception ?? weeklyWindows(a, day.toLocal().weekday);
  final windows = _subtract([...base, ...oneOff], blocked);
  final custom = exception != null || oneOff.isNotEmpty || blocked.isNotEmpty;
  return AgendaDayInfo(
    kind: windows.isEmpty ? AgendaDayKind.unavailable : AgendaDayKind.available,
    source: custom ? AgendaDaySource.custom : AgendaDaySource.regular,
    windows: windows,
  );
}

/// Retire de [intervals] la portion comprise dans les journées [days].
List<AgendaInterval> _withoutDays(
  List<AgendaInterval> intervals,
  Iterable<DateTime> days,
) {
  var result = [...intervals];
  for (final day in days) {
    final start = agendaDayStart(day), end = agendaDayEnd(day);
    final next = <AgendaInterval>[];
    for (final i in result) {
      if (!i.start.isBefore(end) || !i.end.isAfter(start)) {
        next.add(i);
        continue;
      }
      if (i.start.isBefore(start)) next.add(AgendaInterval(i.start, start));
      if (i.end.isAfter(end)) next.add(AgendaInterval(end, i.end));
    }
    result = next;
  }
  return result;
}

Map<String, dynamic> _withExceptions(
  Map<String, dynamic> recurrence,
  Iterable<DateTime> days,
  List<MinuteWindow>? windows,
) {
  final keys = days.map(agendaDateKey).toSet();
  final exceptions = (recurrence['exceptions'] as List)
      .where((e) => !(e is Map && keys.contains(e['date'])))
      .toList();
  if (windows != null) {
    for (final key in (keys.toList()..sort())) {
      exceptions.add({
        'date': key,
        'windows': windows.map((w) => w.toJson()).toList(),
      });
    }
  }
  return {...recurrence, 'exceptions': exceptions};
}

/// Horaire habituel : [weekdays] (1 = lundi … 7 = dimanche) passent à une
/// seule plage [start, end[ en minutes. Les autres jours ne changent pas.
DriverAgenda setWeeklyHours(
  DriverAgenda a,
  Set<int> weekdays,
  int start,
  int end,
) {
  assert(start >= 0 && end <= 1440 && end > start);
  final recurrence = _recurrence(a);
  final weekly = (recurrence['weekly'] as List)
      .where((w) => !(w is Map && weekdays.contains((w['day'] as num?)?.toInt())))
      .toList();
  for (final day in (weekdays.toList()..sort())) {
    weekly.add({'day': day, 'start_minute': start, 'end_minute': end});
  }
  return _copy(a, recurrence: {...recurrence, 'weekly': weekly});
}

/// Horaire habituel : [weekdays] ne sont plus des jours de travail.
DriverAgenda clearWeeklyHours(DriverAgenda a, Set<int> weekdays) {
  final recurrence = _recurrence(a);
  final weekly = (recurrence['weekly'] as List)
      .where((w) => !(w is Map && weekdays.contains((w['day'] as num?)?.toInt())))
      .toList();
  return _copy(a, recurrence: {...recurrence, 'weekly': weekly});
}

/// Journées choisies : disponible de [start] à [end] (minutes).
DriverAgenda setDaysAvailable(
  DriverAgenda a,
  Iterable<DateTime> days,
  int start,
  int end,
) {
  assert(start >= 0 && end <= 1440 && end > start);
  final list = days.toList();
  return _copy(
    a,
    recurrence: _withExceptions(_recurrence(a), list, [MinuteWindow(start, end)]),
    windows: _withoutDays(a.windows, list),
    blocked: _withoutDays(a.blocked, list),
  );
}

/// Journées choisies : pas disponible du tout.
DriverAgenda setDaysUnavailable(DriverAgenda a, Iterable<DateTime> days) {
  final list = days.toList();
  final blocked = _withoutDays(a.blocked, list)
    ..addAll(list.map((d) => AgendaInterval(agendaDayStart(d), agendaDayEnd(d))));
  blocked.sort((x, y) => x.start.compareTo(y.start));
  return _copy(
    a,
    recurrence: _withExceptions(_recurrence(a), list, const []),
    windows: _withoutDays(a.windows, list),
    blocked: blocked,
  );
}

/// Journées choisies : retour à l'horaire habituel.
DriverAgenda resetDays(DriverAgenda a, Iterable<DateTime> days) {
  final list = days.toList();
  return _copy(
    a,
    recurrence: _withExceptions(_recurrence(a), list, null),
    windows: _withoutDays(a.windows, list),
    blocked: _withoutDays(a.blocked, list),
  );
}

/// Avant l'enregistrement : retire ce qui est entièrement passé (exceptions
/// d'avant aujourd'hui, plages et blocages terminés avant aujourd'hui). Le
/// serveur limite ces listes ; rien d'utile n'est perdu.
DriverAgenda pruneAgenda(DriverAgenda a, DateTime now) {
  final today = agendaDayStart(now);
  final todayKey = agendaDateKey(today);
  final r = a.recurrence;
  Map<String, dynamic>? recurrence;
  if (r != null) {
    final exceptions = (r['exceptions'] as List? ?? const [])
        .where((e) => !(e is Map &&
            e['date'] is String &&
            (e['date'] as String).compareTo(todayKey) < 0))
        .toList();
    recurrence = {...r, 'exceptions': exceptions};
  }
  bool current(AgendaInterval i) => i.end.isAfter(today);
  return _copy(
    a,
    recurrence: recurrence,
    windows: a.windows.where(current).toList(),
    blocked: a.blocked.where(current).toList(),
  );
}

/// Groupes de l'horaire habituel pour l'affichage : jours consécutifs avec
/// les mêmes plages. Jours sans plage exclus.
class WeeklyGroup {
  const WeeklyGroup(this.weekdays, this.windows);
  final List<int> weekdays;
  final List<MinuteWindow> windows;
}

List<WeeklyGroup> weeklyGroups(DriverAgenda a) {
  final groups = <WeeklyGroup>[];
  String signature(List<MinuteWindow> w) =>
      w.map((x) => '${x.start}-${x.end}').join(',');
  for (var day = 1; day <= 7; day++) {
    final windows = weeklyWindows(a, day);
    if (windows.isEmpty) continue;
    final last = groups.isEmpty ? null : groups.last;
    if (last != null &&
        last.weekdays.last == day - 1 &&
        signature(last.windows) == signature(windows)) {
      last.weekdays.add(day);
    } else {
      groups.add(WeeklyGroup([day], windows));
    }
  }
  return groups;
}
