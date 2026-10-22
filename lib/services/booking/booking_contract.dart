/// Server-provided, versioned terms. No prices or commercial rules are derived here.
class BookingContract {
  BookingContract(this.data);
  final Map<String, dynamic> data;
  static BookingContract? from(dynamic value) {
    if (value is! Map ||
        value['approved'] != true ||
        value['schema_version'] != 2 ||
        value['contract_hash'] is! String ||
        (value['contract_hash'] as String).isEmpty) {
      return null;
    }
    final documents = value['documents'];
    if (documents is! Map) return null;
    for (final key in ['booking', 'terms', 'privacy']) {
      final doc = documents[key];
      if (doc is! Map ||
          doc['version'] is! String ||
          doc['content'] is! Map ||
          ((doc['content'] as Map)['fr'] as String? ?? '').trim().isEmpty) {
        return null;
      }
    }
    return BookingContract(Map<String, dynamic>.from(value));
  }

  String get hash => data['contract_hash'] as String;
  Map<String, dynamic> document(String key) =>
      Map<String, dynamic>.from((data['documents'] as Map)[key] as Map);
  String localized(dynamic value, String locale) {
    final map = value as Map? ?? {};
    return (map[locale] ?? map['fr'] ?? '') as String;
  }

  Map<String, dynamic> consent(
    String locale, {
    required bool accepted,
    required bool marketing,
  }) => {
    'accepted': accepted,
    'terms_version': data['version'],
    'contract_hash': hash,
    'booking_terms_version': document('booking')['version'],
    'general_terms_version': document('terms')['version'],
    'privacy_presented_version': document('privacy')['version'],
    'locale': locale,
    'marketing': marketing,
  };
}
