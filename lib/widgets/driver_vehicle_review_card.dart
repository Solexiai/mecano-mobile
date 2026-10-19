import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../backend/backend_locator.dart';
import '../backend/models/driver_vehicle.dart';
import '../l10n/app_strings.dart';
import '../l10n/vehicle_review_copy.dart';
import '../models/enums.dart';

class DriverVehicleReviewCard extends StatelessWidget {
  final DriverVehicle vehicle;
  final String locale;
  final VoidCallback onReviewed;
  const DriverVehicleReviewCard({
    super.key,
    required this.vehicle,
    required this.locale,
    required this.onReviewed,
  });
  @override
  Widget build(BuildContext context) {
    String t(String key) => VehicleReviewCopy.text(locale, key);
    final until = vehicle.capacityValidUntil;
    final verified =
        vehicle.isVerified && vehicle.verifiedCapacity != null && until != null;
    final status = !verified
        ? t('pending')
        : until.isAfter(DateTime.now())
        ? '${t('valid')} ${MaterialLocalizations.of(context).formatMediumDate(until.toLocal())}'
        : t('expired');
    return Card(
      key: ValueKey('review-vehicle-${vehicle.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              vehicle.makeModel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(AppStrings.t(vehicle.category.key, locale)),
            Text(
              [
                vehicle.plate,
                vehicle.year.toString(),
                if (vehicle.color != null) vehicle.color!,
              ].join(' · '),
            ),
            Text(status, key: ValueKey('vehicle-status-${vehicle.id}')),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () async {
                final changed = await showDialog<bool>(
                  context: context,
                  builder: (_) => DriverVehicleReviewDialog(
                    vehicle: vehicle,
                    locale: locale,
                  ),
                );
                if (changed == true) onReviewed();
              },
              child: Text(t('review')),
            ),
          ],
        ),
      ),
    );
  }
}

class DriverVehicleReviewDialog extends StatefulWidget {
  final DriverVehicle vehicle;
  final String locale;
  const DriverVehicleReviewDialog({
    super.key,
    required this.vehicle,
    required this.locale,
  });
  @override
  State<DriverVehicleReviewDialog> createState() =>
      _DriverVehicleReviewDialogState();
}

class _DriverVehicleReviewDialogState extends State<DriverVehicleReviewDialog> {
  static const fields = [
    'length_cm',
    'width_cm',
    'height_cm',
    'opening_width_cm',
    'opening_height_cm',
    'payload_kg',
  ];
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> values;
  late final TextEditingController until;
  final note = TextEditingController();
  final equipment = <String>{}, services = <String>{};
  int handlers = 1;
  bool confirmed = false, busy = false;
  String? error;
  String t(String key) => VehicleReviewCopy.text(widget.locale, key);
  @override
  void initState() {
    super.initState();
    final c = widget.vehicle.verifiedCapacity ?? <String, dynamic>{};
    values = {
      for (final k in fields)
        k: TextEditingController(text: c[k]?.toString() ?? ''),
    };
    final date = widget.vehicle.capacityValidUntil?.toLocal();
    until = TextEditingController(
      text: date == null ? '' : date.toIso8601String().substring(0, 10),
    );
    equipment.addAll((c['equipment'] as List?)?.whereType<String>() ?? []);
    services.addAll((c['services'] as List?)?.whereType<String>() ?? []);
    handlers = c['handlers'] == 2 ? 2 : 1;
  }

  DateTime? expiry() {
    final raw = until.text.trim();
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != raw) {
      return null;
    }
    return DateTime(parsed.year, parsed.month, parsed.day, 23, 59, 59);
  }

  Future<void> submit(bool approve) async {
    if (busy) return;
    if (approve && (!confirmed || !form.currentState!.validate())) return;
    if (note.text.trim().isEmpty) {
      setState(() => error = t('required'));
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await BackendLocator.driverRepository.reviewDriverVehicle(
        vehicle: widget.vehicle,
        approve: approve,
        note: note.text.trim(),
        validUntil: approve ? expiry() : null,
        capacity: approve
            ? {
                for (final k in fields)
                  k: double.parse(values[k]!.text.trim().replaceAll(',', '.')),
                'handlers': handlers,
                'equipment': equipment.toList(),
                'services': services.toList(),
              }
            : null,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(
          () => error = t(
            e is FirebaseFunctionsException && e.code == 'permission-denied'
                ? 'access'
                : 'error',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in values.values) {
      c.dispose();
    }
    until.dispose();
    note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    insetPadding: const EdgeInsets.all(12),
    title: Text(t('title')),
    content: SizedBox(
      width: 560,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('${widget.vehicle.makeModel} · ${widget.vehicle.plate}'),
              Text(t('help')),
              if (widget.vehicle.category == VehicleCategory.pickupTruck)
                Text(t('open_bed')),
              for (final k in fields)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t(k)),
                      TextFormField(
                        key: ValueKey('capacity-$k'),
                        controller: values[k],
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          errorMaxLines: 4,
                          semanticCounterText: t(k),
                        ),
                        validator: (value) {
                          final n = double.tryParse(
                            (value ?? '').trim().replaceAll(',', '.'),
                          );
                          return n != null && n.isFinite && n > 0
                              ? null
                              : t('positive');
                        },
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 12),
              Text(t('handlers')),
              Wrap(
                spacing: 8,
                children: [
                  for (final count in [1, 2])
                    ChoiceChip(
                      label: Text(count.toString()),
                      selected: handlers == count,
                      onSelected: busy
                          ? null
                          : (_) => setState(() => handlers = count),
                    ),
                ],
              ),
              for (final k in ['handling', 'stairs'])
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t(k)),
                  value: services.contains(k),
                  onChanged: busy
                      ? null
                      : (yes) => setState(() {
                          yes == true ? services.add(k) : services.remove(k);
                        }),
                ),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in ['dolly', 'straps', 'liftgate'])
                    FilterChip(
                      label: Text(t(k)),
                      selected: equipment.contains(k),
                      onSelected: busy
                          ? null
                          : (yes) => setState(() {
                              yes ? equipment.add(k) : equipment.remove(k);
                            }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(t('until')),
              TextFormField(
                key: const ValueKey('capacity-valid-until'),
                controller: until,
                enabled: !busy,
                decoration: const InputDecoration(
                  hintText: 'YYYY-MM-DD',
                  errorMaxLines: 4,
                ),
                validator: (_) => expiry()?.isAfter(DateTime.now()) == true
                    ? null
                    : t('date_error'),
              ),
              const SizedBox(height: 12),
              Text(t('note')),
              TextFormField(
                key: const ValueKey('capacity-note'),
                controller: note,
                enabled: !busy,
                maxLength: 1200,
                maxLines: 3,
                decoration: const InputDecoration(errorMaxLines: 4),
                validator: (v) =>
                    v?.trim().isNotEmpty == true ? null : t('required'),
              ),
              CheckboxListTile(
                key: const ValueKey('capacity-confirmation'),
                contentPadding: EdgeInsets.zero,
                title: Text(t('confirmed')),
                value: confirmed,
                onChanged: busy
                    ? null
                    : (v) => setState(() => confirmed = v == true),
              ),
              if (error != null)
                Text(
                  error!,
                  key: const ValueKey('capacity-error'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (busy) const LinearProgressIndicator(),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.of(context).pop(false),
        child: Text(t('cancel')),
      ),
      if (widget.vehicle.isVerified)
        TextButton(
          onPressed: busy ? null : () => submit(false),
          child: Text(t('revoke')),
        ),
      FilledButton(
        key: const ValueKey('capacity-approve'),
        onPressed: busy || !confirmed ? null : () => submit(true),
        child: Text(t('approve')),
      ),
    ],
  );
}
