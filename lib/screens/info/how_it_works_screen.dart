import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../l10n/home_copy.dart';
import '../../providers/locale_provider.dart';
import '../../router/delivery_request_intent.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class HowItWorksScreen extends StatelessWidget {
  final String locale;
  const HowItWorksScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    String h(String key) => HomeCopy.text(key, locale);

    final steps = [
      (Icons.inventory_2_outlined, h('step1'), h('step1_body')),
      (Icons.receipt_long_outlined, h('step2'), h('step2_body')),
      (Icons.local_shipping_outlined, h('step3'), h('step3_body')),
      (Icons.route_outlined, h('step4'), h('step4_body')),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: tr('Comment ça marche', 'How it works', 'Cómo funciona'),
                subtitle: tr(
                  'Un parcours simple, sans choix manuel de chauffeur ni créneau promis.',
                  'A simple flow without manual driver selection or a promised time slot.',
                  'Un proceso sencillo, sin elegir manualmente conductor ni prometer una franja horaria.',
                ),
              ),
              const SizedBox(height: 28),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final columns = constraints.maxWidth >= 900 && scale <= 1.35
                      ? 4
                      : constraints.maxWidth >= 600 && scale <= 1.35
                      ? 2
                      : 1;
                  final gap = 16.0;
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
                          child: _HowStepCard(
                            number: i + 1,
                            icon: steps[i].$1,
                            title: steps[i].$2,
                            body: steps[i].$3,
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 28),
              _InfoCard(
                icon: Icons.login_outlined,
                title: tr(
                  'Connexion au moment de calculer le prix officiel',
                  'Sign in when requesting the official price',
                  'Inicio de sesión al solicitar el precio oficial',
                ),
                body: h('quote_note'),
              ),
              const SizedBox(height: 14),
              _InfoCard(
                icon: Icons.schedule_outlined,
                title: tr(
                  'Pas de créneau promis dans ce parcours',
                  'No promised time slot in this flow',
                  'Sin franja horaria prometida en este proceso',
                ),
                body: tr(
                  'Indiquez la date et l’heure souhaitées dans votre demande. Elles restent à confirmer selon l’acceptation et la disponibilité du chauffeur. Après confirmation de la demande, Movi‑K recherche un chauffeur admissible.',
                  'Enter your preferred date and time in the request. They remain subject to driver acceptance and availability. After request confirmation, Movi‑K looks for an eligible driver.',
                  'Indica la fecha y hora deseadas en tu solicitud. Siguen sujetas a la aceptación y disponibilidad del conductor. Tras confirmar la solicitud, Movi‑K busca un conductor apto.',
                ),
              ),
              const SizedBox(height: 14),
              _InfoCard(
                icon: Icons.gps_fixed,
                title: tr(
                  'Suivi des étapes et GPS',
                  'Status tracking and GPS',
                  'Seguimiento de etapas y GPS',
                ),
                body: tr(
                  'Chaque étape de votre livraison est visible dans votre espace client, avec la position de votre chauffeur sur une carte en direct pendant la livraison.',
                  'Every step of your delivery is visible in your customer account, with your driver’s position on a live map during the delivery.',
                  'Cada etapa de tu entrega es visible en tu cuenta de cliente, con la ubicación de tu conductor en un mapa en vivo durante la entrega.',
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => context.go(DeliveryRequestIntent.path(locale)),
                icon: const Icon(Icons.request_quote_outlined),
                label: Text(h('quote_start')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HowStepCard extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String body;
  const _HowStepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 220),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Text(
                '$number',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: AppColors.primary, size: 30),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(color: AppColors.textSecondary, height: 1.5),
        ),
      ],
    ),
  );
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
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
              const SizedBox(height: 5),
              Text(
                body,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
