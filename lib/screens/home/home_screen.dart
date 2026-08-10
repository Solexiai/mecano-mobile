import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../services/demo_data_service.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart' show DemoDataBadge;

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
          _ServiceCards(locale: locale),
          _HowItWorksPreview(locale: locale),
          _WhyMovik(locale: locale),
          _Testimonials(locale: locale),
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
                    Expanded(child: _HeroText(t: t, locale: locale, isDesktop: isDesktop)),
                    const SizedBox(width: 48),
                    Expanded(child: _HeroGlassPanel(t: t)),
                  ],
                )
              : Column(
                  children: [
                    _HeroText(t: t, locale: locale, isDesktop: isDesktop),
                    const SizedBox(height: 36),
                    _HeroGlassPanel(t: t),
                  ],
                ),
        ),
      ),
    );
  }
}

class _HeroText extends StatelessWidget {
  final String Function(String) t;
  final String locale;
  final bool isDesktop;
  const _HeroText({required this.t, required this.locale, required this.isDesktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.24)),
          ),
          child: const Text('Québec • Canada', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
        ),
        const SizedBox(height: 20),
        Text(
          t('home_hero_headline'),
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
          t('home_hero_subheadline'),
          textAlign: isDesktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: isDesktop ? 18 : 15, height: 1.5),
        ),
        const SizedBox(height: 30),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: [
            ElevatedButton(
              onPressed: () => context.go('/$locale/livraison'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
              child: Text(t('home_cta_need_service')),
            ),
            OutlinedButton(
              onPressed: () => context.go('/$locale/devenir-chauffeur'),
              style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
              child: Text(t('home_cta_offer_service')),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroGlassPanel extends StatelessWidget {
  final String Function(String) t;
  const _HeroGlassPanel({required this.t});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: AppColors.deliveryGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.local_shipping_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('home_card_delivery_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('${DemoDataService.drivers.length}+ chauffeurs vérifiés', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.2)),
          const SizedBox(height: 18),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(gradient: AppColors.mechanicGradient, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.build_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t('home_card_mechanic_title'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                    Text('${DemoDataService.mechanics.length}+ mécaniciens vérifiés', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceCards extends StatelessWidget {
  final String locale;
  const _ServiceCards({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final deliveryCard = _BigServiceCard(
      gradient: AppColors.deliveryGradient,
      icon: Icons.local_shipping_rounded,
      title: t('home_card_delivery_title'),
      description: t('home_card_delivery_desc'),
      examples: const ['Meubles', 'Électroménagers', 'Marketplace', 'Matériaux', 'Grand TV', 'BBQ'],
      ctaLabel: t('home_card_delivery_cta'),
      cta2Label: t('home_card_delivery_cta2'),
      onCta: () => context.go('/$locale/livraison'),
      onCta2: () => context.go('/$locale/devenir-chauffeur'),
      exampleLabel: t('home_examples'),
    );

    final mechanicCard = _BigServiceCard(
      gradient: AppColors.mechanicGradient,
      icon: Icons.build_rounded,
      title: t('home_card_mechanic_title'),
      description: t('home_card_mechanic_desc'),
      examples: const ['Batterie', 'Freins', 'Huile', 'Diagnostic', 'Pneus', 'Réparations'],
      ctaLabel: t('home_card_mechanic_cta'),
      cta2Label: t('home_card_mechanic_cta2'),
      onCta: () => context.go('/$locale/mecanique-mobile'),
      onCta2: () => context.go('/$locale/devenir-mecanicien'),
      exampleLabel: t('home_examples'),
    );

    return ResponsivePadding(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 44),
        child: isDesktop
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: deliveryCard),
                  const SizedBox(width: 28),
                  Expanded(child: mechanicCard),
                ],
              )
            : Column(
                children: [
                  deliveryCard,
                  const SizedBox(height: 24),
                  mechanicCard,
                ],
              ),
      ),
    );
  }
}

class _BigServiceCard extends StatelessWidget {
  final Gradient gradient;
  final IconData icon;
  final String title;
  final String description;
  final List<String> examples;
  final String ctaLabel;
  final String cta2Label;
  final VoidCallback onCta;
  final VoidCallback onCta2;
  final String exampleLabel;

  const _BigServiceCard({
    required this.gradient,
    required this.icon,
    required this.title,
    required this.description,
    required this.examples,
    required this.ctaLabel,
    required this.cta2Label,
    required this.onCta,
    required this.onCta2,
    required this.exampleLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 30, offset: const Offset(0, 12)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 20),
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          Text(description, style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5)),
          const SizedBox(height: 18),
          Text(exampleLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: examples
                .map((e) => Chip(
                      label: Text(e, style: const TextStyle(fontSize: 12)),
                      padding: EdgeInsets.zero,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ))
                .toList(),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(onPressed: onCta, child: Text(ctaLabel, textAlign: TextAlign.center)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(onPressed: onCta2, child: Text(cta2Label, textAlign: TextAlign.center)),
              ),
            ],
          ),
        ],
      ),
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
    final steps = [
      ('1', Icons.edit_note_rounded, 'Décrivez votre besoin'),
      ('2', Icons.place_outlined, 'Emplacement et horaire'),
      ('3', Icons.people_outline, 'Comparez les fournisseurs'),
      ('4', Icons.check_circle_outline, 'Réservez et confirmez'),
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
              SectionTitle(title: t('nav_how_it_works'), subtitle: 'Un processus simple, transparent, en quelques étapes.'),
              const SizedBox(height: 32),
              isDesktop
                  ? Row(children: steps.map((s) => Expanded(child: _StepTile(s))).toList())
                  : Column(children: steps.map((s) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _StepTile(s))).toList()),
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
  const _StepTile(this.step);

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
          CircleAvatar(radius: 18, backgroundColor: AppColors.primary.withValues(alpha: 0.1), child: Text(step.$1, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800))),
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
    final items = [
      (Icons.verified_user_outlined, 'Fournisseurs vérifiés', 'Identité et documents examinés avant approbation.'),
      (Icons.price_change_outlined, 'Prix transparents', 'Une répartition claire des coûts avant toute confirmation.'),
      (Icons.chat_bubble_outline, 'Communication directe', 'Échangez avec votre fournisseur via la messagerie intégrée.'),
      (Icons.star_border_rounded, 'Avis vérifiés', 'Seuls les clients ayant complété une réservation peuvent noter.'),
    ];
    return ResponsivePadding(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 44),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionTitle(title: 'Pourquoi choisir Movi-k', subtitle: 'Une plateforme locale conçue pour la confiance et la simplicité.'),
            const SizedBox(height: 32),
            GridView.count(
              crossAxisCount: isDesktop ? 4 : (MediaQuery.of(context).size.width > 600 ? 2 : 1),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
              childAspectRatio: isDesktop ? 0.85 : 1.6,
              children: items
                  .map((i) => Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(i.$1, color: AppColors.success, size: 28),
                            const SizedBox(height: 12),
                            Text(i.$2, style: const TextStyle(fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Text(i.$3, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _Testimonials extends StatelessWidget {
  final String locale;
  const _Testimonials({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 72 : 44),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionTitle(title: 'Ce que nos utilisateurs disent'),
              const SizedBox(height: 6),
              const DemoDataBadge(),
              const SizedBox(height: 28),
              isDesktop
                  ? Row(children: DemoDataService.testimonials.map((r) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 16), child: _TestimonialCard(review: r, label: t('testimonial_placeholder_label'))))).toList())
                  : Column(children: DemoDataService.testimonials.map((r) => Padding(padding: const EdgeInsets.only(bottom: 16), child: _TestimonialCard(review: r, label: t('testimonial_placeholder_label')))).toList()),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestimonialCard extends StatelessWidget {
  final dynamic review;
  final String label;
  const _TestimonialCard({required this.review, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(5, (i) => Icon(i < review.overall.round() ? Icons.star_rounded : Icons.star_border_rounded, color: AppColors.warning, size: 18)),
          ),
          const SizedBox(height: 10),
          Text('"${review.comment}"', style: const TextStyle(fontStyle: FontStyle.italic, height: 1.5)),
          const SizedBox(height: 14),
          Text(review.authorName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
        ],
      ),
    );
  }
}

class _FinalCta extends StatelessWidget {
  final String locale;
  const _FinalCta({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 80 : 56),
          child: Column(
            children: [
              Text(t('home_final_headline'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: isDesktop ? 38 : 26, fontWeight: FontWeight.w800, letterSpacing: -0.8)),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: Text(t('home_final_sub'), textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: isDesktop ? 17 : 15, height: 1.5)),
              ),
              const SizedBox(height: 30),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () => context.go('/$locale/livraison'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: AppColors.primary),
                    child: Text(t('home_final_cta1')),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/$locale/devenir-chauffeur'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                    child: Text(t('home_final_cta2')),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(t('home_trust_statement'), style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}
