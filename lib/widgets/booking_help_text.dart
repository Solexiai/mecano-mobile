// Plain-language labels for the "help and equipment" choices, shared by the
// booking form, the price summary and the tracking screen (2026-10-23:
// "1 · personne(s)" and "Manutentionnaires: null" were shown to customers).

String _tr(String locale, String fr, String en, String es) =>
    locale == 'en' ? en : (locale == 'es' ? es : fr);

/// "1 personne pour la manutention", "2 personnes pour la manutention".
/// Returns null when the number is unknown, so callers can skip the line.
String? handlersLabel(Object? handlers, String locale) {
  final n = handlers is num ? handlers.toInt() : null;
  if (n == null || n < 1) return null;
  return n == 1
      ? _tr(
          locale,
          '1 personne pour la manutention',
          '1 person for handling',
          '1 persona para cargar',
        )
      : _tr(
          locale,
          '$n personnes pour la manutention',
          '$n people for handling',
          '$n personas para cargar',
        );
}

const _equipmentNames = {
  'dolly': ('diable', 'dolly', 'carretilla'),
  'straps': ('sangles', 'straps', 'correas'),
  'liftgate': ('hayon élévateur', 'liftgate', 'plataforma elevadora'),
};

/// "Équipement : diable, sangles" or "Aucun équipement spécial".
String equipmentLabel(Object? equipment, String locale) {
  final names = (equipment is List ? equipment : const [])
      .map((e) {
        final known = _equipmentNames[e];
        if (known == null) return e.toString();
        return _tr(locale, known.$1, known.$2, known.$3);
      })
      .where((e) => e.trim().isNotEmpty)
      .toList();
  if (names.isEmpty) {
    return _tr(
      locale,
      'Aucun équipement spécial',
      'No special equipment',
      'Sin equipo especial',
    );
  }
  return '${_tr(locale, 'Équipement', 'Equipment', 'Equipo')} : ${names.join(', ')}';
}

/// One line for the summary: "1 personne pour la manutention · Aucun équipement spécial".
String helpAndEquipmentLine(Map load, String locale) => [
  handlersLabel(load['handlers'], locale),
  equipmentLabel(load['equipment'], locale),
].whereType<String>().join(' · ');
