import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class DriverLandingScreen extends StatelessWidget {
  final String locale;
  const DriverLandingScreen({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final benefits = [
      (Icons.schedule, 'Horaire flexible', 'Connectez-vous quand ça vous convient.'),
      (Icons.attach_money, 'Revenu supplémentaire', 'Utilisez votre véhicule pour générer un revenu.'),
      (Icons.check_circle_outline, 'Choisissez vos demandes', "N'acceptez que les livraisons qui vous conviennent."),
      (Icons.map_outlined, 'Définissez votre zone', 'Fixez votre rayon de service maximal.'),
      (Icons.price_change_outlined, 'Fixez vos tarifs', 'Tarif horaire, au kilomètre ou forfait par catégorie.'),
      (Icons.support_agent, 'Moins de recherche de clients', 'Recevez des demandes pertinentes directement.'),
    ];

    final vehicles = ['Camionnette', 'Fourgon cargo', 'Camion cube', 'Remorque', 'VUS avec remorque', 'Véhicule commercial léger'];

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
                    Text(t('driver_hero_headline'), textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: TextStyle(color: Colors.white, fontSize: isDesktop ? 42 : 28, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Text(t('driver_hero_sub'), textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.88), fontSize: 16, height: 1.5))),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: () => context.go('/$locale/devenir-chauffeur/inscription'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primaryLight),
                      child: const Text("S'inscrire comme chauffeur"),
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
                  const SectionTitle(title: 'Véhicules admissibles'),
                  const SizedBox(height: 20),
                  Wrap(spacing: 10, runSpacing: 10, children: vehicles.map((v) => Chip(avatar: const Icon(Icons.directions_car_filled_outlined, size: 16), label: Text(v))).toList()),
                  const SizedBox(height: 48),
                  const SectionTitle(title: 'Avantages'),
                  const SizedBox(height: 24),
                  GridView.count(
                    crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 1.4,
                    children: benefits
                        .map((b) => Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Icon(b.$1, color: AppColors.primary),
                                const SizedBox(height: 10),
                                Text(b.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(b.$3, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
                              ]),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 48),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18)),
                    child: Row(children: [
                      const Icon(Icons.calculate_outlined, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Un calculateur de revenus estimatifs sera bientôt disponible. Les revenus réels varient selon la région, la tarification, la demande, la distance et la disponibilité.',
                          style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.go('/$locale/devenir-chauffeur/inscription'),
                      child: const Text("S'inscrire comme chauffeur"),
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
