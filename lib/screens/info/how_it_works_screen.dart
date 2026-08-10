import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class HowItWorksScreen extends StatelessWidget {
  final String locale;
  const HowItWorksScreen({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final deliverySteps = [
      ('1', "Décrivez l'objet", Icons.inventory_2_outlined),
      ('2', "Ajoutez les emplacements de collecte et livraison", Icons.place_outlined),
      ('3', 'Comparez les chauffeurs disponibles', Icons.people_outline),
      ('4', 'Réservez un créneau', Icons.event_available_outlined),
      ('5', 'Confirmez la livraison et laissez un avis', Icons.star_border_rounded),
    ];
    final mechanicSteps = [
      ('1', 'Décrivez le problème de votre véhicule', Icons.build_outlined),
      ('2', 'Choisissez votre emplacement et horaire', Icons.place_outlined),
      ('3', 'Comparez les mécaniciens disponibles', Icons.people_outline),
      ('4', 'Approuvez la demande de service', Icons.check_circle_outline),
      ('5', 'Recevez un rapport et laissez un avis', Icons.star_border_rounded),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('nav_how_it_works')),
              const SizedBox(height: 32),
              Text(t('nav_delivery'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.primary)),
              const SizedBox(height: 16),
              _StepsList(steps: deliverySteps, color: AppColors.primary),
              const SizedBox(height: 20),
              Row(children: [
                const Icon(Icons.gps_fixed, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Suivi GPS en temps réel', style: TextStyle(color: AppColors.textSecondary))),
                const ComingSoonBadge(small: true),
              ]),
              const SizedBox(height: 48),
              Text(t('nav_mechanic'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.success)),
              const SizedBox(height: 16),
              _StepsList(steps: mechanicSteps, color: AppColors.success),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsList extends StatelessWidget {
  final List<(String, String, IconData)> steps;
  final Color color;
  const _StepsList({required this.steps, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps
          .map((s) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  CircleAvatar(radius: 20, backgroundColor: color.withValues(alpha: 0.12), child: Text(s.$1, style: TextStyle(color: color, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 16),
                  Icon(s.$3, color: color),
                  const SizedBox(width: 12),
                  Expanded(child: Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w600))),
                ]),
              ))
          .toList(),
    );
  }
}
