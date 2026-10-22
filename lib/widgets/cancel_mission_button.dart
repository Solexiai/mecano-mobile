// Customer cancellation (fee policy of 2026-10-22, see
// functions/src/lib/missionFees.ts). The server first says which fee would
// apply; the customer sees that exact amount before confirming, and the
// server refuses the cancellation if the amount changed in between.
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../services/booking/booking_api.dart';

/// Statuses where the customer may cancel (before pickup).
const customerCancellableStatuses = {
  MissionStatus.quoted,
  MissionStatus.searchingDriver,
  MissionStatus.offered,
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
};

String formatFeeMinor(num minor, String locale) {
  final value = (minor / 100).toStringAsFixed(2);
  return locale == 'en' ? '\$$value' : '${value.replaceAll('.', ',')} \$';
}

class CancelMissionButton extends StatefulWidget {
  const CancelMissionButton({
    super.key,
    required this.missionId,
    required this.locale,
    required this.api,
  });
  final String missionId;
  final String locale;
  final BookingApi api;

  @override
  State<CancelMissionButton> createState() => _CancelMissionButtonState();
}

class _CancelMissionButtonState extends State<CancelMissionButton> {
  bool _busy = false;
  String? _error;

  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;

  Future<void> _cancel() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final preview = await widget.api.call('cancelDeliveryRequest', {
        'missionId': widget.missionId,
        'dryRun': true,
      });
      final fee = (preview['feeMinor'] as num?)?.toInt() ?? 0;
      if (!mounted) return;
      final amount = formatFeeMinor(fee, widget.locale);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            tr(
              'Annuler cette demande ?',
              'Cancel this request?',
              '¿Cancelar esta solicitud?',
            ),
          ),
          content: Text(
            fee > 0
                ? tr(
                    'Un chauffeur a accepté et le ramassage est dans moins de 2 heures (ou le chauffeur est en route). Des frais d’annulation de $amount seront débités de votre carte.',
                    'A driver accepted and pickup is less than 2 hours away (or the driver is on the way). A cancellation fee of $amount will be charged to your card.',
                    'Un conductor aceptó y la recogida es en menos de 2 horas (o el conductor está en camino). Se cobrará a tu tarjeta un cargo de cancelación de $amount.',
                  )
                : tr(
                    'L’annulation est gratuite. Le blocage sur votre carte, s’il y en a un, sera libéré.',
                    'Cancellation is free. Any hold on your card will be released.',
                    'La cancelación es gratuita. Cualquier retención en tu tarjeta se liberará.',
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                tr('Garder ma demande', 'Keep my request', 'Mantener mi solicitud'),
              ),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                fee > 0
                    ? tr(
                        'Annuler et payer $amount',
                        'Cancel and pay $amount',
                        'Cancelar y pagar $amount',
                      )
                    : tr(
                        'Annuler la demande',
                        'Cancel the request',
                        'Cancelar la solicitud',
                      ),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await widget.api.call('cancelDeliveryRequest', {
        'missionId': widget.missionId,
        if (fee > 0) 'acceptedFeeMinor': fee,
      });
    } on FirebaseFunctionsException catch (e) {
      final details = e.details;
      if (mounted) {
        setState(
          () => _error =
              details is Map && details['reason'] == 'fee_confirmation_required'
              ? tr(
                  'Les frais d’annulation ont changé. Réessayez pour voir le montant à jour.',
                  'The cancellation fee changed. Try again to see the updated amount.',
                  'El cargo de cancelación cambió. Inténtalo de nuevo para ver el importe actualizado.',
                )
              : tr(
                  'L’annulation n’a pas pu être enregistrée. Réessayez.',
                  'The cancellation could not be saved. Please retry.',
                  'No se pudo registrar la cancelación. Reintenta.',
                ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = tr(
            'L’annulation n’a pas pu être enregistrée. Réessayez.',
            'The cancellation could not be saved. Please retry.',
            'No se pudo registrar la cancelación. Reintenta.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ),
      OutlinedButton(
        key: const ValueKey('cancel-mission'),
        onPressed: _busy ? null : _cancel,
        child: Text(
          tr('Annuler ma demande', 'Cancel my request', 'Cancelar mi solicitud'),
        ),
      ),
    ],
  );
}

/// One line on a cancelled mission: the fee and whether it was charged.
String? cancellationFeeSummary(Map<String, dynamic>? fee, String locale) {
  final total = fee?['total_minor'];
  if (fee == null || total is! num || total <= 0) return null;
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  final label = fee['kind'] == 'customer_failed_delivery'
      ? tr('Frais de déplacement', 'Travel fee', 'Cargo por desplazamiento')
      : tr('Frais d’annulation', 'Cancellation fee', 'Cargo de cancelación');
  final state = switch (fee['status']) {
    'captured' => tr('débités', 'charged', 'cobrado'),
    'failed' || 'not_collectable' => tr(
      'non débités',
      'not charged',
      'no cobrado',
    ),
    _ => tr('en cours', 'processing', 'en curso'),
  };
  final colon = locale == 'fr' ? ' : ' : ': ';
  return '$label$colon${formatFeeMinor(total, locale)} ($state)';
}
