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
///
/// Simple card (owner mockup 2026-10-23): the photo, then "On dirait : …"
/// with "Oui, c'est ça" / "Non, changer". The description and category
/// fields only open when the customer wants to change the suggestion, or when
/// no suggestion is available. The customer always confirms the item.
class PhotoBookingItem extends StatefulWidget {
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
  @override
  State<PhotoBookingItem> createState() => _PhotoBookingItemState();
}

class _PhotoBookingItemState extends State<PhotoBookingItem> {
  bool _editing = false;
  Map get item => widget.item;
  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;
  String get _id => '${item['id']}';
  String get _categoryLabel =>
      widget.categories
          .where((c) => c.$1 == item['category'])
          .map((c) => c.$2)
          .firstOrNull ??
      '';

  @override
  void didUpdateWidget(covariant PhotoBookingItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A new recognition result is shown as "On dirait : …" to confirm.
    if (widget.suggestion != null &&
        !identical(widget.suggestion, oldWidget.suggestion) &&
        !widget.suggestion!.uncertain) {
      _editing = false;
    }
  }

  void _confirm() {
    item['identification_confirmed'] = true;
    setState(() => _editing = false);
    widget.onChanged();
  }

  Widget _quantity() {
    final n = (item['quantity'] as num?)?.toInt() ?? 1;
    void set(int value) {
      item['quantity'] = value;
      widget.onChanged();
    }

    return Wrap(
      key: ValueKey('photo-quantity-$_id'),
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 0,
      runSpacing: 4,
      children: [
        Text(tr('Combien ?', 'How many?', '¿Cuántos?')),
        const SizedBox(width: 8),
        IconButton.outlined(
          key: ValueKey('photo-quantity-minus-$_id'),
          tooltip: tr('Un de moins', 'One less', 'Uno menos'),
          onPressed: n > 1 ? () => set(n - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 36,
          child: Text(
            '$n',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filled(
          key: ValueKey('photo-quantity-plus-$_id'),
          tooltip: tr('Un de plus', 'One more', 'Uno más'),
          onPressed: n < 20 ? () => set(n + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  Widget _photos(List photos) => Wrap(
    spacing: 8,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      for (final p in photos)
        Stack(
          key: ValueKey(p),
          children: [
            BookingPhoto(path: p as String, loader: widget.photoLoader),
            Positioned(
              right: 0,
              top: 0,
              child: IconButton(
                key: ValueKey('photo-remove-$p'),
                tooltip: tr(
                  'Retirer cette photo',
                  'Remove this photo',
                  'Quitar esta foto',
                ),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withValues(alpha: .9),
                ),
                onPressed: widget.analysisBusy
                    ? null
                    : () {
                        photos.remove(p);
                        item.remove('photo_size_hint');
                        item['identification_confirmed'] = false;
                        widget.onChanged();
                      },
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          ],
        ),
      if (photos.length < 3)
        SizedBox(
          width: 64,
          height: 64,
          child: IconButton.outlined(
            key: ValueKey('photo-add-$_id'),
            tooltip: tr(
              'Ajouter une photo',
              'Add a photo',
              'Añadir una foto',
            ),
            onPressed: widget.onAddPhoto,
            icon: const Icon(Icons.add_a_photo_outlined, size: 26),
          ),
        ),
    ],
  );

  Widget _editor() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        widget.suggestion?.multiple == true
            ? tr(
                'On voit plusieurs articles sur la photo. Choisissez leur type et la quantité, ou prenez une photo par article.',
                'We see several items in the photo. Choose their type and the quantity, or take one photo per item.',
                'Vemos varios artículos en la foto. Elige su tipo y la cantidad, o toma una foto por artículo.',
              )
            : widget.suggestion?.uncertain == true
            ? tr(
                'On n’est pas sûr. C’est quoi ?',
                'We’re not sure. What is it?',
                'No estamos seguros. ¿Qué es?',
              )
            : tr('C’est quoi ?', 'What is it?', '¿Qué es?'),
        key: ValueKey('photo-editor-question-$_id'),
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
      const SizedBox(height: 8),
      KeyedSubtree(
        key: ValueKey('photo-category-$_id'),
        child: DropdownButtonFormField<String>(
          key: ValueKey(
            'photo-category-value-$_id-${item['photo_suggestion_revision']}',
          ),
          initialValue: widget.categories.any((c) => c.$1 == item['category'])
              ? item['category'] as String
              : 'other',
          isExpanded: true,
          itemHeight: null,
          decoration: InputDecoration(
            labelText: tr('Type d’article', 'Item type', 'Tipo de artículo'),
          ),
          items: widget.categories
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
            // An ordinary type chosen by the customer replaces the AI's
            // "special" flag (e.g. two appliances on one photo, 2026-10-25):
            // no measurements are asked for a washer, a sofa, boxes…
            if (v != 'materials' && v != 'other') {
              item['special_handling'] = false;
            }
            item.remove('photo_size_hint');
            item['identification_confirmed'] = false;
            widget.onChanged();
          },
        ),
      ),
      const SizedBox(height: 12),
      KeyedSubtree(
        key: ValueKey('photo-label-$_id'),
        child: TextFormField(
          key: ValueKey(
            'photo-label-value-$_id-${item['photo_suggestion_revision']}',
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
            widget.onChanged();
          },
        ),
      ),
    ],
  );

  Widget _specialDetails(bool needsDetails) {
    Widget measure(String field, String label, String unit) => SizedBox(
      width: 160,
      child: TextFormField(
        key: ValueKey('photo-$_id-$field'),
        initialValue: item[field]?.toString() ?? '',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '$label ($unit)',
          hintText: tr('Inconnu', 'Unknown', 'Desconocido'),
        ),
        onChanged: (value) {
          item[field] = num.tryParse(value.replaceAll(',', '.'));
          widget.onChanged();
        },
      ),
    );
    return ExpansionTile(
      key: ValueKey('photo-measures-$_id-$needsDetails'),
      initiallyExpanded: needsDetails,
      tilePadding: EdgeInsets.zero,
      title: Text(
        tr('Précisions sur l’objet', 'Item details', 'Detalles del objeto'),
      ),
      children: [
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr(
              'Objet particulier ou hors dimensions',
              'Special or oversized item',
              'Objeto especial o de gran tamaño',
            ),
          ),
          value: item['special_handling'] == true,
          onChanged: (v) {
            item['special_handling'] = v == true;
            item['identification_confirmed'] = false;
            widget.onChanged();
          },
        ),
        Text(
          tr(
            'Pour cet objet, précisez les dimensions et la manutention. Le poids peut rester inconnu.',
            'For this item, add dimensions and handling details. Weight may remain unknown.',
            'Para este objeto, indica dimensiones y manipulación. El peso puede ser desconocido.',
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            measure(
              'length',
              tr('Longueur', 'Length', 'Largo'),
              item['dimension_unit'] as String? ?? 'cm',
            ),
            measure(
              'width',
              tr('Largeur', 'Width', 'Ancho'),
              item['dimension_unit'] as String? ?? 'cm',
            ),
            measure(
              'height',
              tr('Hauteur', 'Height', 'Alto'),
              item['dimension_unit'] as String? ?? 'cm',
            ),
            measure(
              'weight',
              tr('Poids par objet', 'Weight per item', 'Peso por objeto'),
              item['weight_unit'] as String? ?? 'kg',
            ),
          ],
        ),
        TextFormField(
          key: ValueKey('photo-$_id-handling-notes'),
          initialValue: item['handling_notes'] as String? ?? '',
          minLines: 2,
          maxLines: 5,
          maxLength: 1200,
          decoration: InputDecoration(
            labelText: tr(
              'Précautions de manutention',
              'Handling precautions',
              'Precauciones de manipulación',
            ),
            hintText: tr(
              'Fragile, pièces attachées… ou « Aucune ».',
              'Fragile, bundled parts… or “None”.',
              'Frágil, piezas atadas… o «Ninguna».',
            ),
            hintMaxLines: 3,
          ),
          onChanged: (v) {
            item['handling_notes'] = v;
            widget.onChanged();
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr(
              'Mesures approximatives',
              'Approximate measurements',
              'Medidas aproximadas',
            ),
          ),
          value: item['approximate'] == true,
          onChanged: (v) {
            item['approximate'] = v == true;
            widget.onChanged();
          },
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            tr(
              'Doit rester debout',
              'Must remain upright',
              'Debe permanecer vertical',
            ),
          ),
          value: item['upright'] == true,
          onChanged: (v) {
            item['upright'] = v == true;
            widget.onChanged();
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final photos = item['photos'] as List? ?? [];
    if (isEmptyPhotoBookingItem(item)) {
      return Card(
        key: ValueKey('photo-item-$_id'),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: ValueKey('photo-add-$_id'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 56),
                  ),
                  onPressed: widget.onAddPhoto,
                  icon: const Icon(Icons.add_a_photo_outlined, size: 28),
                  label: Text(
                    tr('Prendre une photo', 'Take a photo', 'Tomar una foto'),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr(
                  'Retirer cet objet',
                  'Remove this item',
                  'Quitar este objeto',
                ),
                onPressed: widget.onRemove,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ),
      );
    }
    final confirmed = item['identification_confirmed'] == true;
    final special =
        item['special_handling'] == true ||
        ['materials', 'other'].contains(item['category']);
    final needsDetails =
        special &&
        (confirmed ||
            item['special_handling'] == true ||
            item['category'] == 'materials');
    final label = (item['label'] as String? ?? '').trim();
    // A placeholder label ("Autre objet") is not a recognized item.
    final placeholder = const [
      '',
      'Autre objet',
      'Other item',
      'Otro objeto',
    ].contains(label);
    final hasGuess = widget.suggestion != null
        ? !widget.suggestion!.uncertain
        : !placeholder;
    final showEditor = _editing || (!confirmed && !hasGuess);
    final theme = Theme.of(context);
    return Card(
      key: ValueKey('photo-item-$_id'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: confirmed ? const Color(0xFFDDE2EA) : theme.colorScheme.primary,
          width: 2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _photos(photos)),
                IconButton(
                  tooltip: tr(
                    'Retirer cet objet',
                    'Remove this item',
                    'Quitar este objeto',
                  ),
                  onPressed: widget.onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (widget.analysisError != null && !widget.analysisBusy)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  widget.analysisError!,
                  key: ValueKey('photo-analysis-error-$_id'),
                ),
              ),
            if (widget.analysisBusy) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 6),
              Text(
                tr(
                  'On reconnaît l’article…',
                  'Recognizing the item…',
                  'Reconociendo el artículo…',
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (confirmed && !_editing) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF1F6B3A)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      label.isEmpty ? _categoryLabel : label,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  TextButton(
                    key: ValueKey('photo-edit-$_id'),
                    onPressed: () => setState(() => _editing = true),
                    child: Text(tr('Modifier', 'Edit', 'Modificar')),
                  ),
                ],
              ),
              _quantity(),
            ] else if (!showEditor) ...[
              Text(
                tr('On dirait :', 'Looks like:', 'Parece:'),
                style: const TextStyle(color: Color(0xFF54607A)),
              ),
              Text(
                label,
                key: ValueKey('photo-guess-$_id'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _quantity(),
              const SizedBox(height: 8),
              // Stacked full-width buttons: large targets at any text size.
              FilledButton(
                key: ValueKey('photo-confirm-$_id'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: _confirm,
                child: Text(
                  tr('Oui, c’est ça', 'Yes, that’s it', 'Sí, es eso'),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),
              OutlinedButton(
                key: ValueKey('photo-change-$_id'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => setState(() => _editing = true),
                child: Text(
                  tr('Non, changer', 'No, change', 'No, cambiar'),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else ...[
              if (photos.isNotEmpty && widget.onAnalyzePhoto != null)
                TextButton.icon(
                  key: ValueKey('photo-analyze-$_id'),
                  onPressed: widget.analysisBusy ? null : widget.onAnalyzePhoto,
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(
                    tr('Analyser la photo', 'Analyze photo', 'Analizar foto'),
                  ),
                ),
              _editor(),
              _quantity(),
              const SizedBox(height: 8),
              FilledButton(
                key: ValueKey('photo-confirm-$_id'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: (item['label'] as String? ?? '').trim().isEmpty
                    ? null
                    : _confirm,
                child: Text(tr('C’est bon', 'Done', 'Listo')),
              ),
            ],
            if (special && !widget.analysisBusy) _specialDetails(needsDetails),
          ],
        ),
      ),
    );
  }
}
