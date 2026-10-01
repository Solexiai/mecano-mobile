import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../l10n/home_copy.dart';
import '../../providers/locale_provider.dart';
import '../../router/delivery_request_intent.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class DeliveryLandingScreen extends StatelessWidget {
  final String locale;
  const DeliveryLandingScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    String h(String key) => HomeCopy.text(key, locale);

    return AppShell(
      locale: locale,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: AppColors.deliveryGradient,
            ),
            child: ResponsivePadding(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 46),
                child: Column(
                  crossAxisAlignment: isDesktop
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 44,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      h('title'),
                      textAlign: isDesktop ? TextAlign.left : TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isDesktop ? 40 : 28,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 680),
                      child: Text(
                        h('intro'),
                        textAlign: isDesktop
                            ? TextAlign.left
                            : TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .90),
                          fontSize: 16,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      h('granby_launch'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () =>
                          context.go(DeliveryRequestIntent.path(locale)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryLight,
                      ),
                      child: Text(h('quote_start')),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ResponsivePadding(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: isDesktop ? 56 : 38),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionTitle(
                    title: tr(
                      'Ce que vous pouvez faire livrer',
                      'What you can have delivered',
                      'Lo que puedes transportar',
                    ),
                    subtitle: tr(
                      'Les catégories ci-dessous proviennent du catalogue actuellement accepté dans le formulaire.',
                      'The categories below come from the catalogue currently accepted by the request form.',
                      'Las categorías siguientes provienen del catálogo aceptado actualmente en el formulario.',
                    ),
                  ),
                  const SizedBox(height: 22),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: DemoDataService.deliveryCategories
                        .map(
                          (category) => Chip(
                            avatar: const Icon(
                              Icons.check_circle,
                              size: 16,
                              color: AppColors.success,
                            ),
                            label: Text(t(category)),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 42),
                  SectionTitle(title: h('steps_title')),
                  const SizedBox(height: 20),
                  _DeliverySteps(locale: locale),
                  const SizedBox(height: 36),
                  _StatusNotice(
                    icon: Icons.route_outlined,
                    title: h('reassurance_tracking'),
                    body: tr(
                      'Le suivi des étapes de la mission est disponible dans l’espace client.',
                      'Mission status tracking is available in the customer account.',
                      'El seguimiento de las etapas de la misión está disponible en la cuenta del cliente.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusNotice(
                    icon: Icons.gps_fixed,
                    title: tr('GPS en direct', 'Live GPS', 'GPS en directo'),
                    body: tr(
                      'La carte GPS est conçue pour les phases actives de la livraison, mais sa validation sur appareils réels reste un prérequis du lancement public.',
                      'The live map is designed for active delivery phases, but real-device validation remains a prerequisite for public launch.',
                      'El mapa GPS está diseñado para las fases activas, pero la validación en dispositivos reales sigue siendo un requisito del lanzamiento público.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _StatusNotice(
                    icon: Icons.calculate_outlined,
                    title: tr(
                      'Devis calculé par Movi‑K',
                      'Quote calculated by Movi‑K',
                      'Presupuesto calculado por Movi‑K',
                    ),
                    body: tr(
                      'Le devis officiel est calculé côté serveur et sa ventilation est affichée avant confirmation.',
                      'The official quote is calculated on the server and its breakdown is shown before confirmation.',
                      'El presupuesto oficial se calcula en el servidor y su desglose se muestra antes de confirmar.',
                    ),
                  ),
                  const SizedBox(height: 32),
                  Center(
                    child: ElevatedButton(
                      onPressed: () =>
                          context.go(DeliveryRequestIntent.path(locale)),
                      child: Text(h('quote_start')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => context.go('/$locale/devenir-chauffeur'),
                      child: Text(h('driver_link')),
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

class _DeliverySteps extends StatelessWidget {
  final String locale;
  const _DeliverySteps({required this.locale});

  @override
  Widget build(BuildContext context) {
    String h(String key) => HomeCopy.text(key, locale);
    final steps = [
      (Icons.inventory_2_outlined, h('step1'), h('step1_body')),
      (Icons.receipt_long_outlined, h('step2'), h('step2_body')),
      (Icons.local_shipping_outlined, h('step3'), h('step3_body')),
      (Icons.route_outlined, h('step4'), h('step4_body')),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final columns = constraints.maxWidth >= 900 && scale <= 1.35
            ? 4
            : constraints.maxWidth >= 600 && scale <= 1.35
            ? 2
            : 1;
        final gap = 14.0;
        final width = columns == 1
            ? constraints.maxWidth
            : (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < steps.length; i++)
              SizedBox(
                width: width,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 190),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardTheme.color,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        child: Text('${i + 1}'),
                      ),
                      const SizedBox(height: 12),
                      Icon(steps[i].$1, color: AppColors.primary),
                      const SizedBox(height: 10),
                      Text(
                        steps[i].$2,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[i].$3,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          height: 1.4,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _StatusNotice({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF5FAFF),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFFDCEBFA)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
