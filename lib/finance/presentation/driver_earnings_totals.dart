// Totaux de gains du chauffeur (onglets Accueil et Revenus). Affichage
// seulement : somme des écritures déjà enregistrées dans transaction_ledger.

import '../models/transaction_ledger.dart';
import '../../models/enums.dart';
import 'driver_display_format.dart';

/// Totaux des gains confirmés (crédits moins débits) : semaine en cours
/// (depuis lundi), mois en cours et total. Agrégation d'affichage seulement.
class DriverEarningsTotals {
  const DriverEarningsTotals({
    required this.week,
    required this.month,
    required this.total,
    required this.pending,
    this.today = 0,
    this.weekByDay = const [0, 0, 0, 0, 0, 0, 0],
    this.weekDeliveries = 0,
  });

  /// Gains confirmés depuis minuit (heure locale) — accueil chauffeur.
  final double today;

  /// Gains confirmés de la semaine, par jour (lundi → dimanche) — graphique
  /// de l'onglet Revenus.
  final List<double> weekByDay;

  /// Livraisons distinctes payées cette semaine (gains chauffeur confirmés).
  final int weekDeliveries;
  final double week;
  final double month;
  final double total;
  final double pending;

  factory DriverEarningsTotals.from(List<LedgerEntry> entries, DateTime now) {
    final weekStart = driverWeekStart(now);
    final local = now.toLocal();
    final monthStart = DateTime(local.year, local.month);
    final dayStart = DateTime(local.year, local.month, local.day);
    double week = 0, month = 0, total = 0, pending = 0, today = 0;
    final byDay = List<double>.filled(7, 0);
    final weekMissions = <String>{};
    for (final e in entries) {
      final signed = e.direction == LedgerDirection.credit
          ? e.amount
          : -e.amount;
      if (e.status == LedgerEntryStatus.pending) {
        pending += signed;
        continue;
      }
      if (e.status != LedgerEntryStatus.confirmed) continue;
      total += signed;
      final at = e.createdAt.toLocal();
      if (!at.isBefore(weekStart)) {
        week += signed;
        byDay[at.weekday - 1] += signed;
        if (e.type == LedgerEntryType.driverEarning &&
            e.direction == LedgerDirection.credit &&
            e.missionId != null) {
          weekMissions.add(e.missionId!);
        }
      }
      if (!at.isBefore(monthStart)) month += signed;
      if (!at.isBefore(dayStart)) today += signed;
    }
    return DriverEarningsTotals(
      week: week,
      month: month,
      total: total,
      pending: pending,
      today: today,
      weekByDay: byDay,
      weekDeliveries: weekMissions.length,
    );
  }
}
