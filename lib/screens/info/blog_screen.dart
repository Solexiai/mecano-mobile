import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class BlogScreen extends StatelessWidget {
  final String locale;
  const BlogScreen({super.key, required this.locale});

  String _tr({required String fr, required String en, required String es}) {
    switch (locale) {
      case 'en':
        return en;
      case 'es':
        return es;
      default:
        return fr;
    }
  }

  @override
  Widget build(BuildContext context) {
    context.watch<LocaleProvider>();
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final posts = <(IconData, String, String, String)>[
      (
        Icons.local_shipping_outlined,
        _tr(fr: '5 conseils pour préparer votre livraison de gros objet', en: '5 tips to prepare your large-item delivery', es: '5 consejos para preparar la entrega de un artículo grande'),
        _tr(fr: 'Livraison', en: 'Delivery', es: 'Entrega'),
        _tr(fr: 'À venir', en: 'Coming soon', es: 'Próximamente'),
      ),
      (
        Icons.build_outlined,
        _tr(fr: 'Signes qui indiquent que vous avez besoin d\'un mécanicien mobile', en: 'Signs you need a mobile mechanic', es: 'Señales de que necesitas un mecánico móvil'),
        _tr(fr: 'Mécanique', en: 'Mechanic', es: 'Mecánica'),
        _tr(fr: 'À venir', en: 'Coming soon', es: 'Próximamente'),
      ),
      (
        Icons.storefront_outlined,
        _tr(fr: 'Comment démarrer une activité de chauffeur indépendant au Québec', en: 'How to start an independent driving business in Quebec', es: 'Cómo iniciar un negocio de conductor independiente en Quebec'),
        _tr(fr: 'Fournisseurs', en: 'Providers', es: 'Proveedores'),
        _tr(fr: 'À venir', en: 'Coming soon', es: 'Próximamente'),
      ),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: SectionTitle(
                    title: _tr(fr: 'Blogue', en: 'Blog', es: 'Blog'),
                    subtitle: _tr(
                      fr: 'Conseils, actualités et ressources pour clients et fournisseurs Movi-k.',
                      en: 'Tips, news and resources for Movi-k customers and providers.',
                      es: 'Consejos, noticias y recursos para clientes y proveedores de Movi-k.',
                    ),
                  ),
                ),
                const ComingSoonBadge(),
              ]),
              const SizedBox(height: 32),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 3 : 1,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: isDesktop ? 0.95 : 1.3,
                children: posts
                    .map((p) => Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(gradient: AppColors.deliveryGradient, borderRadius: BorderRadius.circular(14)),
                                child: Icon(p.$1, color: Colors.white),
                              ),
                              const SizedBox(height: 16),
                              Text(p.$3.toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 0.5)),
                              const SizedBox(height: 8),
                              Text(p.$2, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5, height: 1.35)),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(color: AppColors.warning.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
                                child: Text(p.$4, style: const TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700, fontSize: 11)),
                              ),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                child: Row(children: [
                  const Icon(Icons.article_outlined, color: AppColors.textSecondary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _tr(
                        fr: "Le blogue Movi-k est en préparation. Revenez bientôt pour découvrir nos premiers articles.",
                        en: 'The Movi-k blog is being prepared. Check back soon for our first articles.',
                        es: 'El blog de Movi-k está en preparación. Vuelva pronto para ver nuestros primeros artículos.',
                      ),
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
