// ---------------------------------------------------------------------------
// DriverEarningsHeader — en-tête de l'onglet Revenus « style Uber »
// (phase 2, 2026-11-06) : le total de la semaine en gros, le nombre de
// livraisons payées, et un graphique lundi → dimanche.
//
// Affichage seulement : les chiffres viennent de DriverEarningsTotals
// (écritures confirmées du transaction_ledger). Aucun calcul de tarif.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';

import '../../../../core/app_colors.dart';
import '../../../../finance/presentation/driver_display_format.dart';
import '../../../../finance/presentation/driver_earnings_totals.dart';

class DriverEarningsHeader extends StatelessWidget {
  const DriverEarningsHeader({
    super.key,
    required this.totals,
    required this.t,
    required this.locale,
    DateTime Function()? now,
  }) : _now = now;

  final DriverEarningsTotals totals;
  final String Function(String) t;
  final String locale;
  final DateTime Function()? _now;

  @override
  Widget build(BuildContext context) {
    final today = (_now?.call() ?? DateTime.now()).toLocal();
    final deliveries = totals.weekDeliveries;
    final subtitle = deliveries == 0
        ? t('earnings_week_deliveries_none')
        : deliveries == 1
        ? t('earnings_week_deliveries_one')
        : t('earnings_week_deliveries_many').replaceAll('{n}', '$deliveries');
    final days = totals.weekByDay.length == 7
        ? totals.weekByDay
        : List<double>.filled(7, 0);
    final maxDay = days.fold<double>(0, (m, v) => v > m ? v : m);

    return Container(
      key: const ValueKey('driver-earnings-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t('earnings_title'),
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
              fontSize: 22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            driverMoney(totals.week, locale),
            key: const ValueKey('driver-earnings-week-total'),
            style: const TextStyle(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
              fontSize: 40,
              height: 1.05,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppColors.textOnDarkSecondary,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 18),
          // Graphique lundi → dimanche. Le jour courant est en vert.
          SizedBox(
            height: 96,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < 7; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _DayBar(
                      key: ValueKey('driver-earnings-day-$i'),
                      label: driverWeekdayShort(i + 1, locale),
                      amount: days[i],
                      max: maxDay,
                      isToday: today.weekday == i + 1,
                      isFuture: today.weekday < i + 1,
                      tooltip: driverMoney(days[i], locale),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    super.key,
    required this.label,
    required this.amount,
    required this.max,
    required this.isToday,
    required this.isFuture,
    required this.tooltip,
  });

  final String label;
  final double amount;
  final double max;
  final bool isToday;
  final bool isFuture;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    // Hauteur utile : 96 px moins l'étiquette et son espacement. Une barre
    // vide garde 4 px pour rester lisible ; une barre négative (frais) est
    // traitée comme vide.
    const usable = 70.0;
    final ratio = (max <= 0 || amount <= 0) ? 0.0 : (amount / max);
    final height = 4.0 + usable * ratio;
    final color = isToday
        ? AppColors.glowGreen
        : isFuture
        ? Colors.white.withValues(alpha: 0.18)
        : AppColors.glowBlue;
    return Tooltip(
      message: tooltip,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(6),
                bottom: Radius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.clip,
            style: TextStyle(
              fontSize: 11,
              color: isToday ? Colors.white : AppColors.textOnDarkSecondary,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
