import 'booking_access_section.dart';
import 'booking_help_text.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

typedef BookingPhotoLoader = Future<Uint8List?> Function(String path);

/// Authenticated reads only. Used before driver acceptance and in tracking.
class BookingLoadSummary extends StatelessWidget {
  const BookingLoadSummary({
    super.key,
    required this.snapshot,
    required this.locale,
    this.photoLoader,
    this.collapsible = true,
  });
  final Map<String, dynamic> snapshot;
  final String locale;
  final bool collapsible;
  final BookingPhotoLoader? photoLoader;
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  /// "23/10/2026 · 14:00" — same day/month/year convention as the tracking
  /// map. The app does not configure the Material localization delegates,
  /// so MaterialLocalizations would print English month names (2026-10-23).
  static String _dateLabel(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year} · ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final load = Map<String, dynamic>.from(snapshot['load'] as Map? ?? {});
    final photoAssessment = const {
      'driver_photo_review',
      'driver_judgement',
    }.contains(snapshot['vehicle_assessment']);
    final children = <Widget>[
      if (snapshot['vehicle_assessment'] == 'driver_judgement')
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr(
              'À vous de juger : vérifiez sur les photos et la description que le chargement entre dans votre véhicule. Les dimensions et le poids peuvent être inconnus.',
              'Your call: check the photos and description to make sure the load fits your vehicle. Dimensions and weight may be unknown.',
              'Tú decides: revisa las fotos y la descripción para confirmar que la carga cabe en tu vehículo. Las dimensiones y el peso pueden ser desconocidos.',
            ),
          ),
        ),
      if (snapshot['vehicle_assessment'] == 'driver_photo_review')
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            tr(
              'À évaluer sur photo : les dimensions et le poids peuvent être inconnus. La capacité de chargement n’est pas confirmée.',
              'Review the photo: dimensions and weight may be unknown. Loading capacity is not confirmed.',
              'Evalúa la foto: las dimensiones y el peso pueden ser desconocidos. La capacidad de carga no está confirmada.',
            ),
          ),
        ),
      for (final raw in (load['items'] as List? ?? []))
        Builder(
          builder: (context) {
            final i = Map<String, dynamic>.from(raw as Map);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i['quantity']} × ${i['label']} · ${i['length_cm'] ?? '?'} × ${i['width_cm'] ?? '?'} × ${i['height_cm'] ?? '?'} cm · ${i['weight_kg'] ?? '?'} kg',
                ),
                // The AI's broad size range for one piece (2026-10-25): an
                // estimate to check on the photo, never a measurement.
                if (_estimateText(i['size_estimate'], tr) case final estimate?)
                  Text(estimate, key: const ValueKey('load-size-estimate'))
                else if (photoAssessment &&
                    [
                      i['length_cm'],
                      i['width_cm'],
                      i['height_cm'],
                    ].contains(null))
                  Text(
                    tr(
                      'Dimensions non précisées',
                      'Dimensions not provided',
                      'Dimensiones no indicadas',
                    ),
                  ),
                if (photoAssessment &&
                    i['weight_kg'] == null)
                  Text(
                    tr(
                      'Poids non précisé',
                      'Weight not provided',
                      'Peso no indicado',
                    ),
                  ),
                if (i['handling_notes'] is String &&
                    (i['handling_notes'] as String).trim().isNotEmpty)
                  Text(
                    '${tr('Précautions', 'Precautions', 'Precauciones')} : ${i['handling_notes']}',
                  ),
                if (i['special_handling'] == true)
                  Text(
                    tr(
                      'Objet particulier signalé : regardez bien la photo',
                      'Special item flagged: check the photo carefully',
                      'Objeto especial señalado: revisa bien la foto',
                    ),
                    key: const ValueKey('load-special-flag'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (i['approximate'] == true &&
                    [
                      i['length_cm'],
                      i['width_cm'],
                      i['height_cm'],
                    ].any((v) => v != null))
                  Text(
                    tr(
                      'Mesures approximatives fournies par le client',
                      'Approximate measurements provided by the customer',
                      'Medidas aproximadas indicadas por el cliente',
                    ),
                  ),
                if (i['upright'] == true)
                  Text(
                    tr(
                      'Transport debout uniquement',
                      'Upright transport only',
                      'Transporte vertical únicamente',
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  children: (i['photos'] as List? ?? [])
                      .map(
                        (p) => BookingPhoto(
                          path: p as String,
                          loader: photoLoader,
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      for (final key in ['pickup', 'dropoff'])
        Builder(
          builder: (context) {
            final a = Map<String, dynamic>.from(load[key] as Map? ?? {});
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                key == 'pickup'
                    ? tr('Ramassage', 'Pickup', 'Recogida')
                    : tr('Livraison', 'Delivery', 'Entrega'),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(accessSummary(a, locale)),
                  Text(
                    a['help'] == true
                        ? tr(
                            'Avec aide Movi-K',
                            'With Movi-K help',
                            'Con ayuda Movi-K',
                          )
                        : a['help'] == false
                        ? tr(
                            'Sans aide Movi-K',
                            'Without Movi-K help',
                            'Sin ayuda Movi-K',
                          )
                        : tr(
                            'Aide Movi-K à préciser',
                            'Movi-K help to specify',
                            'Ayuda Movi-K por precisar',
                          ),
                  ),
                  if (a['help'] == true)
                    Text(
                      tr(
                            'Aide pour soulever sur place : ',
                            'On-site lifting help: ',
                            'Ayuda para levantar en el lugar: ',
                          ) +
                          (a['onsite_help'] == 'yes'
                              ? tr('Oui', 'Yes', 'Sí')
                              : a['onsite_help'] == 'no'
                              ? tr('Non', 'No', 'No')
                              : tr(
                                  'À confirmer',
                                  'To confirm',
                                  'Por confirmar',
                                )),
                    ),
                  if (a['inside'] is bool)
                    Text(
                      tr(
                            'Déplacement à l’intérieur : ',
                            'Indoor movement: ',
                            'Traslado en el interior: ',
                          ) +
                          (a['inside'] == true
                              ? tr('Oui', 'Yes', 'Sí')
                              : tr('Non', 'No', 'No')),
                    ),
                  if (a['help'] == false &&
                      a['inside'] == true &&
                      a['customer_handles_inside'] == true)
                    Text(
                      tr(
                        'Déplacement organisé par le client.',
                        'Movement arranged by the customer.',
                        'Traslado organizado por el cliente.',
                      ),
                    ),
                  if (a['notes'] is String &&
                      (a['notes'] as String).trim().isNotEmpty)
                    Text(a['notes'] as String),
                ],
              ),
            );
          },
        ),
      if (load['handlers'] != null || load['equipment'] != null)
        Text(helpAndEquipmentLine(load, locale)),
      if (load['timing_mode'] == 'immediate')
        Text(
          tr(
            'Dès maintenant — selon la disponibilité du chauffeur',
            'As soon as possible — subject to driver availability',
            'Lo antes posible — según la disponibilidad del conductor',
          ),
        )
      else if (load['requested_at'] is String &&
          DateTime.tryParse(load['requested_at'] as String) != null)
        Text(
          '${tr('Date demandée (à confirmer)', 'Requested date (to be confirmed)', 'Fecha solicitada (por confirmar)')} : ${_dateLabel(DateTime.parse(load['requested_at'] as String).toLocal())}',
        ),
    ];
    if (!collapsible) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr(
                  'Services et options compris',
                  'Included services and options',
                  'Servicios y opciones incluidos',
                ),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              ...children,
            ],
          ),
        ),
      );
    }
    return ExpansionTile(
      title: Text(
        tr(
          'Objets, accès et services',
          'Items, access and services',
          'Objetos, accesos y servicios',
        ),
      ),
      initiallyExpanded: true,
      childrenPadding: const EdgeInsets.all(12),
      children: children,
    );
  }
}

class BookingPhoto extends StatefulWidget {
  const BookingPhoto({super.key, required this.path, this.loader});
  final String path;
  final BookingPhotoLoader? loader;
  @override
  State<BookingPhoto> createState() => _BookingPhotoState();
}

class _BookingPhotoState extends State<BookingPhoto> {
  Future<Uint8List?> _load() => widget.loader != null
      ? widget.loader!(widget.path)
      : FirebaseStorage.instance.ref(widget.path).getData(5 * 1024 * 1024);
  late Future<Uint8List?> _bytes = _load();
  @override
  void didUpdateWidget(covariant BookingPhoto oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.path != widget.path || oldWidget.loader != widget.loader) {
      _bytes = _load();
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    key: ValueKey((widget.path, widget.loader)),
    future: _bytes,
    builder: (context, snapshot) => SizedBox(
      width: 120,
      height: 100,
      child: snapshot.hasData
          ? Image.memory(
              snapshot.data!,
              fit: BoxFit.contain,
              semanticLabel: 'Photo',
            )
          : Center(
              child: Icon(
                snapshot.hasError
                    ? Icons.broken_image_outlined
                    : Icons.image_outlined,
              ),
            ),
    ),
  );
}

/// "Taille estimée (IA, à vérifier sur la photo) : 60–70 × 60–70 × 85–95 cm".
String? _estimateText(
  dynamic raw,
  String Function(String fr, String en, String es) tr,
) {
  if (raw is! Map) return null;
  String? range(String key) {
    final r = raw[key];
    if (r is! Map || r['min'] is! num || r['max'] is! num) return null;
    return '${r['min']}–${r['max']}';
  }
  final l = range('length_cm'), w = range('width_cm'), h = range('height_cm');
  if (l == null || w == null || h == null) return null;
  return '${tr('Taille estimée (IA, à vérifier sur la photo)', 'Estimated size (AI, check the photo)', 'Tamaño estimado (IA, verificar en la foto)')} : $l × $w × $h cm';
}
