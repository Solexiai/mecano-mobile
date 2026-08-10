import 'package:flutter/material.dart';
import '../../../../core/app_colors.dart';
import '../../../../widgets/coming_soon_badge.dart';

class ProviderCalendarTab extends StatefulWidget {
  const ProviderCalendarTab({super.key});

  @override
  State<ProviderCalendarTab> createState() => _ProviderCalendarTabState();
}

class _ProviderCalendarTabState extends State<ProviderCalendarTab> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Calendrier', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(onPressed: () => setState(() => _selected = DateTime(_selected.year, _selected.month - 1)), icon: const Icon(Icons.chevron_left)),
                    Text('${_monthName(_selected.month)} ${_selected.year}', style: const TextStyle(fontWeight: FontWeight.w700)),
                    IconButton(onPressed: () => setState(() => _selected = DateTime(_selected.year, _selected.month + 1)), icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const SizedBox(height: 12),
                _MiniCalendarGrid(month: _selected),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Text('Disponibilités & dates bloquées', style: TextStyle(fontWeight: FontWeight.w700))),
              const ComingSoonBadge(small: true),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'La synchronisation de calendrier et la gestion avancée des disponibilités seront ajoutées prochainement.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }

  String _monthName(int m) {
    const names = ['Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin', 'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre'];
    return names[m - 1];
  }
}

class _MiniCalendarGrid extends StatelessWidget {
  final DateTime month;
  const _MiniCalendarGrid({required this.month});

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final startOffset = firstDay.weekday % 7;
    final totalCells = startOffset + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      children: [
        Row(
          children: ['D', 'L', 'M', 'M', 'J', 'V', 'S']
              .map((d) => Expanded(child: Center(child: Text(d, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)))))
              .toList(),
        ),
        const SizedBox(height: 6),
        for (int r = 0; r < rows; r++)
          Row(
            children: List.generate(7, (c) {
              final cellIndex = r * 7 + c;
              final day = cellIndex - startOffset + 1;
              final valid = day >= 1 && day <= daysInMonth;
              final isToday = valid && day == DateTime.now().day && month.month == DateTime.now().month;
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.all(2),
                  height: 36,
                  decoration: BoxDecoration(
                    color: isToday ? AppColors.primary : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      valid ? '$day' : '',
                      style: TextStyle(fontSize: 12, color: isToday ? Colors.white : AppColors.textPrimary, fontWeight: isToday ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}
