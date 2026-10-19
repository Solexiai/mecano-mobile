import 'package:flutter/material.dart';
import '../core/app_colors.dart';

String accessSummary(Map a, String locale) {
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  final confirmed = a['confirmed_fields'] as List? ?? const [];
  if (!confirmed.contains('floor') || !confirmed.contains('stairs')) {
    return tr(
      'Accès à préciser',
      'Access details needed',
      'Acceso por precisar',
    );
  }
  final floor = a['floor'];
  final level = floor == 0
      ? tr('Rez-de-chaussée', 'Ground floor', 'Planta baja')
      : tr(
          '$floor${floor == 1 ? 'er' : 'e'} étage',
          'Floor $floor',
          'Piso $floor',
        );
  return [
    level,
    a['stairs'] == true
        ? tr('Escaliers', 'Stairs', 'Escaleras')
        : tr('Sans marches', 'No steps', 'Sin escalones'),
    if (confirmed.contains('elevator') && a['elevator'] == true)
      tr('Ascenseur', 'Elevator', 'Ascensor'),
  ].join(' · ');
}

/// null is an unanswered question, never a free-service selection.
bool accessAnswersComplete(Map a) =>
    a['help'] is bool &&
    a['floor'] is int &&
    (a['floor'] as int) >= -10 &&
    (a['floor'] as int) <= 200 &&
    a['stairs'] is bool &&
    a['elevator'] is bool &&
    [
      'floor',
      'stairs',
      'elevator',
    ].every((k) => (a['confirmed_fields'] as List? ?? []).contains(k)) &&
    a['inside'] is bool &&
    (a['help'] != true ||
        ['yes', 'no', 'unknown'].contains(a['onsite_help'])) &&
    !(a['help'] == false &&
        a['inside'] == true &&
        a['customer_handles_inside'] != true);

class BookingAccessSection extends StatelessWidget {
  const BookingAccessSection({
    super.key,
    required this.access,
    required this.pickup,
    required this.locale,
    required this.onChanged,
  });
  final Map access;
  final bool pickup;
  final String locale;
  final VoidCallback onChanged;
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  String get prefix => pickup ? 'pickup' : 'dropoff';
  void set(String name, dynamic value) {
    access[name] = value;
    access['details_version'] = 1;
    final fields = List<String>.from(access['confirmed_fields'] as List? ?? []);
    if (!fields.contains(name)) fields.add(name);
    access['confirmed_fields'] = fields;
    onChanged();
  }

  Widget choices(String name, String title, List<(dynamic, String)> values) =>
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: values
                  .map(
                    (v) => ChoiceChip(
                      key: ValueKey('$prefix-$name-${v.$1}'),
                      label: Text(v.$2),
                      selected:
                          access[name] == v.$1 &&
                          (name != 'stairs' && name != 'elevator' ||
                              (access['confirmed_fields'] as List? ?? [])
                                  .contains(name)),
                      onSelected: (_) => set(name, v.$1),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
  List<(dynamic, String)> get yesNo => [
    (true, tr('Oui', 'Yes', 'Sí')),
    (false, tr('Non', 'No', 'No')),
  ];

  Widget card(bool value) {
    final selected = access['help'] == value;
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        child: OutlinedButton(
          key: ValueKey('$prefix-help-$value'),
          onPressed: () => set('help', value),
          style: OutlinedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.primary,
            padding: const EdgeInsets.all(14),
            alignment: Alignment.centerLeft,
            side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 2 : 1,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      value
                          ? tr(
                              'Avec aide Movi-K',
                              'With Movi-K help',
                              'Con ayuda Movi-K',
                            )
                          : tr(
                              'Sans aide Movi-K',
                              'Without Movi-K help',
                              'Sin ayuda Movi-K',
                            ),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value
                          ? tr(
                              'À inclure dans mon devis.',
                              'Include in my quote.',
                              'Incluir en mi presupuesto.',
                            )
                          : pickup
                          ? tr(
                              'Nous organisons le chargement.',
                              'We arrange loading.',
                              'Organizamos la carga.',
                            )
                          : tr(
                              'Nous organisons le déchargement.',
                              'We arrange unloading.',
                              'Organizamos la descarga.',
                            ),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 12),
      Material(
        key: ValueKey('$prefix-help-block'),
        color: Color.alphaBlend(
          AppColors.info.withValues(alpha: .07),
          Colors.white,
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 56,
                      height: 40,
                      child: CustomPaint(painter: _CargoIllustration(pickup)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      pickup
                          ? tr(
                              'Besoin d’aide pour charger ?',
                              'Need help loading?',
                              '¿Necesitas ayuda para cargar?',
                            )
                          : tr(
                              'Besoin d’aide pour décharger ?',
                              'Need help unloading?',
                              '¿Necesitas ayuda para descargar?',
                            ),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) =>
                    c.maxWidth >= 580 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.3
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: card(false)),
                          const SizedBox(width: 10),
                          Expanded(child: card(true)),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          card(false),
                          const SizedBox(height: 8),
                          card(true),
                        ],
                      ),
              ),
              if (access['help'] == true) ...[
                choices(
                  'onsite_help',
                  tr(
                    'Quelqu’un sur place pourra-t-il aider à soulever ?',
                    'Can someone on site help lift?',
                    '¿Alguien podrá ayudar a levantar?',
                  ),
                  [
                    ('yes', tr('Oui', 'Yes', 'Sí')),
                    ('no', tr('Non', 'No', 'No')),
                    (
                      'unknown',
                      tr('À confirmer', 'To confirm', 'Por confirmar'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  tr(
                    'Cette réponse ne confirme pas que l’effectif sera suffisant.',
                    'This answer does not confirm that the crew will be sufficient.',
                    'Esta respuesta no confirma que el equipo sea suficiente.',
                  ),
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ],
              if (access['help'] is bool) ...[
                choices(
                  'inside',
                  pickup
                      ? tr(
                          'Faut-il aller chercher les objets à l’intérieur ?',
                          'Must items be collected indoors?',
                          '¿Hay que recoger los objetos dentro?',
                        )
                      : tr(
                          'Faut-il déposer les objets à l’intérieur ?',
                          'Must items be delivered indoors?',
                          '¿Hay que dejar los objetos dentro?',
                        ),
                  yesNo,
                ),
                if (access['help'] == false && access['inside'] == true) ...[
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      'Vous avez choisi sans aide Movi-K. Précisez qui assure le déplacement entre l’intérieur et le véhicule. Aucun service payant ne sera ajouté automatiquement.',
                      'You selected no Movi-K help. Confirm who moves items between indoors and the vehicle. No paid service will be added automatically.',
                      'Elegiste sin ayuda Movi-K. Confirma quién mueve los objetos entre el interior y el vehículo. No se añadirá ningún servicio de pago automáticamente.',
                    ),
                  ),
                  CheckboxListTile(
                    key: ValueKey('$prefix-customer-inside'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(
                      tr(
                        'Nous organisons nous-mêmes ce déplacement.',
                        'We arrange this movement ourselves.',
                        'Organizamos este traslado.',
                      ),
                    ),
                    value: access['customer_handles_inside'] == true,
                    onChanged: (v) => set('customer_handles_inside', v == true),
                  ),
                ],
              ],
              const SizedBox(height: 10),
              Text(
                tr(
                  'Le coût de l’aide sera indiqué dans votre devis avant confirmation.',
                  'The cost of help will appear in your quote before confirmation.',
                  'El coste de la ayuda aparecerá en el presupuesto antes de confirmar.',
                ),
                style: const TextStyle(color: AppColors.primary),
              ),
            ],
          ),
        ),
      ),
      ExpansionTile(
        key: ValueKey('$prefix-access-details'),
        maintainState: true,
        tilePadding: EdgeInsets.zero,
        title: Text(
          pickup
              ? tr('Accès au ramassage', 'Pickup access', 'Acceso de recogida')
              : tr(
                  'Accès à la livraison',
                  'Delivery access',
                  'Acceso de entrega',
                ),
        ),
        subtitle: Text(accessSummary(access, locale)),
        children: [
          TextFormField(
            key: ValueKey('$prefix-floor'),
            initialValue:
                (access['confirmed_fields'] as List? ?? []).contains('floor')
                ? '${access['floor']}'
                : '',
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            decoration: InputDecoration(
              labelText: tr(
                'Niveau (0 = rez-de-chaussée)',
                'Level (0 = ground floor)',
                'Nivel (0 = planta baja)',
              ),
            ),
            onChanged: (v) => set('floor', int.tryParse(v)),
          ),
          choices(
            'stairs',
            tr(
              'Y a-t-il des marches ou des escaliers ?',
              'Are there steps or stairs?',
              '¿Hay escalones o escaleras?',
            ),
            yesNo,
          ),
          choices(
            'elevator',
            tr(
              'Y a-t-il un ascenseur ?',
              'Is there an elevator?',
              '¿Hay ascensor?',
            ),
            yesNo,
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: ValueKey('$prefix-access-notes'),
            initialValue: access['notes'] as String? ?? '',
            minLines: 1,
            maxLines: 3,
            maxLength: 1200,
            decoration: InputDecoration(
              labelText: tr(
                'Contraintes particulières (facultatif)',
                'Special access constraints (optional)',
                'Restricciones de acceso (opcional)',
              ),
            ),
            onChanged: (v) => set('notes', v),
          ),
        ],
      ),
    ],
  );
}

/// Small matching vector pictograms: inward/outward arrow and the same cargo van.
class _CargoIllustration extends CustomPainter {
  _CargoIllustration(this.loading);
  final bool loading;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 56, size.height / 40);
    final p = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeJoin = StrokeJoin.round;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(22, 7, 25, 22),
        const Radius.circular(3),
      ),
      p,
    );
    canvas.drawPath(
      Path()
        ..moveTo(47, 14)
        ..lineTo(53, 21)
        ..lineTo(53, 29)
        ..lineTo(47, 29),
      p,
    );
    for (final x in [28.0, 47.0]) {
      canvas.drawCircle(Offset(x, 31), 3, p);
    }
    canvas.drawRect(const Rect.fromLTWH(3, 18, 11, 11), p);
    canvas.drawLine(const Offset(8.5, 18), const Offset(8.5, 22), p);
    p.color = AppColors.primaryLight;
    final start = loading ? 15.0 : 34.0,
        end = loading ? 34.0 : 15.0,
        dx = loading ? -4.0 : 4.0;
    canvas.drawLine(Offset(start, 12), Offset(end, 12), p);
    canvas.drawPath(
      Path()
        ..moveTo(end + dx, 8)
        ..lineTo(end, 12)
        ..lineTo(end + dx, 16),
      p,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CargoIllustration oldDelegate) =>
      oldDelegate.loading != loading;
}
