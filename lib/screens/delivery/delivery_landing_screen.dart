import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class DeliveryLandingScreen extends StatelessWidget {
  final String locale;
  const DeliveryLandingScreen({super.key, required this.locale});

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
            decoration: const BoxDecoration(gradient: AppColors.deliveryGradient),
            child: ResponsivePadding(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 80 : 48),
                child: Column(
                  crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 44),
                    const SizedBox(height: 18),
                    Text(
                      t('delivery_hero_headline'),
                      textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: isDesktop ? 42 : 28, fontWeight: FontWeight.w800, height: 1.1),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: Text(
                        t('delivery_hero_sub'),
                        textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 16, height: 1.5),
                      ),
                    ),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: () => context.go('/$locale/livraison/demande'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryLight),
                      child: Text(t('home_card_delivery_cta')),
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
                  const SectionTitle(title: 'Ce que nous transportons', subtitle: "Un large éventail d'objets volumineux, gérés par des chauffeurs locaux équipés."),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: DemoDataService.deliveryCategories
                        .map((c) => Chip(avatar: const Icon(Icons.check_circle, size: 16, color: AppColors.success), label: Text(c)))
                        .toList(),
                  ),
                  const SizedBox(height: 48),
                  const SectionTitle(title: 'Comment ça fonctionne'),
                  const SizedBox(height: 24),
                  _StepsRow(isDesktop: isDesktop),
                  const SizedBox(height: 48),
                  Row(
                    children: [
                      const Icon(Icons.gps_fixed, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Suivi GPS en direct pendant la livraison', style: TextStyle(color: AppColors.textSecondary))),
                      const ComingSoonBadge(small: true),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      const Icon(Icons.flash_on_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 10),
                      const Expanded(child: Text('Tarification instantanée automatisée', style: TextStyle(color: AppColors.textSecondary))),
                      const ComingSoonBadge(small: true),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.go('/$locale/livraison/demande'),
                      child: Text(t('home_card_delivery_cta')),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/$locale/devenir-chauffeur'),
                      child: Text(t('home_card_delivery_cta2')),
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

class _StepsRow extends StatelessWidget {
  final bool isDesktop;
  const _StepsRow({required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    final steps = [
      ('1', 'Décrivez l\'objet', Icons.inventory_2_outlined),
      ('2', 'Ajoutez les emplacements', Icons.place_outlined),
      ('3', 'Comparez les chauffeurs', Icons.people_outline),
      ('4', 'Réservez un créneau', Icons.event_available_outlined),
      ('5', 'Confirmez et évaluez', Icons.star_border_rounded),
    ];
    final tiles = steps
        .map((s) => Container(
              width: isDesktop ? 200 : double.infinity,
              margin: const EdgeInsets.only(right: 16, bottom: 16),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(s.$3, color: AppColors.primary),
                  const SizedBox(height: 10),
                  Text(s.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                ],
              ),
            ))
        .toList();
    return Wrap(children: tiles);
  }
}
