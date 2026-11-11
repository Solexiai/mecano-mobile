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
                      'Livraison de meubles et d’électroménagers à Granby.',
                      'Furniture and appliance delivery in Granby.',
                      'Entrega de muebles y electrodomésticos en Granby.',
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
                      'Un divan acheté sur Marketplace, un réfrigérateur, des boîtes ou des matériaux : un chauffeur de la région s’en occupe. Prenez une photo, voyez le prix exact et réservez en ligne.',
                      'A sofa bought on Marketplace, a refrigerator, boxes or materials: a local driver takes care of it. Snap a photo, see the exact price and book online.',
                      'Un sofá comprado en Marketplace, un refrigerador, cajas o materiales: un conductor de la zona se encarga. Toma una foto, ve el precio exacto y reserva en línea.',
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
                    title: tr('Zone desservie', 'Service area', 'Zona de servicio'),
                    body: tr(
                      'Granby et partout ailleurs, sans limite de distance : il suffit qu’un chauffeur près de votre adresse de ramassage accepte la livraison.',
                      'Granby and everywhere else, with no distance limit: a driver near your pickup address just needs to accept the delivery.',
                      'Granby y cualquier otro lugar, sin límite de distancia: basta con que un conductor cerca de tu dirección de recogida acepte la entrega.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LaunchPoint(
                    icon: Icons.request_quote_outlined,
                    title: tr(
                      'Commencez sans compte',
                      'Start without an account',
                      'Empieza sin cuenta',
                    ),
                    body: HomeCopy.text('quote_note', locale),
                  ),
                  const SizedBox(height: 12),
                  _LaunchPoint(
                    icon: Icons.support_agent_outlined,
                    title: tr(
                      'Une question ?',
                      'A question?',
                      '¿Una pregunta?',
                    ),
                    body: tr(
                      'Écrivez-nous à infos@movi-k.com ou depuis la page Contact.',
                      'Write to us at infos@movi-k.com or from the Contact page.',
                      'Escríbenos a infos@movi-k.com o desde la página de Contacto.',
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
                        'Nous contacter',
                        'Contact us',
                        'Contáctanos',
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
