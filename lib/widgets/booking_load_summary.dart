import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';

/// Authenticated reads only. Used before driver acceptance and in tracking.
class BookingLoadSummary extends StatelessWidget {
  const BookingLoadSummary({
    super.key,
    required this.snapshot,
    required this.locale,
  });
  final Map<String, dynamic> snapshot;
  final String locale;
  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;
  @override
  Widget build(BuildContext context) {
    final load = Map<String, dynamic>.from(snapshot['load'] as Map? ?? {});
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
      children: [
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
                        .map((p) => BookingPhoto(path: p as String))
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
        if (load['requested_at'] != null)
          Text(
            '${tr('Date demandée (à confirmer)', 'Requested date (to be confirmed)', 'Fecha solicitada (por confirmar)')}: ${DateTime.tryParse(load['requested_at'] as String)?.toLocal()}',
          ),
      ],
    );
  }
}

class BookingPhoto extends StatefulWidget {
  const BookingPhoto({super.key, required this.path});
  final String path;
  @override
  State<BookingPhoto> createState() => _BookingPhotoState();
}

class _BookingPhotoState extends State<BookingPhoto> {
  late final Future<Uint8List?> _bytes = FirebaseStorage.instance
      .ref(widget.path)
      .getData(5 * 1024 * 1024);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
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
