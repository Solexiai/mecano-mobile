import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class MechanicProviderLandingScreen extends StatelessWidget {
  final String locale;
  const MechanicProviderLandingScreen({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final benefits = [
      (Icons.trending_up, 'Demandes de meilleure qualité', 'Recevez des demandes locales pertinentes.'),
      (Icons.phone_disabled_outlined, "Moins d'appels à gérer", "Fini les appels incessants pour trouver des clients."),
      (Icons.schedule, 'Choisissez votre horaire', 'Connectez-vous selon votre disponibilité.'),
      (Icons.rule_folder_outlined, 'Publiez vos forfaits', 'Créez des services à prix fixe pour vos interventions courantes.'),
      (Icons.inventory_2_outlined, 'Support pièces', "Bénéficiez d'une aide à la coordination des pièces."),
      (Icons.verified_user_outlined, 'Réputation vérifiée', 'Bâtissez un profil professionnel basé sur des avis vérifiés.'),
    ];

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
                    Text(t('mech_provider_hero_headline'), textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: TextStyle(color: Colors.white, fontSize: isDesktop ? 42 : 26, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 14),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text(t('mech_provider_hero_sub'), textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 16, height: 1.5))),
                    const SizedBox(height: 12),
                    ConstrainedBox(constraints: const BoxConstraints(maxWidth: 620), child: Text(t('mech_provider_fr_support'), textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5, fontStyle: FontStyle.italic))),
                    const SizedBox(height: 26),
                    ElevatedButton(
                      onPressed: () => context.go('/$locale/devenir-mecanicien/inscription'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.success),
                      child: const Text("S'inscrire comme mécanicien mobile"),
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
                  const SectionTitle(title: 'Avantages pour les mécaniciens'),
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
                                Icon(b.$1, color: AppColors.success),
                                const SizedBox(height: 10),
                                Text(b.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(b.$3, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
                              ]),
                            ))
                        .toList(),
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: ElevatedButton(
                      onPressed: () => context.go('/$locale/devenir-mecanicien/inscription'),
                      child: const Text("S'inscrire comme mécanicien mobile"),
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
