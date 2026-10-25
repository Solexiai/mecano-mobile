import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/delivery_mission.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../customer_mission_view.dart';
import 'customer_overview_tab.dart';

/// "Activité": upcoming and past deliveries (owner mockup 2026-10-25).
/// Real Firebase data via `watchCustomerMissions()` (server statuses, live).
/// The mobile-mechanic service is not shown in the Movi-K customer space.
class CustomerRequestsTab extends StatefulWidget {
  const CustomerRequestsTab({super.key});

  @override
  State<CustomerRequestsTab> createState() => _CustomerRequestsTabState();
}

class _CustomerRequestsTabState extends State<CustomerRequestsTab> {
  bool? _upcoming; // null: decided from the data (upcoming when any)
  int _retry = 0;

  String tr(String locale, String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final localeProvider = context.watch<LocaleProvider>();
    final t = localeProvider.t;
    final locale = localeProvider.locale;

    if (!auth.isSignedIn || auth.effectiveUid == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(t('delivery_login_required'), textAlign: TextAlign.center),
        ),
      );
    }

    return StreamBuilder<List<DeliveryMission>>(
      key: ValueKey(_retry),
      stream: BackendLocator.missionRepository.watchCustomerMissions(auth.effectiveUid!),
      builder: (context, snapshot) {
        final missions = (snapshot.data ?? const <DeliveryMission>[])
            .where((m) => !m.isInternalTest)
            .toList();
        final upcoming = missions.where(isCustomerActive).toList();
        final past = missions.where(isCustomerPast).toList();
        final showUpcoming = _upcoming ?? upcoming.isNotEmpty;
        final list = showUpcoming ? upcoming : past;
        Widget tab(bool value, String label) {
          final on = value == showUpcoming;
          return Expanded(
            child: Semantics(
              selected: on,
              button: true,
              child: TextButton(
                key: ValueKey('activity-tab-${value ? 'upcoming' : 'past'}'),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(44),
                  backgroundColor: on ? Colors.white : Colors.transparent,
                  foregroundColor: on ? AppColors.primary : AppColors.textSecondary,
                  textStyle: TextStyle(fontSize: 16, fontWeight: on ? FontWeight.w800 : FontWeight.w600),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => setState(() => _upcoming = value),
                child: Text(label),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      tr(locale, 'Activité', 'Activity', 'Actividad'),
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F4F8),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        tab(
                          true,
                          upcoming.isEmpty
                              ? tr(locale, 'À venir', 'Upcoming', 'Próximas')
                              : '${tr(locale, 'À venir', 'Upcoming', 'Próximas')} (${upcoming.length})',
                        ),
                        const SizedBox(width: 4),
                        tab(false, tr(locale, 'Passées', 'Past', 'Pasadas')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (snapshot.connectionState == ConnectionState.waiting)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(t('requests_loading'), style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    )
                  else if (snapshot.hasError)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error, size: 32),
                          const SizedBox(height: 8),
                          Text(t('requests_error'), textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => setState(() => _retry++),
                            child: Text(t('requests_retry')),
                          ),
                        ],
                      ),
                    )
                  else if (list.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        showUpcoming
                            ? tr(
                                locale,
                                'Aucune livraison en cours.',
                                'No delivery in progress.',
                                'Ninguna entrega en curso.',
                              )
                            : t('requests_empty'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    )
                  else
                    for (final m in list) CustomerDeliveryRow(mission: m, locale: locale, t: t),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
