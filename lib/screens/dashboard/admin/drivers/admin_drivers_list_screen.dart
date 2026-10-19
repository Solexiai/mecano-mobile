// ---------------------------------------------------------------------------
// AdminDriversListScreen — Phase 2, portail analyste `/admin/chauffeurs`.
//
// Remplace ENTIÈREMENT les données démo de `_AdminValidationsTab` par un
// flux Firestore réel (`DriverRepository.watchDriversByStatus`). Aucune
// donnée locale/simulée : loading/empty/error/realtime states réels.
// ---------------------------------------------------------------------------

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../backend/repositories/firestore_query_window.dart';
import '../../../../backend/repositories/firestore_driver_window.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import 'admin_driver_detail_screen.dart';
import '../../../../services/driver_presence.dart';
import 'admin_driver_activity_summary.dart';

DriverStatus? adminDriverInitialFilter(String value) => switch (value) {
  'all' || 'connected' || 'offline' => null,
  'documents_required' => DriverStatus.documentsRequired,
  _ => DriverStatus.pendingReview,
};

/// null = filtre "Tous".
const List<DriverStatus?> _kFilters = [
  null,
  DriverStatus.pendingReview,
  DriverStatus.documentsRequired,
  DriverStatus.approved,
  DriverStatus.rejected,
  DriverStatus.suspended,
];

String _filterLabelKey(DriverStatus? s) {
  if (s == null) return 'admin_drivers_filter_all';
  switch (s) {
    case DriverStatus.pendingReview:
      return 'admin_drivers_filter_pending_review';
    case DriverStatus.documentsRequired:
      return 'admin_drivers_filter_documents_required';
    case DriverStatus.approved:
      return 'admin_drivers_filter_approved';
    case DriverStatus.rejected:
      return 'admin_drivers_filter_rejected';
    case DriverStatus.suspended:
      return 'admin_drivers_filter_suspended';
    default:
      return 'admin_drivers_filter_all';
  }
}

Color _statusColor(DriverStatus s) {
  switch (s) {
    case DriverStatus.approved:
      return AppColors.success;
    case DriverStatus.rejected:
      return AppColors.error;
    case DriverStatus.suspended:
      return AppColors.error;
    case DriverStatus.documentsRequired:
      return AppColors.warning;
    case DriverStatus.pendingReview:
      return AppColors.info;
    default:
      return AppColors.textSecondary;
  }
}

class AdminDriversListScreen extends StatefulWidget {
  const AdminDriversListScreen({super.key, this.initialFilter = 'pending'});
  final String initialFilter;

  @override
  State<AdminDriversListScreen> createState() => _AdminDriversListScreenState();
}

class _AdminDriversListScreenState extends State<AdminDriversListScreen> {
  late DriverStatus? _filter;
  String _city = '';
  late String _presence;
  String _copy(String fr, String en, String es) =>
      switch (context.read<LocaleProvider>().locale) {
        'fr' => fr,
        'es' => es,
        _ => en,
      };
  int _window = kFirestoreLiveWindowStep;
  late Stream<List<DriverProfileV2>> _stream;

  @override
  void initState() {
    super.initState();
    _presence = ['connected', 'offline'].contains(widget.initialFilter)
        ? widget.initialFilter
        : 'all';
    _filter = adminDriverInitialFilter(widget.initialFilter);
    _refreshStream();
  }

  @override
  void didUpdateWidget(covariant AdminDriversListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFilter != widget.initialFilter) {
      _presence = ['connected', 'offline'].contains(widget.initialFilter)
          ? widget.initialFilter
          : 'all';
      _filter = adminDriverInitialFilter(widget.initialFilter);
      _window = kFirestoreLiveWindowStep;
      _refreshStream();
    }
  }

  void _refreshStream() {
    _stream = BackendLocator.driverRepository.watchDriversByStatus(
      _filter,
      limit: _window,
    );
  }

  void _changeFilter(DriverStatus? filter) => setState(() {
    _filter = filter;
    _window = kFirestoreLiveWindowStep;
    _refreshStream();
  });

  void _loadMore() => setState(() {
    _window += kFirestoreLiveWindowStep;
    _refreshStream();
  });

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return DriverPresenceView(
      builder: (context, connected) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t('admin_drivers_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _kFilters.map((f) {
                final selected = f == _filter;
                return ChoiceChip(
                  label: Text(t(_filterLabelKey(f))),
                  selected: selected,
                  onSelected: (_) => _changeFilter(f),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('driver-city-search'),
              decoration: InputDecoration(
                labelText: _copy(
                  'Rechercher par ville',
                  'Search by city',
                  'Buscar por ciudad',
                ),
                prefixIcon: const Icon(Icons.location_city),
              ),
              onChanged: (value) => setState(() => _city = value),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in [
                  (
                    'all',
                    _copy(
                      'Toutes les connexions',
                      'All connections',
                      'Todas las conexiones',
                    ),
                  ),
                  ('connected', _copy('Connectés', 'Connected', 'Conectados')),
                  ('offline', _copy('Hors ligne', 'Offline', 'Desconectados')),
                ])
                  ChoiceChip(
                    label: Text(entry.$2),
                    selected: _presence == entry.$1,
                    onSelected: (_) => setState(() => _presence = entry.$1),
                  ),
              ],
            ),
            Text(
              connected == null
                  ? _copy(
                      'Présence indisponible : aucun statut de connexion confirmé.',
                      'Presence unavailable: no confirmed connection status.',
                      'Presencia no disponible: estado sin confirmar.',
                    )
                  : _copy(
                      'Connecté = application au premier plan, signal reçu depuis moins de 90 s. Ce statut ne signifie pas disponible pour une mission.',
                      'Connected = app in foreground, signal received within 90 s. This does not mean available for a job.',
                      'Conectado = aplicación en primer plano, señal de menos de 90 s. No significa disponible para un servicio.',
                    ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<DriverProfileV2>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 48),
                    child: Center(
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(
                            t('admin_drivers_loading'),
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return _ErrorState(
                    message: t('admin_drivers_error'),
                    onRetry: () => setState(_refreshStream),
                  );
                }

                final drivers = snapshot.data ?? const <DriverProfileV2>[];
                // Migration aliases are filtered after the Firestore limit.
                // Detect a full RAW window so they cannot hide later profiles.
                final hasNext = drivers is FirestoreDriverWindow
                    ? drivers.fetchedCount >= _window
                    : drivers.length >= _window;
                if (drivers.isEmpty && !hasNext) {
                  return _EmptyState(message: t('admin_drivers_empty'));
                }

                // Tri en mémoire (le plus récent en premier) — évite tout
                // besoin d'index composite Firestore (orderBy + where).
                final sorted =
                    drivers
                        .where(
                          (d) => matchesDriverDirectory(
                            d,
                            _city,
                            _presence,
                            connected,
                          ),
                        )
                        .toList()
                      ..sort(
                        (a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt),
                      );

                return Column(
                  children: [
                    Text(
                      _copy(
                        'Recherche parmi ${drivers.length} dossiers chargés. Utilisez « Charger plus » pour élargir les résultats.',
                        'Searching ${drivers.length} loaded records. Use Load more to expand results.',
                        'Búsqueda en ${drivers.length} expedientes cargados. Cargue más para ampliar los resultados.',
                      ),
                    ),
                    if (sorted.isEmpty)
                      _EmptyState(message: t('admin_drivers_empty'))
                    else
                      _DriversTable(
                        drivers: sorted,
                        t: t,
                        connected: connected,
                      ),
                    if (hasNext)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: OutlinedButton.icon(
                          key: const Key('admin-drivers-load-more'),
                          onPressed: _loadMore,
                          icon: const Icon(Icons.expand_more),
                          label: Text(t('common_load_more')),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

bool matchesDriverDirectory(
  DriverProfileV2 driver,
  String city,
  String presence,
  Set<String>? connected,
) {
  String normalize(String s) {
    var v = s.toLowerCase().trim();
    const accents = {
      'à': 'a',
      'â': 'a',
      'ä': 'a',
      'é': 'e',
      'è': 'e',
      'ê': 'e',
      'ë': 'e',
      'î': 'i',
      'ï': 'i',
      'ô': 'o',
      'ö': 'o',
      'ù': 'u',
      'û': 'u',
      'ü': 'u',
      'ç': 'c',
    };
    accents.forEach((a, b) => v = v.replaceAll(a, b));
    return v;
  }

  if (!normalize(driver.city).contains(normalize(city))) return false;
  if (presence == 'all') return true;
  if (connected == null) return false;
  return presence == 'connected'
      ? connected.contains(driver.uid)
      : !connected.contains(driver.uid);
}

class _DriversTable extends StatelessWidget {
  final List<DriverProfileV2> drivers;
  final String Function(String) t;
  final Set<String>? connected;
  const _DriversTable({
    required this.drivers,
    required this.t,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: drivers
          .map(
            (d) => _DriverRow(
              key: ValueKey(d.uid),
              driver: d,
              t: t,
              connected: connected?.contains(d.uid),
            ),
          )
          .toList(),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final DriverProfileV2 driver;
  final String Function(String) t;
  final bool? connected;
  const _DriverRow({
    super.key,
    required this.driver,
    required this.t,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale;
    final canDelete = context.watch<FirebaseAuthProvider>().isAdminOrAbove;
    String copy(String fr, String en, String es) => switch (locale) {
      'fr' => fr,
      'es' => es,
      _ => en,
    };
    final name = driver.fullName.trim();
    final vehicle = driver.acceptedVehicleCategories.isEmpty
        ? '—'
        : t(driver.acceptedVehicleCategories.first.key);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => AdminDriverDetailScreen(driverId: driver.uid),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (canDelete)
                  PopupMenuButton<String>(
                    tooltip: 'Actions',
                    onSelected: (value) {
                      if (value == 'delete') {
                        _confirmDeleteDriver(context, driver);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Supprimer le dossier chauffeur'),
                      ),
                    ],
                  )
                else
                  const Icon(
                    Icons.chevron_right,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(driver.status).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  t(driver.status.key),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.statusBadgeTextColor(
                      _statusColor(driver.status),
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
              ),
              Text(driver.city.isEmpty ? '—' : driver.city),
              Text(
                connected == null
                    ? copy(
                        'Présence inconnue',
                        'Presence unknown',
                        'Presencia desconocida',
                      )
                    : connected!
                    ? copy('Connecté', 'Connected', 'Conectado')
                    : copy('Hors ligne', 'Offline', 'Desconectado'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AdminDriverActivitySummary(
            key: ValueKey('activity-${driver.uid}'),
            driverId: driver.uid,
            locale: locale,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              _MetaChip(icon: Icons.local_shipping_outlined, label: vehicle),
              _MetaChip(
                icon: Icons.event_outlined,
                label:
                    "${t('admin_drivers_col_updated_at')}: ${_formatDate(driver.lastUpdatedAt, locale)}",
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _confirmDeleteDriver(
  BuildContext context,
  DriverProfileV2 driver,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Supprimer le dossier chauffeur?'),
      content: Text(
        'Le dossier chauffeur de ${driver.fullName} ainsi que ses documents '
        'seront supprimés. Son compte client et son historique de livraisons '
        'seront conservés.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await FirebaseFunctions.instance.httpsCallable('deleteDriverProfile').call({
      'driverId': driver.uid,
    });
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Dossier chauffeur supprimé. Le compte client est conservé.',
        ),
      ),
    );
  } on FirebaseFunctionsException catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.message ?? 'Suppression impossible.')),
    );
  }
}

String _formatDate(DateTime d, String locale) {
  // Bloc K2 (K2-2) : conversion explicite en heure locale AVANT extraction
  // jour/mois/année — sans ceci, un DateTime réellement UTC (ex: valeur
  // provenant d'un Timestamp Firestore non converti) afficherait le jour
  // UTC au lieu du jour perçu par l'utilisateur, ce qui peut différer de 1
  // jour autour de minuit selon le fuseau. Voir aussi
  // `k2_utc_local_boundary_test.dart`.
  final local = d.toLocal();
  final dd = local.day.toString().padLeft(2, '0');
  final mm = local.month.toString().padLeft(2, '0');
  return '$dd/$mm/${local.year}';
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.inbox_outlined,
              size: 40,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: Text(t('common_retry'))),
          ],
        ),
      ),
    );
  }
}
