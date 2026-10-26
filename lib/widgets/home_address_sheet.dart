import 'package:flutter/material.dart';

import '../services/account/saved_addresses.dart';
import 'address_autocomplete_field.dart';

/// "Votre adresse (Maison)": the customer picks it from the address
/// suggestions; it is saved for the home shortcuts (2026-10-26). Returns
/// the saved address, or null when closed.
Future<Map<String, dynamic>?> showHomeAddressSheet(
  BuildContext context, {
  required String uid,
  required String locale,
  Map<String, dynamic>? current,
}) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) =>
      _HomeAddressSheet(uid: uid, locale: locale, current: current),
);

class _HomeAddressSheet extends StatefulWidget {
  const _HomeAddressSheet({
    required this.uid,
    required this.locale,
    this.current,
  });
  final String uid, locale;
  final Map<String, dynamic>? current;
  @override
  State<_HomeAddressSheet> createState() => _HomeAddressSheetState();
}

class _HomeAddressSheetState extends State<_HomeAddressSheet> {
  late final _controller = TextEditingController(
    text: widget.current?['formatted_address'] as String? ?? '',
  );
  Map<String, dynamic>? _picked;
  bool _saving = false, _failed = false;

  String tr(String fr, String en, String es) => widget.locale == 'en'
      ? en
      : widget.locale == 'es'
      ? es
      : fr;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final address = _picked;
    if (address == null) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await SavedAddresses.instance.saveHome(widget.uid, address);
      if (mounted) Navigator.of(context).pop(address);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _failed = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      0,
      20,
      20 + MediaQuery.viewInsetsOf(context).bottom,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            tr('Votre adresse (Maison)', 'Your address (Home)', 'Tu dirección (Casa)'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            tr(
              'Elle remplit la réservation pour vous : livrer à la maison ou ramasser à la maison.',
              'It fills in your booking: deliver home or pick up at home.',
              'Rellena tu reserva: entregar en casa o recoger en casa.',
            ),
          ),
          const SizedBox(height: 12),
          AddressAutocompleteField(
            key: const ValueKey('home-address-field'),
            controller: _controller,
            label: tr('Adresse', 'Address', 'Dirección'),
            resolvedText: widget.current?['formatted_address'] as String?,
            onResolved: (a) => setState(
              () => _picked = {
                'line1': a.line1,
                'city': a.city,
                'postal_code': a.postalCode,
                'lat': a.lat,
                'lng': a.lng,
                'formatted_address': a.formattedAddress,
                'place_id': a.placeId,
              },
            ),
            onInvalidated: () => setState(() => _picked = null),
          ),
          if (_failed)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                tr(
                  'L’adresse n’a pas pu être enregistrée. Réessayez.',
                  'The address could not be saved. Try again.',
                  'No se pudo guardar la dirección. Inténtalo de nuevo.',
                ),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('home-address-save'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _picked == null || _saving ? null : _save,
            child: Text(tr('Enregistrer', 'Save', 'Guardar')),
          ),
        ],
      ),
    ),
  );
}
