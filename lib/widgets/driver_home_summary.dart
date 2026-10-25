// ---------------------------------------------------------------------------
// DriverHomeSummary — haut de l'onglet Accueil du chauffeur.
//
// En un coup d'œil : la prochaine mission (quand, trajet, rémunération), les
// gains de la semaine et le nombre de missions à venir. Les demandes
// disponibles restent juste en dessous (ProviderJobsTab).
//
// Lecture seule. Une source indisponible (réseau, droits, tests sans
// Firebase) masque simplement la partie concernée : l'accueil ne montre
// jamais d'erreur à la place des demandes.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../backend/backend_locator.dart';
import '../backend/models/delivery_mission.dart';
import '../backend/repositories/driver_agenda_repository.dart';
import '../core/app_colors.dart';
import '../finance/models/transaction_ledger.dart';
import '../finance/presentation/driver_display_format.dart';
import '../finance/presentation/driver_earnings_totals.dart';
import '../models/enums.dart';

String _tr(String locale, String fr, String en, String es) => locale == 'en'
    ? en
    : locale == 'es'
    ? es
    : fr;

const Set<MissionStatus> _upcomingStatuses = {
  MissionStatus.assigned,
  MissionStatus.driverToPickup,
  MissionStatus.arrivedAtPickup,
  MissionStatus.pickedUp,
  MissionStatus.inTransit,
  MissionStatus.arrivedAtDropoff,
};

/// Missions attribuées pas encore terminées, la plus proche d'abord (sans
/// horaire connu : en dernier).
List<DeliveryMission> upcomingDriverMissions(List<DeliveryMission> missions) {
  final list = missions.where((m) => _upcomingStatuses.contains(m.status)).toList()
    ..sort(
      (a, b) => (agendaMissionStart(a) ?? DateTime(2100)).compareTo(
        agendaMissionStart(b) ?? DateTime(2100),
      ),
    );
  return list;
}

class DriverHomeSummary extends StatefulWidget {
  const DriverHomeSummary({
    super.key,
    required this.driverId,
    required this.locale,
    this.missions,
    this.ledger,
  });

  final String driverId;
  final String locale;

  /// Injection pour les tests ; par défaut, les missions du chauffeur.
  final Stream<List<DeliveryMission>>? missions;

  /// Injection pour les tests ; par défaut, l'historique de gains.
  final Stream<List<LedgerEntry>>? ledger;

  @override
  State<DriverHomeSummary> createState() => _DriverHomeSummaryState();
}

class _DriverHomeSummaryState extends State<DriverHomeSummary> {
  String? _driverId;
  late Stream<List<DeliveryMission>> _missions;
  late Stream<List<LedgerEntry>> _ledger;

  String tr(String fr, String en, String es) => _tr(widget.locale, fr, en, es);

  void _ensureStreams() {
    if (_driverId == widget.driverId) return;
    _driverId = widget.driverId;
    _missions =
        widget.missions ??
        driverAgendaRepository(widget.driverId).watchMissions();
    _ledger =
        widget.ledger ??
        BackendLocator.financeRepository.watchDriverEarningsHistory(
          widget.driverId,
        );
  }

  @override
  Widget build(BuildContext context) {
    _ensureStreams();
    return StreamBuilder<List<DeliveryMission>>(
      stream: _missions,
      builder: (context, missionsSnap) {
        final upcoming = missionsSnap.hasData
            ? upcomingDriverMissions(missionsSnap.data!)
            : null;
        return StreamBuilder<List<LedgerEntry>>(
          stream: _ledger,
          builder: (context, ledgerSnap) {
            final totals = ledgerSnap.hasData
                ? DriverEarningsTotals.from(ledgerSnap.data!, DateTime.now())
                : null;
            if (upcoming == null && totals == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (upcoming != null) ...[
                    _NextMissionCard(
                      mission: upcoming.isEmpty ? null : upcoming.first,
                      locale: widget.locale,
                    ),
                    const SizedBox(height: 12),
                  ],
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      if (totals != null)
                        _Tile(
                          key: const ValueKey('home-week-earnings'),
                          label: tr(
                            'Gagné cette semaine',
                            'Earned this week',
                            'Ganado esta semana',
                          ),
                          value: driverMoney(totals.week, widget.locale),
                        ),
                      if (upcoming != null)
                        _Tile(
                          key: const ValueKey('home-upcoming-count'),
                          label: tr(
                            'Missions à venir',
                            'Upcoming jobs',
                            'Misiones próximas',
                          ),
                          value: '${upcoming.length}',
                        ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NextMissionCard extends StatelessWidget {
  const _NextMissionCard({required this.mission, required this.locale});

  final DeliveryMission? mission;
  final String locale;

  String tr(String fr, String en, String es) => _tr(locale, fr, en, es);

  @override
  Widget build(BuildContext context) {
    final m = mission;
    final decoration = BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    );
    if (m == null) {
      return Container(
        key: const ValueKey('home-next-mission-empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: decoration,
        child: Text(
          tr(
            'Aucune mission prévue. Les demandes de votre zone apparaissent ci-dessous.',
            'No job planned. Requests in your area appear below.',
            'Ninguna misión prevista. Las solicitudes de su zona aparecen abajo.',
          ),
          style: const TextStyle(color: AppColors.textSecondary),
        ),
      );
    }
    final start = agendaMissionStart(m);
    final from = m.pickupAddress?.city.trim() ?? '';
    final to = m.dropoffAddress?.city.trim() ?? '';
    final when = start == null
        ? tr('Horaire à préciser', 'Time to be confirmed', 'Horario por precisar')
        : '${driverDayLabel(start, locale)} · ${driverTime(start, locale)}';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home-next-mission'),
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.push('/$locale/provider/mission/${m.id}'),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: decoration,
          child: Row(
            children: [
              const Icon(Icons.local_shipping, color: AppColors.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('Prochaine mission', 'Next job', 'Próxima misión'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Text(
                      when,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (from.isNotEmpty || to.isNotEmpty)
                      Text(
                        from.isNotEmpty && to.isNotEmpty ? '$from → $to' : '$from$to',
                      ),
                    if (m.driverOfferAmount > 0)
                      Text(
                        driverMoney(m.driverOfferAmount, locale),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({super.key, required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 150),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}
