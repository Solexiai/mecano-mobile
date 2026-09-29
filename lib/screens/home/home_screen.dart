import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/app_colors.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  final String locale;
  const HomeScreen({super.key, required this.locale});
  void _quote(BuildContext c, [String? category]) {
    final suffix = category == null ? '' : '?category=$category';
    c.go('/$locale/livraison/demande$suffix');
  }

  void _driver(BuildContext c) => c.go('/$locale/devenir-chauffeur');
  @override
  Widget build(BuildContext context) => AppShell(
    locale: locale,
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
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    return Container(
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
          padding: EdgeInsets.symmetric(vertical: desktop ? 54 : 34),
          child: Column(
            children: [
              if (desktop)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 11,
                      child: _HeroCopy(quote: quote, driver: driver),
                    ),
                    const SizedBox(width: 30),
                    Expanded(flex: 9, child: _HeroRight(quote: quote)),
                  ],
                )
              else ...[
                _HeroCopy(quote: quote, driver: driver),
                const SizedBox(height: 28),
                _HeroRight(quote: quote),
              ],
              SizedBox(height: desktop ? 64 : 28),
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
            fontSize: desktop ? 56 : 38,
            fontWeight: FontWeight.w900,
            height: 1.03,
            letterSpacing: -1.5,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .82),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDCEBFA)),
          ),
          child: const Text(
            'D’un simple colis aux meubles, électroménagers et matériaux, '
            'Movi-K simplifie vos livraisons selon votre projet.',
            style: TextStyle(
              color: Color(0xFF21436F),
              fontSize: 17,
              height: 1.48,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
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
  final VoidCallback quote;
  const _HeroRight({required this.quote});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 980;

    final scene = Semantics(
      image: true,
      label: 'Camionnette Movi-K et chauffeur préparant une livraison',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: AspectRatio(
          aspectRatio: 524 / 350,
          child: Image.asset(
            'assets/home/hero_clean.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerRight,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );

    if (!desktop) {
      return Column(
        children: [
          scene,
          const SizedBox(height: 14),
          _QuoteCard(onTap: quote),
        ],
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        scene,
        Positioned(
          left: 70,
          right: 14,
          bottom: -42,
          child: _QuoteCard(onTap: quote),
        ),
      ],
    );
  }
}

class _QuoteCard extends StatelessWidget {
  final VoidCallback onTap;
  const _QuoteCard({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
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
        const SizedBox(height: 10),
        _FlowField(
          icon: Icons.location_on_outlined,
          text: 'Adresse de départ',
          onTap: onTap,
        ),
        const SizedBox(height: 7),
        _FlowField(
          icon: Icons.location_on_outlined,
          text: 'Adresse de livraison',
          onTap: onTap,
        ),
        const SizedBox(height: 7),
        _FlowField(
          icon: Icons.inventory_2_outlined,
          text: 'Que souhaitez-vous faire livrer ?',
          onTap: onTap,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0879E8),
            foregroundColor: Colors.white,
          ),
          child: const Text('Obtenir mon devis  →'),
        ),
        const SizedBox(height: 6),
        const Text(
          'Adresses et zone de service validées avant le devis.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
        'Identité et documents vérifiés',
      ),
      (
        Icons.sell_outlined,
        'Tarifs clairs',
        'Consultez votre prix avant de confirmer',
      ),
      (
        Icons.location_on_outlined,
        'Un service près de chez vous',
        'Zone de lancement : Granby et environs • zone vérifiée avant le devis',
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
        'Facebook Marketplace, Kijiji et petites annonces',
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
    return Container(
      color: Colors.white,
      width: double.infinity,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 62),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tout ce que vous pouvez faire livrer',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Des objets du quotidien aux plus encombrants, Movi-K s’occupe de votre livraison.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 1000
                      ? 6
                      : (c.maxWidth >= 620 ? 3 : 2);
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: cols == 6
                        ? .62
                        : (cols == 3 ? 1.05 : .62),
                    children: data
                        .map(
                          (e) => _Category(
                            assetPath: e.$2,
                            title: e.$3,
                            sub: e.$4,
                            onTap: () => onQuote(e.$1),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
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
  final VoidCallback onTap;
  const _Category({
    required this.assetPath,
    required this.title,
    required this.sub,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Commencer un devis pour $title',
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(12),
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
                width: 92,
                height: 82,
                child: Image.asset(
                  assetPath,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                  semanticLabel: title,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w800,
              ),
            ),
            if (sub.isNotEmpty) ...[
              const SizedBox(height: 5),
              Text(
                sub,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 9,
                  height: 1.2,
                ),
              ),
            ],
            const SizedBox(height: 8),
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
    const data = [
      (
        Icons.edit_location_alt_outlined,
        'Décrivez votre livraison',
        'Indiquez l’objet et les adresses.',
      ),
      (
        Icons.request_quote_outlined,
        'Obtenez votre prix',
        'Consultez votre devis et confirmez votre demande.',
      ),
      (
        Icons.route_outlined,
        'Suivez l’avancement',
        'Voyez les étapes de votre livraison.',
      ),
      (
        Icons.check_circle_outline,
        'C’est livré!',
        'Votre objet arrive à destination.',
      ),
    ];
    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF8FF),
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 58),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Une livraison en 4 étapes simples',
                style: TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 26),
              LayoutBuilder(
                builder: (context, c) {
                  final wide = c.maxWidth >= 800;
                  Widget tile(int i) => Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: const Color(0xFF0879E8),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Icon(
                          data[i].$1,
                          size: 38,
                          color: const Color(0xFF075FC4),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          data[i].$2,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          data[i].$3,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  );
                  final phone = Semantics(
                    image: true,
                    label: 'Exemple du suivi d’une livraison Movi-K',
                    child: Image.asset(
                      'assets/home/tracking_phone.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  );
                  return wide
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: List.generate(
                                  4,
                                  (i) => Expanded(child: tile(i)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 18),
                            SizedBox(width: 245, height: 315, child: phone),
                          ],
                        )
                      : Column(
                          children: [
                            ...List.generate(
                              4,
                              (i) => SizedBox(height: 180, child: tile(i)),
                            ),
                            SizedBox(height: 300, child: phone),
                          ],
                        );
                },
              ),
            ],
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
        'Ramassage et livraison',
        'De l’adresse de départ à destination',
      ),
      (
        Icons.credit_card_outlined,
        'Paiement sécurisé',
        'Vos informations sont protégées',
      ),
      (
        Icons.groups_outlined,
        'Une équipe à vos côtés',
        'Support lorsque vous en avez besoin',
      ),
      (
        Icons.location_on_outlined,
        'Un service près de chez vous',
        'Granby et environs • validation avant le devis',
      ),
    ];
    return Container(
      width: double.infinity,
      color: const Color(0xFF075AAE),
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth >= 850;
              final items = data
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        children: [
                          Icon(e.$1, color: Colors.white, size: 30),
                          const SizedBox(width: 10),
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
                width: 700,
                height: 116,
                child: Image.asset(
                  'assets/home/quebec_silhouette.png',
                  fit: BoxFit.cover,
                  alignment: Alignment.bottomLeft,
                ),
              ),
            ),
          ),
        ),
        ResponsivePadding(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 42, 0, 48),
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
