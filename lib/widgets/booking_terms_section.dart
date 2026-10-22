import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/booking/booking_contract.dart';

String bookingTermsLabel(String locale, String key) {
  const labels = {
    'booking': [
      'Conditions de réservation',
      'Booking terms',
      'Condiciones de reserva',
    ],
    'terms': [
      'Conditions générales de Movi-K',
      'Movi-K terms of service',
      'Condiciones generales de Movi-K',
    ],
    'privacy': [
      'Politique de confidentialité',
      'Privacy policy',
      'Política de privacidad',
    ],
  };
  return labels[key]![locale == 'en'
      ? 1
      : locale == 'es'
      ? 2
      : 0];
}

Future<void> showBookingDocument(
  BuildContext context,
  BookingContract contract,
  String key,
  String locale,
) async {
  final doc = contract.document(key);
  final content = contract.localized(doc['content'], locale);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 720,
        height: MediaQuery.sizeOf(context).height * .85,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${bookingTermsLabel(locale, key)}\nVersion ${doc['version']}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    autofocus: true,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            if (!(doc['content'] as Map).containsKey(locale))
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Document en français / French document / Documento en francés',
                ),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: SelectableText(content),
              ),
            ),
            TextButton(
              onPressed: () => launchUrl(
                Uri.parse(doc['url'] as String),
                webOnlyWindowName: '_blank',
              ),
              child: Text(
                locale == 'fr'
                    ? 'Ouvrir le document source'
                    : locale == 'en'
                    ? 'Open source document'
                    : 'Abrir documento fuente',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class BookingTermsSection extends StatelessWidget {
  const BookingTermsSection({
    super.key,
    required this.contract,
    required this.locale,
    required this.accepted,
    required this.onChanged,
    required this.beforeOpen,
  });
  final BookingContract contract;
  final String locale;
  final bool accepted;
  final ValueChanged<bool?>? onChanged;
  final Future<void> Function() beforeOpen;
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  Widget _link(BuildContext context, String key) => TextButton(
    key: ValueKey('booking-document-$key'),
    onPressed: () async {
      await beforeOpen();
      if (context.mounted) {
        await showBookingDocument(context, contract, key, locale);
      }
    },
    child: Text(bookingTermsLabel(locale, key)),
  );
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              bookingTermsLabel(locale, 'booking'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('Paiement', 'Payment', 'Pago'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(contract.localized(contract.data['payment_text'], locale)),
          const SizedBox(height: 16),
          Text(
            tr('Annulation', 'Cancellation', 'Cancelación'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(contract.localized(contract.data['cancellation_text'], locale)),
          const SizedBox(height: 12),
          Text(
            tr(
              'Une libération d’autorisation bancaire annule une somme réservée. Un remboursement concerne une somme déjà prélevée. Les conditions applicables figurent ci-dessus.',
              'Releasing an authorization cancels a reserved amount. A refund concerns an amount already charged. Applicable terms are shown above.',
              'Liberar una autorización cancela un importe retenido. Un reembolso corresponde a un importe ya cobrado. Las condiciones aplicables figuran arriba.',
            ),
          ),
          Wrap(
            spacing: 8,
            children: [_link(context, 'booking'), _link(context, 'terms')],
          ),
          CheckboxListTile(
            key: const ValueKey('booking-contract-acceptance'),
            contentPadding: EdgeInsets.zero,
            value: accepted,
            onChanged: onChanged,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(
              tr(
                'J’accepte les Conditions de réservation et les Conditions générales de Movi-K.',
                'I accept the Booking terms and the Movi-K terms of service.',
                'Acepto las Condiciones de reserva y las Condiciones generales de Movi-K.',
              ),
            ),
          ),
          _link(context, 'privacy'),
          Text(
            tr(
              'Ce document vous informe du traitement de vos données. Il est présenté séparément de l’acceptation du contrat.',
              'This document explains how your data is handled. It is presented separately from contract acceptance.',
              'Este documento explica el tratamiento de tus datos. Se presenta por separado de la aceptación del contrato.',
            ),
          ),
        ],
      ),
    ),
  );
}
