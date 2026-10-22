import 'package:flutter/material.dart';
import 'booking_load_summary.dart';
import '../services/booking/booking_photo_analysis.dart';

// Recognize only untouched placeholders; never discard entered cargo details.
bool isEmptyPhotoBookingItem(Map item) =>
    (item['photos'] as List? ?? []).isEmpty &&
    item['category'] == 'other' &&
    [
      '',
      'Autre objet',
      'Other item',
      'Otro objeto',
    ].contains(item['label'] ?? '') &&
    item['quantity'] == 1 &&
    ['length', 'width', 'height', 'weight'].every((key) => item[key] == null) &&
    (item['handling_notes'] as String? ?? '').isEmpty &&
    item['identification_confirmed'] != true &&
    item['special_handling'] != true &&
    item['approximate'] != true &&
    item['upright'] != false;

/// Photo intake only: advisory estimates never fill actual measurements.
class PhotoBookingItem extends StatelessWidget {
  const PhotoBookingItem({
    super.key,
    required this.item,
    required this.locale,
    required this.categories,
    required this.onChanged,
    required this.onRemove,
    required this.onAddPhoto,
    this.photoLoader,
    this.onAnalyzePhoto,
    this.suggestion,
    this.analysisError,
    this.analysisBusy = false,
  });
  final Map item;
  final String locale;
  final List<(String, String)> categories;
  final VoidCallback onChanged, onRemove, onAddPhoto;
  final BookingPhotoLoader? photoLoader;
  final VoidCallback? onAnalyzePhoto;
  final BookingPhotoSuggestion? suggestion;
  final String? analysisError;
  final bool analysisBusy;
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  @override
  Widget build(BuildContext context) {
    final photos = item['photos'] as List? ?? [];
    final estimate =
        suggestion?.sizeEstimate ?? BookingPhotoSizeEstimate.forItem(item);
    Widget addPhoto() => SizedBox(
      width: 64,
      height: 64,
      child: IconButton.outlined(
        key: ValueKey('photo-add-${item['id']}'),
        tooltip: tr('Ajouter une photo', 'Add a photo', 'Añadir una foto'),
        onPressed: onAddPhoto,
        icon: const Icon(Icons.add, size: 28),
      ),
    );
    if (isEmptyPhotoBookingItem(item)) {
      return Card(
        key: ValueKey('photo-item-${item['id']}'),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('photo-add-${item['id']}'),
                  onPressed: onAddPhoto,
                  icon: const Icon(Icons.add, size: 28),
                  label: Text(
                    tr('Ajouter une photo', 'Add a photo', 'Añadir una foto'),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr(
                  'Retirer cet objet',
                  'Remove this item',
                  'Quitar este objeto',
                ),
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      );
    }
    return Card(
      key: ValueKey('photo-item-${item['id']}'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in photos)
                  Column(
                    key: ValueKey(p),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      BookingPhoto(path: p as String, loader: photoLoader),
                      IconButton(
                        key: ValueKey('photo-remove-$p'),
                        tooltip: tr(
                          'Retirer cette photo',
                          'Remove this photo',
                          'Quitar esta foto',
                        ),
                        onPressed: analysisBusy
                            ? null
                            : () {
                                photos.remove(p);
                                item.remove('photo_size_hint');
                                item['identification_confirmed'] = false;
                                onChanged();
                              },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                if (photos.length < 3) addPhoto(),
              ],
            ),
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                if (photos.isNotEmpty && onAnalyzePhoto != null)
                  TextButton.icon(
                    key: ValueKey('photo-analyze-${item['id']}'),
                    onPressed: analysisBusy ? null : onAnalyzePhoto,
                    icon: const Icon(Icons.auto_awesome_outlined),
                    label: Text(
                      tr('Analyser la photo', 'Analyze photo', 'Analizar foto'),
                    ),
                  ),
              ],
            ),
            Text(
              tr(
                'JPG, PNG ou WebP · 20 Mo maximum',
                'JPG, PNG or WebP · up to 20 MB',
                'JPG, PNG o WebP · hasta 20 MB',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (photos.isNotEmpty && onAnalyzePhoto != null)
              Text(
                tr(
                  'Catégorie et description remplies automatiquement. Vérifiez le résultat.',
                  'Category and description filled automatically. Check the result.',
                  'Categoría y descripción completadas automáticamente. Revisa el resultado.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if (analysisBusy) ...[
              const LinearProgressIndicator(),
              Text(
                tr(
                  'Préparation et analyse de la photo…',
                  'Preparing and analyzing the photo…',
                  'Preparando y analizando la foto…',
                ),
              ),
            ],
            if (analysisError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  analysisError!,
                  key: ValueKey('photo-analysis-error-${item['id']}'),
                ),
              ),
            if (suggestion != null) ...[
              const SizedBox(height: 12),
              Text(
                tr('Suggestion IA : ', 'AI suggestion: ', 'Sugerencia IA: ') +
                    suggestion!.label,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (suggestion!.uncertain)
                Text(
                  tr(
                    'Objet incertain : choisissez sa catégorie.',
                    'Uncertain item: choose its category.',
                    'Objeto incierto: elige su categoría.',
                  ),
                ),
            ],
            if (estimate != null) ...[
              const SizedBox(height: 8),
              Text(
                tr(
                  'Dimensions estimées',
                  'Estimated dimensions',
                  'Dimensiones estimadas',
                ),
                style: Theme.of(context).textTheme.titleSmall,
              ),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  for (final axis in [
                    ('length_cm', tr('Longueur', 'Length', 'Largo')),
                    ('width_cm', tr('Profondeur', 'Depth', 'Fondo')),
                    ('height_cm', tr('Hauteur', 'Height', 'Alto')),
                  ])
                    Text(
                      '${axis.$2} : ${estimate.ranges[axis.$1]![0]}–${estimate.ranges[axis.$1]![1]} cm',
                    ),
                ],
              ),
              Text(
                estimate.basis == 'typical_object'
                    ? tr(
                        'Taille habituelle de ce type d’objet, à confirmer.',
                        'Typical size for this kind of item; please verify.',
                        'Tamaño habitual de este tipo de objeto; por confirmar.',
                      )
                    : tr(
                        'Estimation visuelle à confirmer.',
                        'Visual estimate; please verify.',
                        'Estimación visual por confirmar.',
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (suggestion != null)
              Text(
                tr(
                  'Dimensions inconnues : vous pouvez continuer pour un objet ordinaire.',
                  'Dimensions unknown: you can continue for an ordinary item.',
                  'Dimensiones desconocidas: puedes continuar para un objeto común.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: ValueKey('photo-label-${item['id']}'),
              child: TextFormField(
                key: ValueKey(
                  'photo-label-value-${item['id']}-${item['photo_suggestion_revision']}',
                ),
                initialValue: item['label'] as String? ?? '',
                maxLength: 160,
                decoration: InputDecoration(
                  labelText: tr(
                    'Description courte',
                    'Short description',
                    'Descripción breve',
                  ),
                ),
                onChanged: (v) {
                  item['label'] = v;
                  item.remove('photo_size_hint');
                  item['identification_confirmed'] = false;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 12),
            KeyedSubtree(
              key: ValueKey('photo-category-${item['id']}'),
              child: DropdownButtonFormField<String>(
                key: ValueKey(
                  'photo-category-value-${item['id']}-${item['photo_suggestion_revision']}',
                ),
                initialValue: categories.any((c) => c.$1 == item['category'])
                    ? item['category'] as String
                    : 'other',
                isExpanded: true,
                itemHeight: null,
                decoration: InputDecoration(
                  labelText: tr('Catégorie', 'Category', 'Categoría'),
                ),
                items: categories
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.$1,
                        child: Text(c.$2, maxLines: 2),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v == null) return;
                  item['category'] = v;
                  item.remove('photo_size_hint');
                  item['identification_confirmed'] = false;
                  onChanged();
                },
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('photo-quantity-${item['id']}'),
              initialValue: (item['quantity'] as num).toInt(),
              decoration: InputDecoration(
                labelText: tr('Quantité', 'Quantity', 'Cantidad'),
              ),
              items: List.generate(
                20,
                (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}')),
              ),
              onChanged: (v) {
                if (v != null) {
                  item['quantity'] = v;
                  onChanged();
                }
              },
            ),
            CheckboxListTile(
              key: ValueKey('photo-confirm-${item['id']}'),
              contentPadding: EdgeInsets.zero,
              title: Text(
                tr(
                  'Je confirme la catégorie et l’objet.',
                  'I confirm the category and item.',
                  'Confirmo la categoría y el objeto.',
                ),
              ),
              value: item['identification_confirmed'] == true,
              onChanged: (v) {
                item['identification_confirmed'] = v == true;
                onChanged();
              },
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline),
                label: Text(
                  tr(
                    'Retirer cet objet',
                    'Remove this item',
                    'Quitar este objeto',
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
