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
  });

  final double week;
  final double month;
  final double total;
  final double pending;

  factory DriverEarningsTotals.from(List<LedgerEntry> entries, DateTime now) {
    final weekStart = driverWeekStart(now);
    final local = now.toLocal();
    final monthStart = DateTime(local.year, local.month);
    double week = 0, month = 0, total = 0, pending = 0;
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
      if (!at.isBefore(weekStart)) week += signed;
      if (!at.isBefore(monthStart)) month += signed;
    }
    return DriverEarningsTotals(
      week: week,
      month: month,
      total: total,
      pending: pending,
    );
  }
}
