import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class PricingScreen extends StatelessWidget {
  final String locale;
  const PricingScreen({super.key, required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final deliveryOptions = ['Tarif horaire', 'Tarif au kilomètre', 'Frais minimum de réservation', 'Prix fixe par catégorie', "Frais d'aide au chargement", 'Frais d\'aide supplémentaire', 'Frais escaliers', 'Frais de temps d\'attente', 'Frais arrêt additionnel'];
    final mechanicOptions = ['Tarif horaire de main-d\'œuvre', 'Frais de déplacement', 'Frais minimum de service', "Frais d'urgence", 'Frais de soirée', 'Frais de fin de semaine', 'Forfaits à prix fixe', 'Frais de diagnostic', 'Majoration sur pièces (si applicable)'];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('pricing_title'), subtitle: 'Une tarification transparente établie par chaque fournisseur.'),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(color: AppColors.info.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(18)),
                child: Row(children: [
                  const Icon(Icons.info_outline, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(child: Text(t('pricing_mvp_notice'), style: const TextStyle(fontSize: 13.5))),
                ]),
              ),
              const SizedBox(height: 32),
              isDesktop
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: _PricingCard(title: t('nav_delivery'), gradient: AppColors.deliveryGradient, options: deliveryOptions)),
                      const SizedBox(width: 24),
                      Expanded(child: _PricingCard(title: t('nav_mechanic'), gradient: AppColors.mechanicGradient, options: mechanicOptions)),
                    ])
                  : Column(children: [
                      _PricingCard(title: t('nav_delivery'), gradient: AppColors.deliveryGradient, options: deliveryOptions),
                      const SizedBox(height: 20),
                      _PricingCard(title: t('nav_mechanic'), gradient: AppColors.mechanicGradient, options: mechanicOptions),
                    ]),
              const SizedBox(height: 40),
              const SectionTitle(title: 'Modes de paiement'),
              const SizedBox(height: 16),
              Wrap(spacing: 12, runSpacing: 12, children: [
                Chip(avatar: const Icon(Icons.payments_outlined, size: 16), label: Text(t('payment_cash'))),
                Chip(avatar: const Icon(Icons.sync_alt, size: 16), label: Text(t('payment_interac'))),
                Chip(avatar: const Icon(Icons.handshake_outlined, size: 16), label: Text(t('payment_arrangement'))),
              ]),
              const SizedBox(height: 32),
              Row(children: [
                const Icon(Icons.credit_card, color: AppColors.textSecondary),
                const SizedBox(width: 10),
                const Expanded(child: Text('Paiement sécurisé en ligne intégré (Stripe Connect)', style: TextStyle(color: AppColors.textSecondary))),
                const ComingSoonBadge(small: true),
              ]),
              const SizedBox(height: 32),
              const SectionTitle(title: 'Monétisation future'),
              const SizedBox(height: 12),
              const Text(
                "L'inscription des fournisseurs est gratuite et sans commission durant la phase MVP, le temps de valider la traction du marché. Une commission (8% à 12%), des abonnements Pro et d'autres options pourront être activés plus tard, de façon transparente.",
                style: TextStyle(color: AppColors.textSecondary, height: 1.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PricingCard extends StatelessWidget {
  final String title;
  final Gradient gradient;
  final List<String> options;
  const _PricingCard({required this.title, required this.gradient, required this.options});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(24), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(12)), child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
          const SizedBox(height: 18),
          ...options.map((o) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  const Icon(Icons.check, size: 16, color: AppColors.success),
                  const SizedBox(width: 10),
                  Expanded(child: Text(o, style: const TextStyle(fontSize: 13.5))),
                ]),
              )),
        ],
      ),
    );
  }
}
