import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../providers/locale_provider.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';
import '../../widgets/coming_soon_badge.dart';

class AboutScreen extends StatelessWidget {
  final String locale;
  const AboutScreen({super.key, required this.locale});

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
    final t = context.watch<LocaleProvider>().t;
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    final values = <(IconData, String, String)>[
      (Icons.shield_moon_outlined, _tr(fr: 'Fiable', en: 'Reliable', es: 'Confiable'), _tr(fr: 'Des fournisseurs vérifiés, des engagements tenus.', en: 'Verified providers, commitments kept.', es: 'Proveedores verificados, compromisos cumplidos.')),
      (Icons.location_on_outlined, _tr(fr: 'Local', en: 'Local', es: 'Local'), _tr(fr: 'Ancrés dans les communautés du Québec et du Canada.', en: 'Rooted in Quebec and Canadian communities.', es: 'Arraigados en las comunidades de Quebec y Canadá.')),
      (Icons.diversity_3_outlined, _tr(fr: 'Humain', en: 'Human', es: 'Humano'), _tr(fr: 'Un service à échelle humaine, pas un algorithme froid.', en: 'Human-scale service, not a cold algorithm.', es: 'Un servicio a escala humana, no un algoritmo frío.')),
      (Icons.bolt_outlined, _tr(fr: 'Rapide', en: 'Fast', es: 'Rápido'), _tr(fr: 'Trouvez un fournisseur disponible en quelques minutes.', en: 'Find an available provider within minutes.', es: 'Encuentre un proveedor disponible en minutos.')),
      (Icons.visibility_outlined, _tr(fr: 'Transparent', en: 'Transparent', es: 'Transparente'), _tr(fr: 'Profils, tarifs et avis clairement affichés.', en: 'Profiles, rates and reviews clearly displayed.', es: 'Perfiles, tarifas y reseñas claramente mostrados.')),
      (Icons.workspace_premium_outlined, _tr(fr: 'Professionnel', en: 'Professional', es: 'Profesional'), _tr(fr: 'Des standards de qualité exigeants pour chaque fournisseur.', en: 'High quality standards for every provider.', es: 'Estándares de calidad exigentes para cada proveedor.')),
    ];

    return AppShell(
      locale: locale,
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: isDesktop ? 64 : 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionTitle(title: t('nav_about')),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(gradient: AppColors.heroGradient, borderRadius: BorderRadius.circular(24)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _tr(
                        fr: 'Notre mission',
                        en: 'Our mission',
                        es: 'Nuestra misión',
                      ),
                      style: const TextStyle(color: AppColors.glowGreen, fontWeight: FontWeight.w700, fontSize: 14, letterSpacing: 0.5),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _tr(
                        fr: 'Connecter les gens à des fournisseurs locaux de confiance pour tout ce qui est trop gros à transporter ou trop compliqué à réparer soi-même.',
                        en: 'Connecting people to trusted local providers for anything too big to move or too complicated to fix on their own.',
                        es: 'Conectar a las personas con proveedores locales de confianza para todo lo que sea demasiado grande de mover o demasiado complicado de reparar por su cuenta.',
                      ),
                      style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),
              Row(children: [
                Text(
                  _tr(fr: 'Notre histoire', en: 'Our story', es: 'Nuestra historia'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 12),
                const ComingSoonBadge(small: true),
              ]),
              const SizedBox(height: 12),
              Text(
                _tr(
                  fr: "Movi-k est né d'un constat simple au Québec: trouver un chauffeur de confiance pour un gros achat ou un mécanicien mobile fiable en cas de pépin repose encore trop souvent sur le bouche-à-oreille ou des petites annonces peu structurées. Nous construisons une plateforme locale, transparente et humaine pour changer cela — un marché en démarrage, pensé pour et avec les fournisseurs indépendants de nos communautés.",
                  en: 'Movi-k was born from a simple observation in Quebec: finding a trusted driver for a big purchase, or a reliable mobile mechanic when something breaks down, still relies too often on word-of-mouth or loosely structured classifieds. We are building a local, transparent and human platform to change that — an early-stage marketplace, built for and with the independent providers of our communities.',
                  es: 'Movi-k nació de una observación simple en Quebec: encontrar un conductor de confianza para una compra grande, o un mecánico móvil confiable cuando algo falla, todavía depende demasiado del boca a boca o de anuncios poco estructurados. Estamos construyendo una plataforma local, transparente y humana para cambiar eso: un mercado en etapa inicial, creado para y con los proveedores independientes de nuestras comunidades.',
                ),
                style: const TextStyle(color: AppColors.textSecondary, height: 1.7, fontSize: 15),
              ),
              const SizedBox(height: 40),
              Text(_tr(fr: 'Nos valeurs', en: 'Our values', es: 'Nuestros valores'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: isDesktop ? 3 : (MediaQuery.of(context).size.width >= 600 ? 2 : 1),
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: isDesktop ? 1.5 : 1.9,
                children: values
                    .map((v) => Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(v.$1, color: AppColors.primary),
                              const SizedBox(height: 10),
                              Text(v.$2, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text(v.$3, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5, height: 1.4)),
                            ],
                          ),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_tr(fr: 'Vous voulez faire partie de la communauté?', en: 'Want to be part of the community?', es: '¿Quieres ser parte de la comunidad?'), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 4),
                          Text(_tr(fr: 'Devenez chauffeur ou mécanicien mobile dès aujourd\'hui.', en: 'Become a driver or mobile mechanic today.', es: 'Conviértase en conductor o mecánico móvil hoy.'), style: const TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    ElevatedButton(onPressed: () => context.go('/$locale/devenir-chauffeur'), child: Text(t('nav_become_provider'))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
