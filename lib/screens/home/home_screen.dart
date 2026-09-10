import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/section_title.dart';

String _tr(
  String locale, {
  required String fr,
  required String en,
  required String es,
}) {
  switch (locale) {
    case 'en':
      return en;
    case 'es':
      return es;
    default:
      return fr;
  }
}

class HomeScreen extends StatelessWidget {
  final String locale;
  const HomeScreen({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    return AppShell(
      locale: locale,
      child: Column(
        children: [
          _Hero(locale: locale),
          _DeliveryService(locale: locale),
          _HowItWorksPreview(locale: locale),
          _WhyMovik(locale: locale),
          _FinalCta(locale: locale),
        ],
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final String locale;
  const _Hero({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 90 : 56),
          child: isDesktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _HeroText(locale: locale)),
                    const SizedBox(width: 48),
                    Expanded(child: _DeliveryGlassPanel(t: t, locale: locale)),
                  ],
                )
              : Column(
                  children: [
                    _HeroText(locale: locale),
                    const SizedBox(height: 36),
                    _DeliveryGlassPanel(t: t, locale: locale),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final String locale;
  const _HeroText({required this.locale});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Column(
      crossAxisAlignment:
          isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: const Text(
            'Québec • Canada',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _tr(
            locale,
            fr: 'Livrez ce qui ne rentre pas dans votre véhicule.',
            en: 'Deliver what does not fit in your vehicle.',
            es: 'Entrega lo que no cabe en tu vehículo.',
          ),
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: isDesktop ? 52 : 34,
            fontWeight: FontWeight.w800,
            letterSpacing: -1.2,
            height: 1.08,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          _tr(
            locale,
            fr: 'Trouvez un chauffeur local de confiance avec le bon véhicule pour vos meubles, électroménagers, achats Marketplace et autres objets volumineux.',
            en: 'Find a trusted local driver with the right vehicle for furniture, appliances, Marketplace purchases and other large items.',
            es: 'Encuentra un conductor local de confianza con el vehículo adecuado para muebles, electrodomésticos, compras de Marketplace y otros artículos voluminosos.',
          ),
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: isDesktop ? 18 : 15,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/$locale/livraison'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primary,
              ),
              child: Text(
                _tr(
                  locale,
                  fr: 'Demander une livraison',
                  en: 'Request a delivery',
                  es: 'Solicitar una entrega',
                ),
              ),
            ),
            OutlinedButton(
              onPressed: () => context.go('/$locale/devenir-chauffeur'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white),
              ),
              child: Text(
                _tr(
                  locale,
                  fr: 'Devenir chauffeur',
                  en: 'Become a driver',
                  es: 'Convertirse en conductor',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryGlassPanel extends StatelessWidget {
  final String Function(String) t;
  final String locale;
  const _DeliveryGlassPanel({required this.t, required this.locale});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: AppColors.deliveryGradient,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t('home_card_delivery_title'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  _tr(
                    locale,
                    fr: '${DemoDataService.drivers.length}+ chauffeurs de démonstration',
                    en: '${DemoDataService.drivers.length}+ demo drivers',
                    es: '${DemoDataService.drivers.length}+ conductores de demostración',
                  ),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryService extends StatelessWidget {
  final String locale;
  const _DeliveryService({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return ResponsivePadding(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 44),
        child: Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: Theme.of(context).cardTheme.color,
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: AppColors.deliveryGradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    t('home_card_delivery_title'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    t('home_card_delivery_desc'),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(height: 1.5),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    t('home_examples'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _ExampleChip(
                        label: _tr(locale, fr: 'Meubles', en: 'Furniture', es: 'Muebles'),
                      ),
                      _ExampleChip(
                        label: _tr(locale, fr: 'Électroménagers', en: 'Appliances', es: 'Electrodomésticos'),
                      ),
                      const _ExampleChip(label: 'Marketplace'),
                      _ExampleChip(
                        label: _tr(locale, fr: 'Matériaux', en: 'Materials', es: 'Materiales'),
                      ),
                      _ExampleChip(
                        label: _tr(locale, fr: 'Grand téléviseur', en: 'Large TV', es: 'Televisor grande'),
                      ),
                      const _ExampleChip(label: 'BBQ'),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => context.go('/$locale/livraison'),
                      child: Text(t('home_card_delivery_cta')),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/$locale/devenir-chauffeur'),
                      child: Text(t('home_card_delivery_cta2')),
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

class _ExampleChip extends StatelessWidget {
  final String label;
  const _ExampleChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: const TextStyle(fontSize: 12)),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _HowItWorksPreview extends StatelessWidget {
  final String locale;
  const _HowItWorksPreview({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final steps = <(String, IconData, String)>[
      (
        '1',
        Icons.edit_note_rounded,
        _tr(locale, fr: 'Décrivez votre besoin', en: 'Describe your need', es: 'Describe tu necesidad'),
      ),
      (
        '2',
        Icons.place_outlined,
        _tr(locale, fr: 'Collecte et livraison', en: 'Pickup and delivery', es: 'Recogida y entrega'),
      ),
      (
        '3',
        Icons.people_outline,
        _tr(locale, fr: 'Trouvez un chauffeur', en: 'Find a driver', es: 'Encuentra un conductor'),
      ),
      (
        '4',
        Icons.check_circle_outline,
        _tr(locale, fr: 'Confirmez la livraison', en: 'Confirm the delivery', es: 'Confirma la entrega'),
      ),
    ];

    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(
                title: t('nav_how_it_works'),
                subtitle: _tr(
                  locale,
                  fr: 'Un processus simple et transparent, en quelques étapes.',
                  en: 'A simple and transparent process in just a few steps.',
                  es: 'Un proceso simple y transparente en pocos pasos.',
                ),
              ),
              const SizedBox(height: 32),
              isDesktop
                  ? Row(
                      children: steps
                          .map((s) => Expanded(child: _StepTile(step: s)))
                          .toList(),
                    )
                  : Column(
                      children: steps
                          .map(
                            (s) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _StepTile(step: s),
                            ),
                          )
                          .toList(),
                    ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/$locale/comment-ca-marche'),
                child: Text('${t('common_see_all')} →'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepTile extends StatelessWidget {
  final (String, IconData, String) step;
  const _StepTile({required this.step});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              step.$1,
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Icon(step.$2, color: AppColors.primary),
          const SizedBox(height: 10),
          Text(step.$3, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _WhyMovik extends StatelessWidget {
  final String locale;
  const _WhyMovik({required this.locale});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    final items = <(IconData, String, String)>[
      (
        Icons.verified_user_outlined,
        _tr(locale, fr: 'Chauffeurs vérifiés', en: 'Verified drivers', es: 'Conductores verificados'),
        _tr(locale, fr: 'Identité et documents examinés avant approbation.', en: 'Identity and documents reviewed before approval.', es: 'Identidad y documentos revisados antes de la aprobación.'),
      ),
      (
        Icons.price_change_outlined,
        _tr(locale, fr: 'Prix transparents', en: 'Transparent pricing', es: 'Precios transparentes'),
        _tr(locale, fr: 'Une répartition claire des coûts avant toute confirmation.', en: 'Clear pricing before you confirm.', es: 'Precios claros antes de confirmar.'),
      ),
      (
        Icons.chat_bubble_outline,
        _tr(locale, fr: 'Communication directe', en: 'Direct communication', es: 'Comunicación directa'),
        _tr(locale, fr: 'Échangez avec votre chauffeur pendant la livraison.', en: 'Communicate with your driver during the delivery.', es: 'Comunícate con tu conductor durante la entrega.'),
      ),
      (
        Icons.star_border_rounded,
        _tr(locale, fr: 'Avis vérifiés', en: 'Verified reviews', es: 'Reseñas verificadas'),
        _tr(locale, fr: 'Les clients peuvent laisser un avis après une livraison complétée.', en: 'Customers can leave a review after a completed delivery.', es: 'Los clientes pueden dejar una reseña después de una entrega completada.'),
      ),
    ];

    return ResponsivePadding(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionTitle(
              title: _tr(
                locale,
                fr: 'Pourquoi choisir Movi-k',
                en: 'Why choose Movi-k',
                es: 'Por qué elegir Movi-k',
              ),
              subtitle: _tr(
                locale,
                fr: 'Une plateforme locale conçue pour la confiance et la simplicité.',
                en: 'A local platform designed for trust and simplicity.',
                es: 'Una plataforma local diseñada para la confianza y la simplicidad.',
              ),
            ),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: isDesktop
                  ? 4
                  : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: isDesktop ? 0.85 : 1.6,
              children: items
                  .map(
                    (item) => Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardTheme.color,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(item.$1, color: AppColors.success, size: 28),
                          const SizedBox(height: 12),
                          Text(
                            item.$2,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.$3,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  final String locale;
  const _FinalCta({required this.locale});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 80 : 56),
          child: Column(
            children: [
              Text(
                _tr(
                  locale,
                  fr: 'Besoin de transporter quelque chose de gros?',
                  en: 'Need to move something large?',
                  es: '¿Necesitas transportar algo grande?',
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isDesktop ? 38 : 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(
                  _tr(
                    locale,
                    fr: 'Movi-k vous aide à trouver un chauffeur local avec le véhicule adapté à votre livraison.',
                    en: 'Movi-k helps you find a local driver with the right vehicle for your delivery.',
                    es: 'Movi-k te ayuda a encontrar un conductor local con el vehículo adecuado para tu entrega.',
                  ),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: isDesktop ? 17 : 15,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => context.go('/$locale/livraison'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.primary,
                    ),
                    child: Text(
                      _tr(locale, fr: 'Demander une livraison', en: 'Request a delivery', es: 'Solicitar una entrega'),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/$locale/devenir-chauffeur'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                    ),
                    child: Text(
                      _tr(locale, fr: 'Devenir chauffeur', en: 'Become a driver', es: 'Convertirse en conductor'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
