import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  final String locale;
  const HomeScreen({super.key, required this.locale});
  void _quote(BuildContext c, [String? category]) {
    final suffix = category == null || category.isEmpty
        ? ''
        : '?category=$category';
    c.go('/$locale/livraison/demande$suffix');
  }

  void _driver(BuildContext c) => c.go('/$locale/devenir-chauffeur');
  @override
  Widget build(BuildContext context) => AppShell(
    locale: locale,
    showFooter: false,
    child: Column(
      children: [
        _Hero(quote: () => _quote(context), driver: () => _driver(context)),
        _Categories(onQuote: (category) => _quote(context, category)),
        const _Steps(),
        const _Reassurance(),
        _LocalCta(
          onQuote: () => _quote(context),
          onDriver: () => _driver(context),
        ),
      ],
    ),
  );
}

class _Hero extends StatelessWidget {
  final VoidCallback quote, driver;
  const _Hero({required this.quote, required this.driver});
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 980;

    if (!desktop) {
      return Container(
        key: const Key('home-hero'),
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFE8F5FF), Colors.white],
          ),
        ),
        child: ResponsivePadding(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 34),
            child: Column(
              children: [
                _HeroCopy(quote: quote, driver: driver),
                const SizedBox(height: 18),
                _HeroRight(quote: quote, driver: driver),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      key: const Key('home-hero'),
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF6FF), Colors.white],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(34, 34, 34, 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 5,
                    child: _HeroCopy(quote: quote, driver: driver),
                  ),
                  const SizedBox(width: 32),
                  Expanded(
                    flex: 6,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Image.asset(
                              'assets/home/hero_reference_right.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.centerRight,
                              filterQuality: FilterQuality.high,
                              semanticLabel:
                                  'Camionnette Movi-K avec chauffeur préparant une livraison',
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 430),
                            child: _QuoteCard(onTap: quote),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              const _Trust(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final VoidCallback quote, driver;
  const _HeroCopy({required this.quote, required this.driver});
  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    if (!desktop) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '●  Suivi en temps réel',
            style: TextStyle(
              color: Color(0xFF0879E8),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          SizedBox(height: 14),
          Text.rich(
            TextSpan(children: [
              TextSpan(text: 'Votre livraison\\nen '),
              TextSpan(
                text: 'temps réel.',
                style: TextStyle(color: Color(0xFF0879E8)),
              ),
            ]),
            style: TextStyle(
              color: AppColors.primaryDark,
              fontSize: 38,
              height: 1.02,
              fontWeight: FontWeight.w900,
              letterSpacing: -1.2,
            ),
          ),
          SizedBox(height: 12),
          Text(
            'Suivez chaque étape, depuis l’enlèvement jusqu’à la livraison.',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 19,
              height: 1.28,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LIVRAISON SELON VOS PROJETS',
          style: TextStyle(
            color: Color(0xFF0879E8),
            fontWeight: FontWeight.w800,
            letterSpacing: 2,
            fontSize: 13,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Faites livrer ce qui ne rentre pas dans votre véhicule.',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: desktop ? 52 : 38,
            fontWeight: FontWeight.w900,
            height: 1.03,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCEBFA)),
          ),
          child: const Text(
            'D’un simple colis, une boîte ou un petit déménagement.\n'
            'Jusqu’aux meubles, électroménagers et matériaux,\n'
            'Movi-K simplifie votre livraison.',
            style: TextStyle(
              color: Color(0xFF21436F),
              fontSize: 17,
              height: 1.48,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              key: const Key('home-primary-quote'),
              onPressed: quote,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0879E8),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
              child: const Text('Obtenir mon devis  →'),
            ),
            OutlinedButton(
              onPressed: driver,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF075FC4),
                side: const BorderSide(color: Color(0xFF0879E8)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 18,
                ),
              ),
              child: const Text('Devenir chauffeur'),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroRight extends StatelessWidget {
  final VoidCallback quote, driver;
  const _HeroRight({required this.quote, required this.driver});

  @override
  Widget build(BuildContext context) {
    const benefits = [
      (Icons.location_on_rounded, 'Localisation\nen direct', 'Voyez où se trouve\nvotre chauffeur'),
      (Icons.notifications_rounded, 'Notifications\ninstantanées', 'Soyez informé\nà chaque étape'),
      (Icons.verified_user_rounded, 'Livraison en\ntoute confiance', 'Simple, rapide\net sécuritaire'),
    ];
    const cats = [
      (Icons.chair_outlined, 'Meubles'),
      (Icons.local_laundry_service_outlined, 'Électroménagers'),
      (Icons.inventory_2_outlined, 'Boîtes et colis'),
      (Icons.home_outlined, 'Petits déménagements'),
    ];

    return Column(
      children: [
        SizedBox(
          height: 455,
          width: double.infinity,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(26),
                  child: Image.asset(
                    'assets/home/hero_clean.png',
                    fit: BoxFit.cover,
                    alignment: Alignment.centerRight,
                    filterQuality: FilterQuality.high,
                  ),
                ),
              ),
              Positioned(
                left: 12,
                top: 24,
                child: Transform.rotate(
                  angle: -0.08,
                  child: const Text(
                    'Suivez chaque\nétape en temps réel !',
                    style: TextStyle(
                      color: Color(0xFF075FC4),
                      fontSize: 15,
                      height: 1.05,
                      fontWeight: FontWeight.w900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 30,
                top: 74,
                bottom: 8,
                width: 220,
                child: Transform.rotate(
                  angle: .07,
                  child: Image.asset(
                    'assets/home/tracking_phone.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                    semanticLabel: 'Suivi de livraison Movi-K en temps réel',
                  ),
                ),
              ),
              const Positioned(
                right: 10,
                bottom: 20,
                child: Text(
                  'Vos objets\navancent,\nvous aussi !',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    height: 1.0,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    shadows: [Shadow(color: Color(0xAA000000), blurRadius: 8)],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in benefits)
              Expanded(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 23,
                      backgroundColor: const Color(0xFFF1F8FF),
                      child: Icon(item.$1, color: const Color(0xFF0879E8)),
                    ),
                    const SizedBox(height: 7),
                    Text(item.$2, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.primaryDark, fontWeight: FontWeight.w900, fontSize: 11, height: 1.05)),
                    const SizedBox(height: 4),
                    Text(item.$3, textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 9, height: 1.1)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        KeyedSubtree(key: const Key('home-primary-quote'), child: _QuoteCard(onTap: quote)),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: driver,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF075FC4),
              side: const BorderSide(color: Color(0xFF0879E8)),
              padding: const EdgeInsets.symmetric(vertical: 15),
            ),
            child: const Text('Devenir chauffeur', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final item in cats)
              Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
                  decoration: BoxDecoration(color: const Color(0xFFF3F9FF), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    children: [
                      Icon(item.$1, color: const Color(0xFF075FC4), size: 22),
                      const SizedBox(height: 4),
                      Text(item.$2, textAlign: TextAlign.center, maxLines: 2,
                        style: const TextStyle(color: Color(0xFF075FC4), fontSize: 8.5, height: 1.05)),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        const Row(
          children: [
            Expanded(child: _MiniTrust(icon: Icons.local_shipping_outlined, text: 'Partout\nau Québec')),
            Expanded(child: _MiniTrust(icon: Icons.handshake_outlined, text: 'Service local\net fiable')),
            Expanded(child: _MiniTrust(icon: Icons.shield_outlined, text: 'Des gens de\nconfiance')),
          ],
        ),
      ],
    );
  }
}

class _MiniTrust extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniTrust({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(icon, color: const Color(0xFF082A80), size: 24),
      const SizedBox(width: 5),
      Flexible(child: Text(text, style: const TextStyle(color: Color(0xFF45658F), fontSize: 9, height: 1.05))),
    ],
  );
}
class _QuoteCard extends StatelessWidget {
  final VoidCallback onTap;
  const _QuoteCard({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .12),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Obtenez votre devis en quelques clics',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        _FlowField(
          icon: Icons.location_on_outlined,
          text: 'Adresse de départ',
          onTap: onTap,
        ),
        const SizedBox(height: 6),
        _FlowField(
          icon: Icons.location_on_outlined,
          text: 'Adresse de livraison',
          onTap: onTap,
        ),
        const SizedBox(height: 6),
        _FlowField(
          icon: Icons.inventory_2_outlined,
          text: 'Que souhaitez-vous faire livrer ?',
          onTap: onTap,
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0879E8),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(44),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text('Obtenir mon devis  →'),
        ),
        const SizedBox(height: 4),
        const Text(
          '🔒 Gratuit · Sans engagement',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 9, color: AppColors.textSecondary),
        ),
      ],
    ),
  );
}

class _FlowField extends StatelessWidget {
  final IconData icon;
  final String text;
  final VoidCallback onTap;
  const _FlowField({
    required this.icon,
    required this.text,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF075FC4), size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Trust extends StatelessWidget {
  const _Trust();
  @override
  Widget build(BuildContext context) {
    const data = [
      (
        Icons.verified_user_outlined,
        'Chauffeurs vérifiés',
        'Des pros de confiance',
      ),
      (
        Icons.sell_outlined,
        'Tarifs clairs',
        'Sans mauvaise surprise',
      ),
      (
        Icons.location_on_outlined,
        'Un service près de chez vous',
        'Près de chez vous',
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final items = data
        .map(
          (e) => Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Icon(e.$1, color: const Color(0xFF075FC4), size: 32),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.$2,
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        e.$3,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        )
        .toList();
    return wide
        ? Row(children: items.map((e) => Expanded(child: e)).toList())
        : Column(children: items);
  }
}

class _Categories extends StatelessWidget {
  final ValueChanged<String> onQuote;
  const _Categories({required this.onQuote});
  @override
  Widget build(BuildContext context) {
    const data = [
      ('cat_furniture', 'assets/home/category_furniture.png', 'Meubles', ''),
      (
        'cat_appliances',
        'assets/home/category_appliances.png',
        'Électroménagers',
        '',
      ),
      (
        'cat_marketplace',
        'assets/home/category_marketplace.png',
        'Achats Marketplace',
        'Leboncoin, Marketplace, Kijiji, etc.',
      ),
      (
        'cat_building_materials',
        'assets/home/category_materials.png',
        'Matériaux de construction',
        '',
      ),
      ('cat_tv', 'assets/home/category_tv.png', 'Téléviseurs', ''),
      ('cat_costco', 'assets/home/category_store.png', 'Achats en magasin', ''),
    ];
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    return Container(
      color: const Color(0xFFF9FCFF),
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        desktop ? 18 : 0,
        0,
        desktop ? 18 : 0,
        desktop ? 8 : 0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(desktop ? 22 : 0),
          border: Border.all(color: const Color(0xFFE3EDF8)),
          boxShadow: desktop
              ? [
                  BoxShadow(
                    color: const Color(0xFF0B3B78).withValues(alpha: .06),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ]
              : const [],
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            desktop ? 24 : 16,
            desktop ? 14 : 38,
            desktop ? 24 : 16,
            desktop ? 10 : 38,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tout ce que vous pouvez faire livrer',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Des objets du quotidien aux plus encombrants, Movi-K s’occupe de tout.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (desktop)
                    TextButton(
                      onPressed: () => onQuote(''),
                      child: const Text('Voir toutes les catégories  →'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, c) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final cols = scale > 1.4
                      ? 1
                      : (c.maxWidth >= 900 ? 6 : (c.maxWidth >= 620 ? 3 : 2));
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 10,
                    childAspectRatio: cols == 6
                        ? .72
                        : (cols == 3 ? .82 : (cols == 1 ? 1.0 : .72)),
                    children: data
                        .map(
                          (e) => _Category(
                            assetPath: e.$2,
                            title: e.$3,
                            sub: e.$4,
                            categoryKey: e.$1,
                            onTap: () => onQuote(e.$1),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
              if (!desktop) ...[
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => onQuote(''),
                    child: const Text('Voir toutes les catégories  →'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Category extends StatelessWidget {
  final String assetPath;
  final String title;
  final String sub;
  final String categoryKey;
  final VoidCallback onTap;
  const _Category({
    required this.assetPath,
    required this.title,
    required this.sub,
    required this.categoryKey,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Commencer un devis pour $title',
    child: InkWell(
      key: Key('home-category-$categoryKey'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFF),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFDCE9F8)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 86,
                height: 66,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: title,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                sub,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  height: 1.2,
                ),
              ),
            ],
            const SizedBox(height: 5),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: Color(0xFF0879E8),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF8FF),
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 28 : 0,
        vertical: desktop ? 28 : 0,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: desktop ? 760 : double.infinity),
          child: Semantics(
            image: true,
            label: 'Une livraison en 3 étapes simples : Préparer, Réservez et c’est livré !',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(desktop ? 22 : 0),
              child: Image.asset(
                'assets/home/steps_exact.webp',
                width: double.infinity,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class _Reassurance extends StatelessWidget {
  const _Reassurance();
  @override
  Widget build(BuildContext context) {
    const data = [
      (
        Icons.home_outlined,
        'Livraison à domicile',
        'Du rez-de-chaussée au domicile',
      ),
      (
        Icons.credit_card_outlined,
        'Paiement sécurisé',
        'Vos informations sont protégées',
      ),
      (
        Icons.groups_outlined,
        'Une équipe à vos côtés',
        'Support réactif',
      ),
      (
        Icons.location_on_outlined,
        'Service partout',
        'Partout au Québec et ses environs',
      ),
    ];
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    return Container(
      width: double.infinity,
      color: const Color(0xFF075AAE),
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: desktop ? 14 : 26),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 850;
              final items = data
                  .map(
                    (e) => Padding(
                      padding: EdgeInsets.all(desktop ? 6 : 10),
                      child: Row(
                        children: [
                          Icon(
                            e.$1,
                            color: Colors.white,
                            size: desktop ? 27 : 30,
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e.$2,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  e.$3,
                                  style: const TextStyle(
                                    color: Color(0xFFD8EBFF),
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList();
              return wide
                  ? Row(children: items.map((e) => Expanded(child: e)).toList())
                  : Column(children: items);
            },
          ),
        ),
      ),
    );
  }
}

class _LocalCta extends StatelessWidget {
  final VoidCallback onQuote, onDriver;
  const _LocalCta({required this.onQuote, required this.onDriver});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: Colors.white,
    child: Stack(
      alignment: Alignment.bottomLeft,
      children: [
        Positioned(
          left: 0,
          bottom: 0,
          child: IgnorePointer(
            child: Opacity(
              opacity: .9,
              child: SizedBox(
                width: 420,
                height: 105,
                child: Image.asset(
                  'assets/home/quebec_silhouette.png',
                  fit: BoxFit.contain,
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
        ),
        ResponsivePadding(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              0,
              MediaQuery.sizeOf(context).width >= 980 ? 20 : 42,
              0,
              MediaQuery.sizeOf(context).width >= 980 ? 24 : 48,
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 18,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Des gens d’ici, pour vous simplifier la vie.',
                      style: TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Movi-K — Livraison simplifiée.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    OutlinedButton(
                      onPressed: onDriver,
                      child: const Text('Devenir chauffeur'),
                    ),
                    ElevatedButton(
                      onPressed: onQuote,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0879E8),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Obtenir mon devis  →'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
