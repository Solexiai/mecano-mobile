import 'driver_dialog.dart';
import 'package:flutter/material.dart';

class DriverRecurrenceEditor extends StatefulWidget {
  const DriverRecurrenceEditor({
    super.key,
    required this.value,
    required this.onChanged,
    required this.locale,
    this.enabled = true,
  });
  final Map<String, dynamic>? value;
  final ValueChanged<Map<String, dynamic>> onChanged;
  final String locale;
  final bool enabled;
  @override
  State<DriverRecurrenceEditor> createState() => _DriverRecurrenceEditorState();
}

class _DriverRecurrenceEditorState extends State<DriverRecurrenceEditor> {
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  Map<String, dynamic> get value =>
      widget.value ??
      {
        'time_zone': 'America/Toronto',
        'weekly': <dynamic>[],
        'exceptions': <dynamic>[],
        'pause_before_minutes': 0,
        'pause_after_minutes': 0,
      };
  List get weekly => List.from(value['weekly'] as List? ?? []);
  List get exceptions => List.from(value['exceptions'] as List? ?? []);
  void change(String key, dynamic data) =>
      widget.onChanged({...value, key: data});
  String time(dynamic m) =>
      '${'${(m as int) ~/ 60}'.padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';
  String day(int i) => [
    tr('Lundi', 'Monday', 'Lunes'),
    tr('Mardi', 'Tuesday', 'Martes'),
    tr('Mercredi', 'Wednesday', 'Miércoles'),
    tr('Jeudi', 'Thursday', 'Jueves'),
    tr('Vendredi', 'Friday', 'Viernes'),
    tr('Samedi', 'Saturday', 'Sábado'),
    tr('Dimanche', 'Sunday', 'Domingo'),
  ][i - 1];
  Future<Map<String, int>?> hours() async {
    final start = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: tr('Début', 'Start', 'Inicio'),
    );
    if (start == null || !mounted) return null;
    final end = await showTimePicker(
      context: context,
      initialTime: start,
      helpText: tr('Fin', 'End', 'Fin'),
    );
    if (end == null || !mounted) return null;
    final a = start.hour * 60 + start.minute;
    final endMinute = end.hour * 60 + end.minute;
    final b = endMinute == 0 ? 1440 : endMinute;
    if (b <= a) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              'La fin doit suivre le début. Séparez les plages à minuit.',
              'End must follow start. Split periods at midnight.',
              'El fin debe seguir al inicio. Divide los períodos a medianoche.',
            ),
          ),
        ),
      );
      return null;
    }
    return {'start_minute': a, 'end_minute': b};
  }

  Future<void> addWeekly() async {
    final d = await showDriverDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(tr('Jour de la semaine', 'Weekday', 'Día de la semana')),
        children: [
          for (int i = 1; i <= 7; i++)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, i),
              child: Text(day(i)),
            ),
        ],
      ),
    );
    if (d == null || !mounted) return;
    final w = await hours();
    if (w == null || !mounted) return;
    change('weekly', [
      ...weekly,
      {'day': d, ...w},
    ]);
  }

  Future<void> addException(bool closed) async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final key =
        '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    Map<String, int>? w;
    if (!closed) {
      w = await hours();
      if (w == null || !mounted) return;
    }
    final old = exceptions.where((e) => e['date'] == key).firstOrNull;
    final windows = closed ? <dynamic>[] : [...?old?['windows'] as List?, w];
    change('exceptions', [
      ...exceptions.where((e) => e['date'] != key),
      {'date': key, 'windows': windows},
    ]);
  }

  Future<void> editSettings() async {
    final zone = TextEditingController(
      text: value['time_zone'] as String? ?? 'America/Toronto',
    );
    final before = TextEditingController(
      text: '${value['pause_before_minutes'] ?? 0}',
    );
    final after = TextEditingController(
      text: '${value['pause_after_minutes'] ?? 0}',
    );
    final form = GlobalKey<FormState>();
    final ok = await showDriverDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr(
            'Fuseau et pauses',
            'Time zone and breaks',
            'Zona horaria y pausas',
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: zone,
                  decoration: InputDecoration(
                    labelText: tr('Fuseau IANA', 'IANA time zone', 'Zona IANA'),
                    helperText: 'America/Toronto',
                  ),
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? tr('Champ requis', 'Required', 'Obligatorio')
                      : null,
                ),
                for (final entry in [
                  (
                    before,
                    tr(
                      'Pause avant, en minutes',
                      'Break before, minutes',
                      'Pausa antes, minutos',
                    ),
                  ),
                  (
                    after,
                    tr(
                      'Pause après, en minutes',
                      'Break after, minutes',
                      'Pausa después, minutos',
                    ),
                  ),
                ])
                  TextFormField(
                    controller: entry.$1,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(labelText: entry.$2),
                    validator: (v) {
                      final n = int.tryParse(v ?? '');
                      return n == null || n < 0 || n > 1440
                          ? tr(
                              'De 0 à 1440 minutes',
                              '0 to 1440 minutes',
                              'De 0 a 1440 minutos',
                            )
                          : null;
                    },
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr('Retour', 'Back', 'Volver')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, true);
            },
            child: Text(tr('Appliquer', 'Apply', 'Aplicar')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      widget.onChanged({
        ...value,
        'time_zone': zone.text.trim(),
        'pause_before_minutes': int.parse(before.text),
        'pause_after_minutes': int.parse(after.text),
      });
    }
    zone.dispose();
    before.dispose();
    after.dispose();
  }

  @override
  Widget build(BuildContext context) => ExpansionTile(
    title: Text(
      tr(
        'Horaire régulier et exceptions',
        'Regular hours and exceptions',
        'Horario regular y excepciones',
      ),
    ),
    subtitle: Text(
      '${value['time_zone']} · ${weekly.length} ${tr('plages régulières', 'regular periods', 'períodos regulares')}',
    ),
    childrenPadding: const EdgeInsets.all(12),
    children: [
      Text(
        tr(
          'Les exceptions remplacent l’horaire régulier de la journée. Les blocages manuels restent prioritaires.',
          'Exceptions replace that day’s regular hours. Manual blocks take priority.',
          'Las excepciones sustituyen el horario regular del día. Los bloqueos manuales tienen prioridad.',
        ),
      ),
      for (var i = 0; i < weekly.length; i++)
        ListTile(
          title: Text(
            '${day(weekly[i]['day'])} · ${time(weekly[i]['start_minute'])}–${time(weekly[i]['end_minute'])}',
          ),
          trailing: IconButton(
            tooltip: tr('Retirer', 'Remove', 'Eliminar'),
            onPressed: widget.enabled
                ? () => change('weekly', weekly..removeAt(i))
                : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      for (var i = 0; i < exceptions.length; i++)
        ListTile(
          title: Text(
            '${exceptions[i]['date']} · ${(exceptions[i]['windows'] as List).isEmpty ? tr('Indisponible', 'Unavailable', 'No disponible') : (exceptions[i]['windows'] as List).map((w) => '${time(w['start_minute'])}–${time(w['end_minute'])}').join(', ')}',
          ),
          trailing: IconButton(
            tooltip: tr(
              'Retirer l’exception',
              'Remove exception',
              'Eliminar excepción',
            ),
            onPressed: widget.enabled
                ? () => change('exceptions', exceptions..removeAt(i))
                : null,
            icon: const Icon(Icons.delete_outline),
          ),
        ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          OutlinedButton(
            onPressed: widget.enabled ? addWeekly : null,
            child: Text(
              tr(
                'Ajouter un horaire régulier',
                'Add regular hours',
                'Añadir horario regular',
              ),
            ),
          ),
          OutlinedButton(
            onPressed: widget.enabled ? () => addException(false) : null,
            child: Text(
              tr(
                'Disponibilité exceptionnelle',
                'Special availability',
                'Disponibilidad excepcional',
              ),
            ),
          ),
          OutlinedButton(
            onPressed: widget.enabled ? () => addException(true) : null,
            child: Text(
              tr('Journée indisponible', 'Day off', 'Día no disponible'),
            ),
          ),
          TextButton(
            onPressed: widget.enabled ? editSettings : null,
            child: Text(
              tr(
                'Fuseau et pauses',
                'Time zone and breaks',
                'Zona horaria y pausas',
              ),
            ),
          ),
        ],
      ),
    ],
  );
}
