import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/responsive.dart';
import '../../l10n/home_copy.dart';
import '../../providers/locale_provider.dart';
import '../../router/delivery_request_intent.dart';
import '../../widgets/app_shell.dart';
import '../../widgets/section_title.dart';

class HomeScreen extends StatelessWidget {
  final String locale;
  const HomeScreen({super.key, required this.locale});
  String h(String key) => HomeCopy.text(key, locale);
  @override
  Widget build(BuildContext context) => Title(title: "Movi-K | ${h('eyebrow')}", color: AppColors.primary, child: AppShell(locale: locale, child: Column(children: [
    _Hero(locale: locale),
    _CategorySection(locale: locale),
    _Section(title: h('steps_title'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      for (var i = 1; i <= 4; i++) Padding(padding: const EdgeInsets.only(bottom: 20), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: CircleAvatar(backgroundColor: AppColors.primary, foregroundColor: Colors.white, child: Text('$i'))),
        const SizedBox(width: 16), Expanded(child: _TextPair(title: h('step$i'), body: h('step${i}_body'))),
      ])),
      TextButton(onPressed: () => context.go('/$locale/comment-ca-marche'), child: Text(h('details'))),
    ])),
    _TrustSection(locale: locale),
    _CoverageAndFaq(locale: locale),
    _DriverSection(locale: locale),
    _FinalCta(locale: locale),
  ])));
}

class _Hero extends StatelessWidget {
  final String locale;
  const _Hero({required this.locale});
  @override
  Widget build(BuildContext context) {
    String h(String key) => HomeCopy.text(key, locale);
    final wide = MediaQuery.sizeOf(context).width >= AppBreakpoints.desktop;
    return Container(key: const Key('home-hero'), width: double.infinity,
      decoration: const BoxDecoration(gradient: AppColors.heroGradient),
      child: ResponsivePadding(child: Padding(padding: EdgeInsets.symmetric(vertical: wide ? 64 : 32),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 820), child: Column(children: [
          Text(h('eyebrow'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 16),
          Semantics(header: true, child: Text(h('title'), textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: wide ? 50 : 32, height: 1.15, fontWeight: FontWeight.w800, letterSpacing: -0.6))),
          const SizedBox(height: 18),
          Text(h('intro'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.55)),
          const SizedBox(height: 24),
          _QuoteButton(locale: locale, light: true, buttonKey: const Key('home-primary-quote')),
          const SizedBox(height: 10),
          Text(h('quote_note'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4)),
          TextButton(style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => context.go('/$locale/devenir-chauffeur'), child: Text(h('driver_link'), textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Text(h('pilot'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 12, height: 1.4)),
        ])))),
      ));
  }
}

class _QuoteButton extends StatelessWidget {
  final String locale;
  final bool light;
  final Key? buttonKey;
  const _QuoteButton({required this.locale, this.light = false, this.buttonKey});
  @override
  Widget build(BuildContext context) => ElevatedButton(
    key: buttonKey, onPressed: () => context.go(DeliveryRequestIntent.path(locale)),
    style: ElevatedButton.styleFrom(minimumSize: const Size(0, 52),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      backgroundColor: light ? Colors.white : AppColors.primary,
      foregroundColor: light ? AppColors.primary : Colors.white),
    child: Text(HomeCopy.text('quote', locale), textAlign: TextAlign.center),
  );
}

class _CategorySection extends StatelessWidget {
  final String locale;
  const _CategorySection({required this.locale});
  static const items = <(String, IconData)>[
    ('cat_furniture', Icons.chair_outlined), ('cat_appliances', Icons.kitchen_outlined),
    ('cat_marketplace', Icons.shopping_bag_outlined), ('cat_building_materials', Icons.handyman_outlined),
    ('cat_tv', Icons.tv_outlined), ('cat_bbq', Icons.outdoor_grill_outlined),
  ];
  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    return _Section(title: HomeCopy.text('categories_title', locale), subtitle: HomeCopy.text('categories_body', locale),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        LayoutBuilder(builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.4;
          final columns = largeText || constraints.maxWidth < 340 ? 1 : constraints.maxWidth >= 820 ? 3 : 2;
          final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
          return Wrap(spacing: 12, runSpacing: 12, children: [for (final item in items)
            SizedBox(width: width, child: Material(color: Theme.of(context).cardTheme.color,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: AppColors.border)),
              clipBehavior: Clip.antiAlias, child: InkWell(key: Key('home-category-${item.$1}'),
                onTap: () => context.go(DeliveryRequestIntent.path(locale, category: item.$1)),
                child: Semantics(button: true, label: t(item.$1), hint: HomeCopy.text('category_hint', locale),
                  excludeSemantics: true, child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
                    Icon(item.$2, color: Theme.of(context).colorScheme.onSurface, size: 30), const SizedBox(height: 12),
                    Text(t(item.$1), textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]))),
              ),
            )),
          ]);
        }),
        const SizedBox(height: 18), Text(HomeCopy.text('item_note', locale), style: const TextStyle(height: 1.5)),
      ]));
  }
}

class _TextPair extends StatelessWidget {
  final String title, body;
  const _TextPair({required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)), const SizedBox(height: 8), Text(body, style: const TextStyle(height: 1.5)),
  ]);
}

class _TrustSection extends StatelessWidget {
  final String locale;
  const _TrustSection({required this.locale});
  @override
  Widget build(BuildContext context) => _Section(title: HomeCopy.text('trust_title', locale), child: LayoutBuilder(builder: (context, constraints) {
    final columns = constraints.maxWidth >= 900 && MediaQuery.textScalerOf(context).scale(1) < 1.4 ? 3 : 1;
    final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
    return Wrap(spacing: 16, runSpacing: 16, children: [for (var i = 1; i <= 3; i++) SizedBox(width: width,
      child: Container(padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border)),
        child: _TextPair(title: HomeCopy.text('trust$i', locale), body: HomeCopy.text('trust${i}_body', locale)),
      )),
    ]);
  }));
}

class _CoverageAndFaq extends StatelessWidget {
  final String locale;
  const _CoverageAndFaq({required this.locale});
  @override
  Widget build(BuildContext context) {
    String h(String key) => HomeCopy.text(key, locale);
    final t = context.watch<LocaleProvider>().t;
    return _Section(title: h('coverage_title'), subtitle: h('coverage_body'), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(h('faq_title'), style: Theme.of(context).textTheme.titleLarge)),
      const SizedBox(height: 16),
      for (final topic in ['price', 'help', 'available', 'cancel']) ExpansionTile(key: Key('home-faq-$topic'),
        tilePadding: const EdgeInsets.symmetric(horizontal: 8), title: Text(h('faq_$topic')),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 20), expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [Text(h('faq_${topic}_body'), style: const TextStyle(height: 1.6)),
          if (topic == 'price') TextButton(onPressed: () => context.go('/$locale/tarifs'), child: Text(t('nav_pricing'))),
          if (topic == 'cancel') Wrap(children: [
            TextButton(onPressed: () => context.go('/$locale/legal/cancellation'), child: Text(t('footer_cancellation_policy'))),
            TextButton(onPressed: () => context.go('/$locale/contact'), child: Text(t('nav_contact'))),
          ]),
        ]),
      TextButton(onPressed: () => context.go('/$locale/faq'), child: Text(t('nav_faq'))),
    ]));
  }
}

class _DriverSection extends StatelessWidget {
  final String locale;
  const _DriverSection({required this.locale});
  @override
  Widget build(BuildContext context) => _Section(title: HomeCopy.text('driver_title', locale), subtitle: HomeCopy.text('driver_body', locale),
    child: OutlinedButton(onPressed: () => context.go('/$locale/devenir-chauffeur'),
      child: Text(HomeCopy.text('driver_cta', locale), textAlign: TextAlign.center)));
}

class _FinalCta extends StatelessWidget {
  final String locale;
  const _FinalCta({required this.locale});
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, color: AppColors.primary,
    child: ResponsivePadding(child: Padding(padding: const EdgeInsets.symmetric(vertical: 40), child: Column(children: [
      Semantics(header: true, child: Text(HomeCopy.text('final_title', locale), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800))),
      const SizedBox(height: 12), Text(HomeCopy.text('final_body', locale), textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.5)),
      const SizedBox(height: 22), _QuoteButton(locale: locale, light: true),
    ]))));
}

/// Natural-height sections: no fixed-height cards or nested scrolling.
class _Section extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  const _Section({required this.title, this.subtitle, required this.child});
  @override
  Widget build(BuildContext context) => ResponsivePadding(child: Padding(
    padding: EdgeInsets.symmetric(vertical: MediaQuery.sizeOf(context).width < 600 ? 28 : 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800))),
      if (subtitle != null) ...[const SizedBox(height: 12), Text(subtitle!, style: const TextStyle(height: 1.55))],
      const SizedBox(height: 24), child,
    ]),
  ));
}
