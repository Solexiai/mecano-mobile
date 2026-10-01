import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../l10n/home_copy.dart';
import '../../providers/locale_provider.dart';
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
    showFooter: true,
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
                const SizedBox(height: 28),
                _HeroRight(quote: quote),
                const SizedBox(height: 28),
                const _Trust(),
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
                            aspectRatio: 524 / 350,
                            child: Image.asset(
                              'assets/home/hero_clean.png',
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
    final locale = context.watch<LocaleProvider>().locale;
    final desktop = MediaQuery.sizeOf(context).width >= 980;
    String h(String key) => HomeCopy.text(key, locale);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .88),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: const Color(0xFFDCEBFA)),
          ),
          child: Text(
            h('granby_launch'),
            style: const TextStyle(
              color: Color(0xFF0879E8),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          h('title'),
          style: TextStyle(
            color: AppColors.primaryDark,
            fontSize: desktop ? 48 : 36,
            fontWeight: FontWeight.w900,
            height: 1.04,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          h('intro'),
          style: TextStyle(
            color: const Color(0xFF21436F),
            fontSize: desktop ? 17 : 16,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          h('prelaunch_status'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
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
              child: Text(h('quote')),
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
              child: Text(h('driver_link')),
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
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDCEBFA)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .10),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            h('quote_card_title'),
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _QuotePrepRow(
            icon: Icons.inventory_2_outlined,
            text: h('quote_card_1'),
          ),
          const SizedBox(height: 10),
          _QuotePrepRow(icon: Icons.route_outlined, text: h('quote_card_2')),
          const SizedBox(height: 10),
          _QuotePrepRow(
            icon: Icons.local_shipping_outlined,
            text: h('quote_card_3'),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0879E8),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(h('quote_start')),
          ),
          const SizedBox(height: 10),
          Text(
            h('quote_note'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuotePrepRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _QuotePrepRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: const Color(0xFF0879E8), size: 19),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.only(top: 7),
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFF21436F),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    ],
  );
}

class _Trust extends StatelessWidget {
  const _Trust();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);
    final data = [
      (
        Icons.verified_user_outlined,
        locale == 'en'
            ? 'Driver files reviewed'
            : locale == 'es'
            ? 'Expedientes revisados'
            : 'Dossiers chauffeurs vérifiés',
        locale == 'en'
            ? 'Profile, vehicle and required documents'
            : locale == 'es'
            ? 'Perfil, vehículo y documentos requeridos'
            : 'Profil, véhicule et documents requis',
      ),
      (
        Icons.receipt_long_outlined,
        h('reassurance_quote'),
        h('reassurance_quote_body'),
      ),
      (
        Icons.location_on_outlined,
        h('reassurance_local'),
        h('reassurance_local_body'),
      ),
    ];
    final wide = MediaQuery.sizeOf(context).width >= 760;
    final items = data
        .map(
          (e) => Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(e.$1, color: const Color(0xFF075FC4), size: 30),
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
                      const SizedBox(height: 2),
                      Text(
                        e.$3,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 11,
                          height: 1.25,
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
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);
    final data = [
      ('cat_furniture', 'assets/home/category_furniture.png', ''),
      ('cat_appliances', 'assets/home/category_appliances.png', ''),
      (
        'cat_marketplace',
        'assets/home/category_marketplace.png',
        h('marketplace_examples'),
      ),
      ('cat_building_materials', 'assets/home/category_materials.png', ''),
      ('cat_tv', 'assets/home/category_tv.png', ''),
      ('cat_costco', 'assets/home/category_store.png', ''),
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
            desktop ? 20 : 34,
            desktop ? 24 : 16,
            desktop ? 16 : 34,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                h('categories_title'),
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                h('categories_body'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, c) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final cols = scale > 1.35
                      ? 1
                      : (c.maxWidth >= 900 ? 6 : (c.maxWidth >= 620 ? 3 : 2));
                  const gap = 10.0;
                  final cardWidth = cols == 1
                      ? c.maxWidth
                      : (c.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (final e in data)
                        SizedBox(
                          width: cardWidth,
                          child: _Category(
                            assetPath: e.$2,
                            title: t(e.$1),
                            sub: e.$3,
                            categoryKey: e.$1,
                            onTap: () => onQuote(e.$1),
                          ),
                        ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              Text(
                h('item_note'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                  height: 1.4,
                ),
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
    final locale = context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);
    final data = [
      (Icons.inventory_2_outlined, h('step1'), h('step1_body')),
      (Icons.receipt_long_outlined, h('step2'), h('step2_body')),
      (Icons.local_shipping_outlined, h('step3'), h('step3_body')),
      (Icons.route_outlined, h('step4'), h('step4_body')),
    ];

    return Container(
      width: double.infinity,
      color: const Color(0xFFEEF8FF),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 38),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Column(
            children: [
              Text(
                h('steps_title'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                h('prelaunch_status'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 24),
              LayoutBuilder(
                builder: (context, constraints) {
                  final scale = MediaQuery.textScalerOf(context).scale(1);
                  final columns = scale > 1.35
                      ? 1
                      : constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 600
                      ? 2
                      : 1;
                  final spacing = 14.0;
                  final cardWidth = columns == 1
                      ? constraints.maxWidth
                      : (constraints.maxWidth - spacing * (columns - 1)) /
                            columns;
                  return Wrap(
                    spacing: spacing,
                    runSpacing: spacing,
                    children: [
                      for (var i = 0; i < data.length; i++)
                        SizedBox(
                          width: cardWidth,
                          child: _StepCard(
                            number: i + 1,
                            icon: data[i].$1,
                            title: data[i].$2,
                            body: data[i].$3,
                          ),
                        ),
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

class _StepCard extends StatelessWidget {
  final int number;
  final IconData icon;
  final String title;
  final String body;
  const _StepCard({
    required this.number,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 210),
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: const Color(0xFFDCEBFA)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF0879E8),
              child: Text(
                '$number',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(icon, color: const Color(0xFF075FC4), size: 30),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            color: AppColors.textSecondary,
            height: 1.45,
            fontSize: 13,
          ),
        ),
      ],
    ),
  );
}

class _Reassurance extends StatelessWidget {
  const _Reassurance();

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);
    final data = [
      (
        Icons.receipt_long_outlined,
        h('reassurance_quote'),
        h('reassurance_quote_body'),
      ),
      (
        Icons.route_outlined,
        h('reassurance_tracking'),
        h('reassurance_tracking_body'),
      ),
      (
        Icons.verified_user_outlined,
        locale == 'en'
            ? 'Driver review'
            : locale == 'es'
            ? 'Revisión de conductores'
            : 'Vérification chauffeur',
        locale == 'en'
            ? 'Profile and required documents reviewed'
            : locale == 'es'
            ? 'Perfil y documentos requeridos revisados'
            : 'Profil et documents requis examinés',
      ),
      (
        Icons.location_on_outlined,
        h('reassurance_local'),
        h('reassurance_local_body'),
      ),
    ];
    final desktop = MediaQuery.sizeOf(context).width >= 980;

    return Container(
      width: double.infinity,
      color: const Color(0xFF075AAE),
      child: ResponsivePadding(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: desktop ? 18 : 26),
          child: LayoutBuilder(
            builder: (context, c) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              final wide = c.maxWidth >= 850 && scale <= 1.35;
              final items = data
                  .map(
                    (e) => Padding(
                      padding: EdgeInsets.all(desktop ? 8 : 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                const SizedBox(height: 2),
                                Text(
                                  e.$3,
                                  style: const TextStyle(
                                    color: Color(0xFFD8EBFF),
                                    fontSize: 11,
                                    height: 1.3,
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
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    String h(String key) => HomeCopy.text(key, locale);

    return Container(
      width: double.infinity,
      color: Colors.white,
      child: ResponsivePadding(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 36),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 28,
            runSpacing: 20,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 660),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      h('local_cta_title'),
                      style: const TextStyle(
                        color: AppColors.primaryDark,
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      h('local_cta_body'),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  OutlinedButton(
                    onPressed: onDriver,
                    child: Text(h('driver_link')),
                  ),
                  ElevatedButton(
                    onPressed: onQuote,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0879E8),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(h('quote')),
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
