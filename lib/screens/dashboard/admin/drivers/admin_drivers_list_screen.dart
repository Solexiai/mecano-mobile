// ---------------------------------------------------------------------------
// AdminDriversListScreen — Phase 2, portail analyste `/admin/chauffeurs`.
//
// Remplace ENTIÈREMENT les données démo de `_AdminValidationsTab` par un
// flux Firestore réel (`DriverRepository.watchDriversByStatus`). Aucune
// donnée locale/simulée : loading/empty/error/realtime states réels.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../core/app_colors.dart';
import '../../../../models/enums.dart';
import '../../../../providers/locale_provider.dart';
import 'admin_driver_detail_screen.dart';

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
  const AdminDriversListScreen({super.key});

  @override
  State<AdminDriversListScreen> createState() => _AdminDriversListScreenState();
}

class _AdminDriversListScreenState extends State<AdminDriversListScreen> {
  DriverStatus? _filter = DriverStatus.pendingReview;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final repo = BackendLocator.driverRepository;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('admin_drivers_title'),
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _kFilters.map((f) {
              final selected = f == _filter;
              return ChoiceChip(
                label: Text(t(_filterLabelKey(f))),
                selected: selected,
                onSelected: (_) => setState(() => _filter = f),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          StreamBuilder<List<DriverProfileV2>>(
            stream: repo.watchDriversByStatus(_filter),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Column(
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 12),
                        Text(t('admin_drivers_loading'),
                            style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return _ErrorState(
                  message: t('admin_drivers_error'),
                  onRetry: () => setState(() {}),
                );
              }

              final drivers = snapshot.data ?? const <DriverProfileV2>[];
              if (drivers.isEmpty) {
                return _EmptyState(message: t('admin_drivers_empty'));
              }

              // Tri en mémoire (le plus récent en premier) — évite tout
              // besoin d'index composite Firestore (orderBy + where).
              final sorted = [...drivers]
                ..sort((a, b) => b.lastUpdatedAt.compareTo(a.lastUpdatedAt));

              return _DriversTable(drivers: sorted, t: t);
            },
          ),
        ],
      ),
    );
  }
}

class _DriversTable extends StatelessWidget {
  final List<DriverProfileV2> drivers;
  final String Function(String) t;
  const _DriversTable({required this.drivers, required this.t});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: drivers.map((d) => _DriverRow(driver: d, t: t)).toList(),
    );
  }
}

class _DriverRow extends StatelessWidget {
  final DriverProfileV2 driver;
  final String Function(String) t;
  const _DriverRow({required this.driver, required this.t});

  @override
  Widget build(BuildContext context) {
    final locale = context.read<LocaleProvider>().locale;
    final nameParts = driver.fullName.trim().split(RegExp(r'\s+'));
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';
    final vehicleLabel = driver.acceptedVehicleCategories.isNotEmpty
        ? t(driver.acceptedVehicleCategories.first.key)
        : '—';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => AdminDriverDetailScreen(driverId: driver.uid),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$firstName $lastName'.trim(),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      _MetaChip(icon: Icons.local_shipping_outlined, label: vehicleLabel),
                      _MetaChip(
                        icon: Icons.event_outlined,
                        label: '${t('admin_drivers_col_updated_at')}: '
                            '${_formatDate(driver.lastUpdatedAt, locale)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _statusColor(driver.status).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                t(driver.status.key),
                style: TextStyle(
                    color: _statusColor(driver.status),
                    fontWeight: FontWeight.w700,
                    fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime d, String locale) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
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
        Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
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
            const Icon(Icons.inbox_outlined, size: 40, color: AppColors.textSecondary),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.textSecondary)),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 40, color: AppColors.error),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: AppColors.error)),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
