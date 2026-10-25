/// An untrusted suggestion, never a quote, measurement or confirmed identity.
class BookingPhotoSuggestion {
  const BookingPhotoSuggestion({
    required this.category,
    required this.label,
    required this.special,
    required this.uncertain,
    this.multiple = false,
    this.quantity,
    this.sizeEstimate,
    this.sourcePhotoPath,
  });
  final String category, label;
  final bool special, uncertain;

  /// Several items on one photo (2026-10-25): the customer is asked for one
  /// photo per item, or the type and the quantity.
  final bool multiple;

  /// Pieces of the same type on the photo (a washer and a dryer = 2).
  final int? quantity;
  final BookingPhotoSizeEstimate? sizeEstimate;
  final String? sourcePhotoPath;
  static const categories = {
    'sofa',
    'armchair',
    'fridge',
    'washer',
    'table',
    'tv',
    'boxes',
    'materials',
    'other',
  };
  factory BookingPhotoSuggestion.fromResponse(
    Map<String, dynamic> response,
    String photoPath,
  ) {
    final value = response['suggestion'];
    if (response['photoPath'] != photoPath ||
        response['requiresConfirmation'] != true ||
        response['measurementsVerified'] != false ||
        response['quoteAuthorized'] != false ||
        value is! Map ||
        !categories.contains(value['category']) ||
        value['label'] is! String ||
        (value['label'] as String).trim().isEmpty ||
        (value['label'] as String).length > 160 ||
        value['special_handling'] is! bool ||
        !['low', 'medium', 'high'].contains(value['confidence']) ||
        ![
          'ordinary',
          'special',
          'uncertain',
          'multiple_objects',
        ].contains(value['reason'])) {
      throw const FormatException('Invalid photo suggestion');
    }
    // Same rule as the server (2026-10-25): only an ambiguous photo becomes
    // "other"; several pieces of one type keep their type and a quantity.
    final uncertain =
        value['confidence'] == 'low' || value['reason'] == 'uncertain';
    final rawQuantity = value['quantity'];
    if (rawQuantity != null && (rawQuantity is! int || rawQuantity < 1)) {
      throw const FormatException('Invalid quantity');
    }
    final category = uncertain ? 'other' : value['category'] as String;
    return BookingPhotoSuggestion(
      category: category,
      label: (value['label'] as String).trim(),
      special:
          value['special_handling'] == true ||
          category == 'materials' ||
          value['reason'] == 'special',
      quantity: rawQuantity is int ? (rawQuantity > 20 ? 20 : rawQuantity) : null,
      uncertain: uncertain,
      multiple: value['reason'] == 'multiple_objects',
      sizeEstimate: uncertain
          ? null
          : BookingPhotoSizeEstimate.parse(value['size_estimate']),
      sourcePhotoPath: photoPath,
    );
  }
  void applyTo(Map item) {
    if (sizeEstimate != null && sourcePhotoPath != null) {
      item['photo_size_hint'] = {
        ...sizeEstimate!.toJson(),
        'photo_path': sourcePhotoPath,
        'category': category,
        'label': label,
      };
    } else {
      item.remove('photo_size_hint');
    }
    item['category'] = category;
    item['label'] = label;
    item['special_handling'] = special || item['special_handling'] == true;
    if (quantity != null) item['quantity'] = quantity;
    item['identification_confirmed'] = false;
    item['photo_suggestion_revision'] =
        (item['photo_suggestion_revision'] as int? ?? 0) + 1;
    // Measurements, photos and money stay untouched; the quantity is only a
    // suggestion the customer confirms with the item.
  }
}

class BookingPhotoSizeEstimate {
  const BookingPhotoSizeEstimate(this.basis, this.confidence, this.ranges);
  final String basis, confidence;
  final Map<String, List<int>> ranges;
  static BookingPhotoSizeEstimate? parse(dynamic value) {
    if (value == null) return null;
    if (value is! Map ||
        value.length != 5 ||
        !['typical_object', 'visible_reference'].contains(value['basis']) ||
        !['low', 'medium'].contains(value['confidence']) ||
        (value['basis'] == 'typical_object' && value['confidence'] != 'low')) {
      throw const FormatException('Invalid estimate');
    }
    final ranges = <String, List<int>>{};
    for (final k in ['length_cm', 'width_cm', 'height_cm']) {
      final r = value[k];
      if (r is! Map ||
          r.length != 2 ||
          r['min'] is! int ||
          r['max'] is! int ||
          r['min'] < 1 ||
          r['max'] > 2000 ||
          r['min'] >= r['max']) {
        throw const FormatException('Invalid range');
      }
      ranges[k] = [r['min'] as int, r['max'] as int];
    }
    return BookingPhotoSizeEstimate(
      value['basis'] as String,
      value['confidence'] as String,
      ranges,
    );
  }

  Map<String, dynamic> toJson() => {
    'basis': basis,
    'confidence': confidence,
    for (final e in ranges.entries)
      e.key: {'min': e.value[0], 'max': e.value[1]},
  };
  static BookingPhotoSizeEstimate? forItem(Map item) {
    final v = item['photo_size_hint'], photos = item['photos'];
    if (v is! Map ||
        photos is! List ||
        photos.isEmpty ||
        photos.last != v['photo_path'] ||
        item['category'] != v['category'] ||
        item['label'] != v['label']) {
      return null;
    }
    try {
      return parse({
        for (final k in [
          'basis',
          'confidence',
          'length_cm',
          'width_cm',
          'height_cm',
        ])
          k: v[k],
      });
    } catch (_) {
      return null;
    }
  }
}
