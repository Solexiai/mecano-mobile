import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class MechanicLandingScreen extends StatelessWidget {
  final String locale;
  const MechanicLandingScreen({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return AppShell(
      locale: locale,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(gradient: AppColors.mechanicGradient),
            child: ResponsivePadding(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 80 : 48),
                child: Column(
                  crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.build_rounded, color: Colors.white, size: 44),
                    const SizedBox(height: 18),
                    Text(
                      t('mechanic_hero_headline'),
                      textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: isDesktop ? 42 : 28, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        t('mechanic_hero_sub'),
                        textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 16, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: () => context.go('/$locale/mecanique-mobile/demande'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.success),
                      child: Text(t('home_card_mechanic_cta')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ResponsivePadding(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionTitle(title: 'Services disponibles', subtitle: 'Un mécanicien mobile qualifié se déplace chez vous.'),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: DemoDataService.mechanicServices
                        .map((c) => Chip(avatar: const Icon(Icons.check_circle, size: 16, color: AppColors.success), label: Text(t(c))))
                        .toList(),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t('mechanic_disclaimer'), style: const TextStyle(fontSize: 13, height: 1.5))),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      const Icon(Icons.medical_services_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Couverture assurance sur les interventions', style: TextStyle(color: AppColors.textSecondary))),
                      const ComingSoonBadge(small: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Commande automatique de pièces auprès des fournisseurs', style: TextStyle(color: AppColors.textSecondary))),
                      const ComingSoonBadge(small: true),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.go('/$locale/mecanique-mobile/demande'),
                      child: Text(t('home_card_mechanic_cta')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/$locale/devenir-mecanicien'),
                      child: Text(t('home_card_mechanic_cta2')),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
