import 'dart:convert';
import '../../finance/presentation/money_format.dart';
import 'booking_contract.dart';

String bookingReceiptText(Map<String, dynamic> r, String locale) {
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  String yesNo(dynamic value) => value is bool
      ? value
            ? tr('Oui', 'Yes', 'Sí')
            : tr('Non', 'No', 'No')
      : '—';
  String money(num n) =>
      formatMajorAmount(n, locale: locale, currencySymbol: r'$ CA');
  final contract = BookingContract.from(r['contract']);
  final acceptance = r['acceptance'] as Map?;
  final b = r['breakdown'] as Map? ?? {};
  final load = (r['booking'] as Map?)?['load'] as Map? ?? {};
  final lines = <String>[
    tr(
      'Movi-K — Récapitulatif de la demande',
      'Movi-K — Request summary',
      'Movi-K — Resumen de solicitud',
    ),
    '${tr('Référence', 'Reference', 'Referencia')}: ${r['missionId']}',
    '${tr('Référence du prix', 'Price reference', 'Referencia del precio')}: ${r['quoteId']}',
    '${tr('Prix total accepté', 'Accepted total price', 'Precio total aceptado')}: ${money((r['customerTotalMinor'] as num) / 100)}',
    tr(
      'Ce récapitulatif ne constitue pas une preuve de paiement. Consultez le suivi pour le statut actuel.',
      'This summary is not proof of payment. Check tracking for the current status.',
      'Este resumen no es un comprobante de pago. Consulta el seguimiento para ver el estado actual.',
    ),
  ];
  const feeKeys = [
    'missionBaseValue',
    'handlingFeesTotal',
    'waitingFee',
    'additionalStopsFee',
    'surchargesTotal',
    'customerServiceFee',
    'customerDiscountAmount',
    'taxAmount',
  ];
  final feeLabels = [
    tr('Transport', 'Transport', 'Transporte'),
    tr('Manutention', 'Handling', 'Manipulación'),
    tr('Attente', 'Waiting', 'Espera'),
    tr('Arrêts supplémentaires', 'Additional stops', 'Paradas adicionales'),
    tr('Suppléments', 'Surcharges', 'Suplementos'),
    tr('Frais de service', 'Service fee', 'Tarifa de servicio'),
    tr('Remise', 'Discount', 'Descuento'),
    tr('Taxes', 'Taxes', 'Impuestos'),
  ];
  for (var i = 0; i < feeKeys.length; i++) {
    if (b[feeKeys[i]] is num) {
      lines.add('${feeLabels[i]}: ${money(b[feeKeys[i]] as num)}');
    }
  }
  for (final key in ['pickup', 'dropoff']) {
    final address = r[key] as Map? ?? {};
    final access = load[key] as Map? ?? {};
    lines.add(
      '${key == 'pickup' ? tr('Ramassage', 'Pickup', 'Recogida') : tr('Livraison', 'Delivery', 'Entrega')}: ${[address['line1'], address['city'], address['postal_code']].whereType<String>().join(', ')}',
    );
    lines.add(
      '${tr('Étage', 'Floor', 'Piso')}: ${access['floor'] ?? '—'}; ${tr('Escaliers', 'Stairs', 'Escaleras')}: ${yesNo(access['stairs'])}; ${tr('Aide incluse', 'Included help', 'Ayuda incluida')}: ${yesNo(access['help'])}',
    );
  }
  for (final item in load['items'] as List? ?? []) {
    lines.add('${item['quantity']} × ${item['label']}');
  }
  lines.add(
    '${tr('Manutentionnaires', 'Handlers', 'Personas para cargar')}: ${load['handlers'] ?? '—'}',
  );
  final equipmentLabels = {
    'dolly': tr('Diable', 'Dolly', 'Carretilla'),
    'straps': tr('Sangles', 'Straps', 'Correas'),
    'liftgate': tr('Hayon élévateur', 'Liftgate', 'Plataforma elevadora'),
  };
  lines.add(
    '${tr('Équipement compris', 'Included equipment', 'Equipo incluido')}: ${(load['equipment'] as List? ?? []).map((key) => equipmentLabels[key] ?? key).join(', ')}',
  );
  for (final key in ['pickup', 'dropoff']) {
    final access = load[key] as Map? ?? {};
    lines.add(
      '${key == 'pickup' ? tr('Ramassage', 'Pickup', 'Recogida') : tr('Livraison', 'Delivery', 'Entrega')} — ${tr('Ascenseur', 'Elevator', 'Ascensor')}: ${access['elevator'] == null
          ? '—'
          : access['elevator'] == true
          ? tr('Oui', 'Yes', 'Sí')
          : tr('Non', 'No', 'No')}',
    );
  }
  if (load['timing_mode'] == 'immediate') {
    lines.add(
      tr(
        'Demandée dès maintenant, selon la disponibilité du chauffeur.',
        'Requested as soon as possible, subject to driver availability.',
        'Solicitada lo antes posible, según la disponibilidad del conductor.',
      ),
    );
  } else if (load['requested_at'] != null) {
    lines.add(
      '${tr('Date demandée, à confirmer', 'Requested time, to be confirmed', 'Fecha solicitada, por confirmar')}: ${load['requested_at']}',
    );
  }
  if (contract != null) {
    final millis = acceptance?['acceptedAtMillis'];
    lines.add(
      '${tr('Acceptation enregistrée', 'Acceptance recorded', 'Aceptación registrada')}: ${millis is num ? DateTime.fromMillisecondsSinceEpoch(millis.toInt(), isUtc: true).toIso8601String() : '—'}',
    );
    for (final key in ['booking', 'terms', 'privacy']) {
      final doc = contract.document(key);
      final title = key == 'booking'
          ? tr(
              'Conditions de réservation',
              'Booking terms',
              'Condiciones de reserva',
            )
          : key == 'terms'
          ? tr(
              'Conditions générales',
              'Terms of service',
              'Condiciones generales',
            )
          : tr(
              'Politique de confidentialité présentée',
              'Privacy policy presented',
              'Política de privacidad presentada',
            );
      lines.add(
        '\n$title — version ${doc['version']}\n${doc['url']}\n${contract.localized(doc['content'], locale)}',
      );
    }
    lines.add(
      '\n${contract.localized(contract.data['payment_text'], locale)}\n${contract.localized(contract.data['cancellation_text'], locale)}',
    );
  } else {
    lines.add(
      tr(
        'Le texte intégral des conditions d’origine n’a pas été archivé pour cette demande. Aucune condition actuelle ne lui est substituée.',
        'The full original terms were not archived for this request. Current terms are not substituted.',
        'No se archivó el texto completo de las condiciones originales. No se sustituyen por las condiciones actuales.',
      ),
    );
    final legacy = r['legacyTerms'] as Map?;
    if (legacy != null) {
      for (final key in ['payment_text', 'cancellation_text']) {
        final text = legacy[key] as Map?;
        if (text != null) lines.add('${text[locale] ?? text['fr'] ?? ''}');
      }
    }
  }
  return lines.join('\n\n');
}

String bookingReceiptHtml(Map<String, dynamic> receipt, String locale) {
  const escape = HtmlEscape();
  return '<!doctype html><html lang="${['fr', 'en', 'es'].contains(locale) ? locale : 'fr'}"><meta charset="utf-8">'
      '<meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="Content-Security-Policy" content="default-src \'none\'; style-src \'unsafe-inline\'">'
      '<title>Movi-K</title><style>body{font:16px/1.5 sans-serif;margin:2rem auto;padding:1rem;max-width:50rem;color:#101c34}pre{font:inherit;white-space:pre-wrap;overflow-wrap:anywhere}@media print{body{margin:0;max-width:none}}</style>'
      '<body><pre>${escape.convert(bookingReceiptText(receipt, locale))}</pre></body></html>';
}
