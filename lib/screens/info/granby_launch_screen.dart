import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../l10n/home_copy.dart';
import '../../providers/locale_provider.dart';
import '../../router/delivery_request_intent.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class GranbyLaunchScreen extends StatelessWidget {
  final String locale;
  const GranbyLaunchScreen({super.key, required this.locale});

  String tr(String fr, String en, String es) => locale == 'en'
      ? en
      : locale == 'es'
      ? es
      : fr;

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 42),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Image.asset(
                    'assets/home/brand_logo.png',
                    height: 72,
                    fit: BoxFit.contain,
                    semanticLabel: 'Movi-K',
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEAF6FF),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      HomeCopy.text('granby_launch', locale),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    tr(
                      'Movi‑K se prépare à servir Granby.',
                      'Movi‑K is preparing to serve Granby.',
                      'Movi‑K se prepara para servir Granby.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.primaryDark,
                      fontSize: 34,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(
                      'Le lancement public est encore en préparation. Aucune réservation, disponibilité de chauffeur ou transaction réelle n’est promise par cette page.',
                      'Public launch is still being prepared. This page does not promise a booking, driver availability or a live transaction.',
                      'El lanzamiento público sigue en preparación. Esta página no promete una reserva, disponibilidad de conductor ni una transacción real.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 30),
                  _LaunchPoint(
                    icon: Icons.location_on_outlined,
                    title: tr('Zone prévue', 'Planned area', 'Zona prevista'),
                    body: tr(
                      'Granby et les environs. La prise en charge dépendra des chauffeurs actifs, de leur rayon d’action et du véhicule requis.',
                      'Granby and surrounding areas. Service will depend on active drivers, their service areas and the required vehicle.',
                      'Granby y alrededores. El servicio dependerá de los conductores activos, sus zonas de servicio y el vehículo necesario.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LaunchPoint(
                    icon: Icons.request_quote_outlined,
                    title: tr(
                      'Vous pouvez préparer une demande',
                      'You can prepare a request',
                      'Puedes preparar una solicitud',
                    ),
                    body: HomeCopy.text('quote_note', locale),
                  ),
                  const SizedBox(height: 12),
                  _LaunchPoint(
                    icon: Icons.support_agent_outlined,
                    title: tr(
                      'Canal de contact à venir',
                      'Contact channel coming soon',
                      'Canal de contacto próximamente',
                    ),
                    body: tr(
                      'Le canal officiel de contact n’est pas encore publié. La page Contact indique l’état actuel; aucun message n’y est simulé.',
                      'The official contact channel is not yet published. The Contact page shows the current status and does not simulate message delivery.',
                      'El canal oficial de contacto aún no está publicado. La página de Contacto muestra el estado actual y no simula el envío de mensajes.',
                    ),
                  ),
                  const SizedBox(height: 28),
                  ElevatedButton.icon(
                    onPressed: () =>
                        context.go(DeliveryRequestIntent.path(locale)),
                    icon: const Icon(Icons.edit_note_outlined),
                    label: Text(HomeCopy.text('quote_start', locale)),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => context.go('/$locale/faq'),
                    icon: const Icon(Icons.help_outline),
                    label: Text(
                      tr(
                        'Consulter la FAQ',
                        'Read the FAQ',
                        'Consultar preguntas frecuentes',
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: () => context.go('/$locale/contact'),
                    child: Text(
                      tr(
                        'Voir l’état du contact',
                        'View contact status',
                        'Ver el estado del contacto',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LaunchPoint extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _LaunchPoint({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.primary, size: 28),
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
