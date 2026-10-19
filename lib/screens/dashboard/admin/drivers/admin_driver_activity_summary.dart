import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../backend/backend_status.dart';

class AdminDriverActivitySummary extends StatefulWidget {
  const AdminDriverActivitySummary({
    super.key,
    required this.driverId,
    required this.locale,
    this.loader,
  });
  final String driverId, locale;
  final Future<Map<String, dynamic>> Function()? loader;
  @override
  State<AdminDriverActivitySummary> createState() =>
      _AdminDriverActivitySummaryState();
}

class _AdminDriverActivitySummaryState
    extends State<AdminDriverActivitySummary> {
  Future<Map<String, dynamic>>? _future;
  String copy(String fr, String en, String es) => switch (widget.locale) {
    'fr' => fr,
    'es' => es,
    _ => en,
  };
  Future<Map<String, dynamic>> _load() async {
    if (widget.loader != null) return widget.loader!();
    if (!(context.read<BackendStatus?>()?.isConfigured ?? false)) {
      throw StateError('Backend unavailable');
    }
    final result = await FirebaseFunctions.instance
        .httpsCallable('getAdminDriverActivity')
        .call({'driverId': widget.driverId});
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, dynamic>>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return TextButton.icon(
          onPressed: () => setState(() {
            _future = _load();
          }),
          icon: const Icon(Icons.refresh),
          label: Text(
            copy(
              'Statistiques indisponibles · Réessayer',
              'Statistics unavailable · Retry',
              'Estadísticas no disponibles · Reintentar',
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return Text(
          copy(
            'Chargement des statistiques…',
            'Loading statistics…',
            'Cargando estadísticas…',
          ),
        );
      }
      final data = snapshot.data!;
      final reviews = (data['reviews'] as List? ?? []).whereType<Map>();
      final rating = data['rating'] as num?;
      final count = data['ratingCount'];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy(
              'Réalisées : ${data['completed']} · Annulées : ${data['cancelled']} · En litige : ${data['disputed']}',
              'Completed: ${data['completed']} · Cancelled: ${data['cancelled']} · Disputed: ${data['disputed']}',
              'Completadas: ${data['completed']} · Canceladas: ${data['cancelled']} · En disputa: ${data['disputed']}',
            ),
          ),
          Text(
            copy(
              'Échecs confirmés : ${data['failed'] ?? '—'} · Sans attribution automatique de faute',
              'Confirmed failures: ${data['failed'] ?? '—'} · No automatic blame assigned',
              'Fallos confirmados: ${data['failed'] ?? '—'} · Sin atribución automática de culpa',
            ),
          ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              rating == null
                  ? copy('Aucun avis', 'No reviews', 'Sin opiniones')
                  : '★ ${rating.toStringAsFixed(1)} / 5 · $count ${copy('avis', 'reviews', 'opiniones')}',
            ),
            children: [
              for (final review in reviews)
                ListTile(
                  leading: const Icon(Icons.star),
                  title: Text('${review['stars']} / 5'),
                  subtitle: review['comment'] == ''
                      ? null
                      : Text(review['comment'] as String? ?? ''),
                ),
              TextButton.icon(
                onPressed: () => setState(() {
                  _future = _load();
                }),
                icon: const Icon(Icons.refresh),
                label: Text(
                  copy(
                    'Actualiser les avis',
                    'Refresh reviews',
                    'Actualizar opiniones',
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    },
  );
}
