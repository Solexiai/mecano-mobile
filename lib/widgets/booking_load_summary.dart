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
  @override
  Widget build(BuildContext context) {
    final load = Map<String, dynamic>.from(snapshot['load'] as Map? ?? {});
    final children = <Widget>[
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
                if (snapshot['vehicle_assessment'] == 'driver_photo_review' &&
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
                if (snapshot['vehicle_assessment'] == 'driver_photo_review' &&
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
                if (i['approximate'] == true)
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
              subtitle: Text(
                '${tr('Étage', 'Floor', 'Piso')}: ${a['floor']} · ${tr('Escaliers', 'Stairs', 'Escaleras')}: ${a['stairs'] == true ? tr('Oui', 'Yes', 'Sí') : tr('Non', 'No', 'No')} · ${tr('Ascenseur', 'Elevator', 'Ascensor')}: ${a['elevator'] == true ? tr('Oui', 'Yes', 'Sí') : tr('Non', 'No', 'No')} · ${tr('Aide', 'Help', 'Ayuda')}: ${a['help'] == true ? tr('Oui', 'Yes', 'Sí') : tr('Non', 'No', 'No')}',
              ),
            );
          },
        ),
      Text(
        '${tr('Manutentionnaires', 'Handlers', 'Personas para cargar')}: ${load['handlers']} · ${tr('Équipement', 'Equipment', 'Equipo')}: ${(load['equipment'] as List? ?? []).join(', ')}',
      ),
      if (load['timing_mode'] == 'immediate')
        Text(
          tr(
            'Dès maintenant — selon la disponibilité du chauffeur',
            'As soon as possible — subject to driver availability',
            'Lo antes posible — según la disponibilidad del conductor',
          ),
        )
      else if (load['requested_at'] != null)
        Text(
          '${tr('Date demandée (à confirmer)', 'Requested date (to be confirmed)', 'Fecha solicitada (por confirmar)')}: ${DateTime.tryParse(load['requested_at'] as String)?.toLocal()}',
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
