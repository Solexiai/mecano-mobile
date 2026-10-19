import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/app_colors.dart';

class AdminActionCounts {
  const AdminActionCounts({
    this.pendingReview,
    this.documentsRequired,
    this.unassigned,
    this.disputes,
  });
  final int? pendingReview, documentsRequired, unassigned, disputes;

  factory AdminActionCounts.fromJson(Map<String, dynamic> data) {
    int? count(String key) {
      final value = data[key];
      return value is num &&
              value.isFinite &&
              value >= 0 &&
              value == value.roundToDouble()
          ? value.toInt()
          : null;
    }

    return AdminActionCounts(
      pendingReview: count('pendingReviewDrivers'),
      documentsRequired: count('documentsRequiredDrivers'),
      unassigned: count('unassignedMissions'),
      disputes: data['actionCountsVersion'] == 1 ? count('openDisputes') : null,
    );
  }
}

class AdminActionCenter extends StatelessWidget {
  const AdminActionCenter({
    super.key,
    required this.counts,
    required this.locale,
    this.loading = false,
  });
  final AdminActionCounts? counts;
  final String locale;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    String copy(String fr, String en, String es) => switch (locale) {
      'fr' => fr,
      'es' => es,
      _ => en,
    };
    final entries = [
      (
        id: 'drivers',
        label: copy(
          'Dossiers chauffeurs en attente',
          'Driver applications awaiting review',
          'Solicitudes de conductores pendientes',
        ),
        count: counts?.pendingReview,
        icon: Icons.fact_check_outlined,
        path: '/$locale/admin/chauffeurs?filter=pending',
      ),
      (
        id: 'documents',
        label: copy(
          'Documents à compléter',
          'Documents to complete',
          'Documentos por completar',
        ),
        count: counts?.documentsRequired,
        icon: Icons.folder_open_outlined,
        path: '/$locale/admin/chauffeurs?filter=documents_required',
      ),
      (
        id: 'missions',
        label: copy(
          'Missions sans chauffeur',
          'Unassigned jobs',
          'Servicios sin conductor',
        ),
        count: counts?.unassigned,
        icon: Icons.local_shipping_outlined,
        path: '/$locale/admin/missions?filter=unassigned',
      ),
      (
        id: 'disputes',
        label: copy('Litiges ouverts', 'Open disputes', 'Disputas abiertas'),
        count: counts?.disputes,
        icon: Icons.report_problem_outlined,
        path: '/$locale/admin/paiements?section=disputes&filter=open',
      ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          copy('À traiter', 'To do', 'Por atender'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 6),
        Text(
          copy(
            'Vos priorités de gestion, en un clic.',
            'Your management priorities, one click away.',
            'Sus prioridades de gestión, a un clic.',
          ),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        if (loading)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              copy(
                'Actualisation des compteurs…',
                'Updating counts…',
                'Actualizando contadores…',
              ),
            ),
          ),
        if (!loading && entries.any((e) => e.count == null))
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              copy(
                'Certains compteurs sont indisponibles. Vous pouvez ouvrir les dossiers.',
                'Some counts are unavailable. You can still open the records.',
                'Algunos contadores no están disponibles. Puede abrir los expedientes.',
              ),
            ),
          ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1100
                ? 4
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final entry in entries)
                  SizedBox(
                    width: width,
                    child: Card(
                      margin: EdgeInsets.zero,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: InkWell(
                        key: ValueKey('admin-action-${entry.id}'),
                        onTap: () => context.go(entry.path),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(entry.icon, color: AppColors.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.count?.toString() ?? '—',
                                      semanticsLabel: entry.count == null
                                          ? copy(
                                              'Compteur indisponible',
                                              'Count unavailable',
                                              'Contador no disponible',
                                            )
                                          : null,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w900,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      entry.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.textSecondary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
