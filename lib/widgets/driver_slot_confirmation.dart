import 'driver_dialog.dart';
import 'package:flutter/material.dart';

Future<Map<String, dynamic>?> confirmDriverSlot(
  BuildContext context, {
  required String locale,
  required Map<String, dynamic> preparation,
}) async {
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  final requested = preparation['requested_at'] as String?;
  DateTime pickup = requested == null
      ? DateTime.now()
      : DateTime.parse(requested).toLocal();
  final before = TextEditingController(text: '0'),
      total = TextEditingController();
  final form = GlobalKey<FormState>();
  bool confirmed = false;
  final result = await showDriverDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(
          tr(
            'Confirmer mon créneau complet',
            'Confirm my full time slot',
            'Confirmar mi período completo',
          ),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(
                    'Incluez le chargement, le trajet, le déchargement et les contraintes d’accès. Le devis du client reste inchangé.',
                    'Include loading, driving, unloading and access constraints. The customer’s quote remains unchanged.',
                    'Incluye carga, trayecto, descarga y restricciones de acceso. El precio del cliente no cambia.',
                  ),
                ),
                if (preparation['driver_offer_minor'] is num)
                  Text(
                    '${tr('Rémunération à confirmer', 'Compensation to confirm', 'Remuneración por confirmar')} : ${((preparation['driver_offer_minor'] as num) / 100).toStringAsFixed(2)} CAD',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                const SizedBox(height: 12),
                Text(
                  '${tr('Ramassage prévu', 'Planned pickup', 'Recogida prevista')} : $pickup',
                ),
                if (requested == null)
                  TextButton(
                    onPressed: () async {
                      final day = await showDatePicker(
                        context: ctx,
                        initialDate: pickup,
                        firstDate: DateTime.now().subtract(
                          const Duration(days: 1),
                        ),
                        lastDate: DateTime.now().add(
                          Duration(
                            minutes: (preparation['max_advance_minutes'] as num)
                                .toInt(),
                          ),
                        ),
                      );
                      if (day == null || !ctx.mounted) return;
                      final time = await showTimePicker(
                        context: ctx,
                        initialTime: TimeOfDay.fromDateTime(pickup),
                      );
                      if (time != null && ctx.mounted) {
                        set(
                          () => pickup = DateTime(
                            day.year,
                            day.month,
                            day.day,
                            time.hour,
                            time.minute,
                          ),
                        );
                      }
                    },
                    child: Text(
                      tr(
                        'Préciser mon arrivée',
                        'Set my arrival time',
                        'Indicar mi llegada',
                      ),
                    ),
                  ),
                Text(
                  '${tr('Trajet indicatif seulement', 'Driving time only', 'Solo trayecto indicativo')} : ${preparation['route_minutes']} min',
                ),
                TextFormField(
                  controller: before,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr(
                      'Temps avant le ramassage, minutes',
                      'Time before pickup, minutes',
                      'Tiempo antes de recoger, minutos',
                    ),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null || n < 0
                        ? tr(
                            'Entrez un nombre positif ou zéro',
                            'Enter zero or a positive number',
                            'Escribe cero o un número positivo',
                          )
                        : null;
                  },
                ),
                TextFormField(
                  controller: total,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: tr(
                      'Du ramassage à la fin du déchargement, minutes',
                      'From pickup to end of unloading, minutes',
                      'Desde recogida hasta fin de descarga, minutos',
                    ),
                  ),
                  validator: (v) {
                    final n = int.tryParse(v ?? '');
                    return n == null ||
                            n <= 0 ||
                            n < (preparation['route_minutes'] as num? ?? 0)
                        ? tr(
                            'Incluez le trajet et toute la manutention',
                            'Include driving and all handling',
                            'Incluye trayecto y toda la manipulación',
                          )
                        : null;
                  },
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmed,
                  onChanged: (v) => set(() => confirmed = v == true),
                  title: Text(
                    tr(
                      'Je confirme que ce créneau couvre toute la mission.',
                      'I confirm this slot covers the entire mission.',
                      'Confirmo que este período cubre toda la misión.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('Retour', 'Back', 'Volver')),
          ),
          FilledButton(
            onPressed: !confirmed
                ? null
                : () {
                    if (!form.currentState!.validate()) return;
                    final a = pickup.subtract(
                          Duration(minutes: int.parse(before.text)),
                        ),
                        b = pickup.add(
                          Duration(minutes: int.parse(total.text)),
                        );
                    Navigator.pop(ctx, {
                      'start': a.toUtc().toIso8601String(),
                      'pickup_at': pickup.toUtc().toIso8601String(),
                      'end': b.toUtc().toIso8601String(),
                      'policy_version': preparation['policy_version'],
                      'full_duration_confirmed': true,
                    });
                  },
            child: Text(
              tr(
                'Confirmer et accepter',
                'Confirm and accept',
                'Confirmar y aceptar',
              ),
            ),
          ),
        ],
      ),
    ),
  );
  before.dispose();
  total.dispose();
  return result;
}
