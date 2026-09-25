import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../core/app_colors.dart';
import '../l10n/home_copy.dart';
import '../router/delivery_request_intent.dart';
import '../core/responsive.dart';
import '../models/enums.dart';
import '../providers/firebase_auth_provider.dart';
import '../providers/locale_provider.dart';
import 'language_selector.dart';

String _deliveryTagline(String locale) {
  switch (locale) {
    case 'en':
      return 'Large-item delivery, made local.';
    case 'es':
      return 'Entregas de artículos voluminosos, cerca de ti.';
    default:
      return 'La livraison de gros objets, près de chez vous.';
  }
}

/// Shared public-page shell: responsive header with nav + footer.
/// Phone/tablet: compact header with drawer. Desktop: full navigation.
class AppShell extends StatefulWidget {
  final String locale;
  final Widget child;
  final bool showFooter;

  const AppShell({
    super.key,
    required this.locale,
    required this.child,
    this.showFooter = true,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    _syncLocale();
  }

  @override
  void didUpdateWidget(AppShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.locale != widget.locale) _syncLocale();
  }

  void _syncLocale() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<LocaleProvider>();
      if (provider.locale != widget.locale) provider.setLocale(widget.locale);
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= AppBreakpoints.wide && MediaQuery.textScalerOf(context).scale(16) <= 18;

    return Scaffold(
      drawer: isDesktop ? null : _MobileDrawer(locale: widget.locale),
      appBar: _MovikAppBar(locale: widget.locale, isDesktop: isDesktop),
      body: SingleChildScrollView(
        key: const Key('public-scroll'),
        child: Column(
          children: [
            widget.child,
            if (widget.showFooter) _MovikFooter(locale: widget.locale),
          ],
        ),
      ),
    );
  }
}

class _MovikAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String locale;
  final bool isDesktop;

  const _MovikAppBar({required this.locale, required this.isDesktop});

  @override
  Size get preferredSize => const Size.fromHeight(72);

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final isPhone = AppBreakpoints.isPhone(MediaQuery.sizeOf(context).width);

    return AppBar(
      toolbarHeight: 72,
      titleSpacing: isDesktop ? 24 : (isPhone ? 4 : 12),
      title: Row(
        children: [
          Flexible(
            child: InkWell(
              onTap: () => context.go('/$locale'),
              child: Semantics(button: true, label: HomeCopy.text('home_link', locale), excludeSemantics: true, child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: isPhone ? 32 : 36,
                    height: isPhone ? 32 : 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.deliveryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.bolt,
                      color: Colors.white,
                      size: isPhone ? 18 : 20,
                    ),
                  ),
                  SizedBox(width: isPhone ? 8 : 10),
                  Flexible(
                    child: Text(
                      'Movi-K',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: isPhone ? 18 : 20,
                      ),
                    ),
                  ),
                ],
              )),
            ),
          ),
          if (isDesktop) const SizedBox(width: 40),
          if (isDesktop) ..._desktopNavItems(context, t),
        ],
      ),
      actions: [
        if (auth.isSignedIn) _AccountMenu(locale: locale)
        else IconButton(key: const Key('public-sign-in'), tooltip: t('nav_sign_in'),
          onPressed: () => context.go('/$locale/connexion'), icon: const Icon(Icons.person_outline)),
        LanguageSelector(compact: !isDesktop),
        if (isDesktop) Padding(padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ElevatedButton(onPressed: () => context.go(DeliveryRequestIntent.path(locale)),
            child: Text(HomeCopy.text('quote', locale)))),
        if (!isDesktop) const SizedBox(width: 4),
      ],
    );
  }

  List<Widget> _desktopNavItems(
    BuildContext context,
    String Function(String) t,
  ) {
    Widget item(String label, String path) => TextButton(
      onPressed: () => context.go(path),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
    );

    return [
      item(t('nav_delivery'), '/$locale/livraison'),
      item(t('nav_how_it_works'), '/$locale/comment-ca-marche'),
      item(t('nav_pricing'), '/$locale/tarifs'),
      item(t('nav_safety'), '/$locale/securite'),
      item(t('nav_faq'), '/$locale/faq'),
    ];
  }
}

class _AccountMenu extends StatelessWidget {
  final String locale;

  const _AccountMenu({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();
    final canSeeDriverSpace = auth.hasRole(PlatformRole.driver);

    return PopupMenuButton<String>(
      key: const Key('public-account-menu'),
      tooltip: HomeCopy.text('account', locale),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'dashboard') context.go('/$locale/tableau-de-bord');
        if (value == 'provider') {
          context.go('/$locale/fournisseur/tableau-de-bord');
        }
        if (value == 'admin') context.go('/$locale/admin');
        if (value == 'logout') auth.signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'dashboard', child: Text(t('nav_dashboard'))),
        if (canSeeDriverSpace)
          PopupMenuItem(
            value: 'provider',
            child: Text(t('nav_provider_space')),
          ),
        if (auth.isAnalystOrAbove)
          PopupMenuItem(value: 'admin', child: Text(t('nav_admin'))),
        PopupMenuItem(value: 'logout', child: Text(t('nav_logout'))),
      ],
      icon: const Icon(Icons.account_circle_outlined),
    );
  }
}

class _MobileDrawer extends StatelessWidget {
  final String locale;

  const _MobileDrawer({required this.locale});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    final auth = context.watch<FirebaseAuthProvider>();

    Widget item(IconData icon, String label, VoidCallback onTap) => ListTile(
      minVerticalPadding: 12,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );

    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: const BoxDecoration(gradient: AppColors.heroGradient),
              child: const Text(
                'Movi-K',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            item(Icons.request_quote_outlined, HomeCopy.text('quote', locale),
              () => context.go(DeliveryRequestIntent.path(locale))),
            item(
              Icons.home_outlined,
              t('nav_home'),
              () => context.go('/$locale'),
            ),
            item(
              Icons.local_shipping_outlined,
              t('nav_delivery'),
              () => context.go('/$locale/livraison'),
            ),
            item(
              Icons.directions_car_outlined,
              t('nav_become_driver'),
              () => context.go('/$locale/devenir-chauffeur'),
            ),
            item(
              Icons.info_outline,
              t('nav_how_it_works'),
              () => context.go('/$locale/comment-ca-marche'),
            ),
            item(
              Icons.payments_outlined,
              t('nav_pricing'),
              () => context.go('/$locale/tarifs'),
            ),
            item(
              Icons.shield_outlined,
              t('nav_safety'),
              () => context.go('/$locale/securite'),
            ),
            item(
              Icons.help_outline,
              t('nav_faq'),
              () => context.go('/$locale/faq'),
            ),
            item(
              Icons.mail_outline,
              t('nav_contact'),
              () => context.go('/$locale/contact'),
            ),
            if (auth.isAnalystOrAbove) item(
              Icons.admin_panel_settings_outlined,
              t('nav_admin'),
              () => context.go('/$locale/admin'),
            ),
            if (auth.isSignedIn && auth.hasRole(PlatformRole.driver)) item(
              Icons.local_shipping_outlined, t('nav_provider_space'),
              () => context.go('/$locale/fournisseur/tableau-de-bord')),
            const Divider(),
            if (auth.isSignedIn) ...[
              item(
                Icons.dashboard_outlined,
                t('nav_dashboard'),
                () => context.go('/$locale/tableau-de-bord'),
              ),
              item(Icons.logout, t('nav_logout'), () => auth.signOut()),
            ] else
              item(
                Icons.login,
                t('nav_sign_in'),
                () => context.go('/$locale/connexion'),
              ),
          ],
        ),
      ),
    );
  }
}

class _MovikFooter extends StatelessWidget {
  final String locale;
  const _MovikFooter({required this.locale});
  @override
  Widget build(BuildContext context) {
    final t = context.watch<LocaleProvider>().t;
    String h(String key) => HomeCopy.text(key, locale);
    Widget link(String label, String path) => InkWell(onTap: () => context.go(path),
      child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(label, style: const TextStyle(color: AppColors.textOnDark)))));
    Widget group(String title, List<Widget> links) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Semantics(header: true, child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16))),
      const SizedBox(height: 8), ...links,
    ]);
    final groups = [
      group(h('footer_service'), [link(h('quote'), DeliveryRequestIntent.path(locale)), link(t('nav_pricing'), '/$locale/tarifs'), link(t('nav_how_it_works'), '/$locale/comment-ca-marche')]),
      group(h('footer_drivers'), [link(t('nav_become_driver'), '/$locale/devenir-chauffeur'), link(t('nav_sign_in'), '/$locale/connexion')]),
      group(h('footer_help'), [link(t('nav_faq'), '/$locale/faq'), link(t('nav_contact'), '/$locale/contact'), link(t('nav_safety'), '/$locale/securite'), link(t('nav_about'), '/$locale/a-propos')]),
      group(t('footer_legal_column_title'), [link(t('footer_privacy'), '/$locale/legal/privacy'), link(t('footer_terms'), '/$locale/legal/terms'), link(t('footer_cancellation_policy'), '/$locale/legal/cancellation')]),
    ];
    return Container(color: AppColors.primaryDark, width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: AppBreakpoints.pageHorizontalPadding(MediaQuery.sizeOf(context).width), vertical: 32),
      child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: AppBreakpoints.contentMaxWidth),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Movi-K', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8), Text(_deliveryTagline(locale), style: const TextStyle(color: AppColors.textOnDark)),
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(16) / 16;
            final count = constraints.maxWidth >= 960 && scale <= 1.3 ? 4 : constraints.maxWidth >= 600 && scale <= 1.3 ? 2 : 1;
            final width = (constraints.maxWidth - 24 * (count - 1)) / count;
            return Wrap(spacing: 24, runSpacing: 28, children: [for (final g in groups) SizedBox(width: width, child: g)]);
          }),
          const SizedBox(height: 24), const Divider(color: AppColors.borderDark),
          const SizedBox(height: 16), Text("© ${DateTime.now().year} Movi-K. ${t('footer_rights')}", style: const TextStyle(color: AppColors.textOnDark, fontSize: 13)),
        ]),
      )),
    );
  }
}
