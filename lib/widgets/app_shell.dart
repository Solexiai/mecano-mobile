import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../core/app_colors.dart';
import '../providers/locale_provider.dart';
import '../providers/firebase_auth_provider.dart';
import '../models/enums.dart';
import 'language_selector.dart';

/// Shared public-page shell: responsive header with nav + footer.
/// Mobile: compact header with hamburger drawer. Desktop: full nav bar.
///
/// Also keeps [LocaleProvider] in sync with the /fr|/en|/es URL segment,
/// so a direct link, bookmark, or browser refresh on a locale-prefixed URL
/// always renders the matching language (not just whatever locale was
/// last saved in local storage).
class AppShell extends StatefulWidget {
  final String locale;
  final Widget child;
  final bool showFooter;

  const AppShell({super.key, required this.locale, required this.child, this.showFooter = true});

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
    final isDesktop = MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      drawer: isDesktop ? null : _MobileDrawer(locale: widget.locale),
      appBar: _MovikAppBar(locale: widget.locale, isDesktop: isDesktop),
      body: SingleChildScrollView(
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

    return AppBar(
      toolbarHeight: 72,
      titleSpacing: isDesktop ? 24 : 0,
      title: Row(
        children: [
          // BUG-AB-09-02 (P2, AB-9) — le logo/marque était un enfant direct
          // (non flexible) de ce Row de titre. Sur mobile (`isDesktop ==
          // false`), c'est le SEUL enfant du Row : sans `Flexible`, le Row
          // conserve la taille intrinsèque du `GestureDetector`, qui grandit
          // avec `textScale` (accessibilité) jusqu'à dépasser la largeur
          // disponible de la zone de titre sur un téléphone 320 px — d'où un
          // `RenderFlex overflowed` visible seulement à `textScale >= 1.5`.
          // Corrigé en rendant le bloc logo+texte flexible, et en permettant
          // au texte "Movi-k" de s'ellipser en dernier recours, sans jamais
          // changer la mise en page desktop (>=900px, non affectée). Test de
          // régression permanent :
          // `test/accessibility/critical_accessibility_test.dart`
          // (groupe "AB-9 — AppShell").
          Flexible(
            child: GestureDetector(
              onTap: () => context.go('/$locale'),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      gradient: AppColors.deliveryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bolt, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Movi-k',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isDesktop) const SizedBox(width: 40),
          if (isDesktop) ..._desktopNavItems(context, t),
        ],
      ),
      actions: [
        if (isDesktop) const LanguageSelector(),
        const SizedBox(width: 8),
        if (isDesktop)
          if (auth.isSignedIn)
            _AccountMenu(locale: locale)
          else ...[
            OutlinedButton(
              onPressed: () => context.go('/$locale/connexion'),
              child: Text(t('nav_sign_in')),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: () => context.go('/$locale/connexion'),
              child: Text(t('nav_get_started')),
            ),
            const SizedBox(width: 8),
          ],
        if (!isDesktop) const LanguageSelector(compact: true),
        if (!isDesktop) const SizedBox(width: 8),
      ],
    );
  }

  List<Widget> _desktopNavItems(BuildContext context, String Function(String) t) {
    Widget item(String label, String path) => TextButton(
          onPressed: () => context.go(path),
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        );
    return [
      item(t('nav_delivery'), '/$locale/livraison'),
      item(t('nav_mechanic'), '/$locale/mecanique-mobile'),
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
    final displayName = auth.user?.displayName ?? auth.user?.email ?? '';
    final isCustomerOnly = auth.roles.length == 1 && auth.roles.first == PlatformRole.customer;
    return PopupMenuButton<String>(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (value) {
        if (value == 'dashboard') context.go('/$locale/tableau-de-bord');
        if (value == 'provider') context.go('/$locale/fournisseur/tableau-de-bord');
        if (value == 'admin') context.go('/$locale/admin');
        if (value == 'logout') auth.signOut();
      },
      itemBuilder: (context) => [
        PopupMenuItem(value: 'dashboard', child: Text(t('nav_dashboard'))),
        if (!isCustomerOnly) PopupMenuItem(value: 'provider', child: Text(t('nav_provider_space'))),
        if (auth.isAnalystOrAbove) PopupMenuItem(value: 'admin', child: Text(t('nav_admin'))),
        PopupMenuItem(value: 'logout', child: Text(t('nav_logout'))),
      ],
      child: CircleAvatar(
        radius: 18,
        backgroundColor: AppColors.primary.withValues(alpha: 0.1),
        child: Text(
          (displayName.isNotEmpty ? displayName.substring(0, 1) : '?').toUpperCase(),
          style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
        ),
      ),
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
              child: const Text('Movi-k', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800)),
            ),
            item(Icons.home_outlined, t('nav_home'), () => context.go('/$locale')),
            item(Icons.local_shipping_outlined, t('nav_delivery'), () => context.go('/$locale/livraison')),
            item(Icons.build_outlined, t('nav_mechanic'), () => context.go('/$locale/mecanique-mobile')),
            item(Icons.directions_car_outlined, t('nav_become_driver'), () => context.go('/$locale/devenir-chauffeur')),
            item(Icons.handyman_outlined, t('nav_become_mechanic'), () => context.go('/$locale/devenir-mecanicien')),
            item(Icons.info_outline, t('nav_how_it_works'), () => context.go('/$locale/comment-ca-marche')),
            item(Icons.payments_outlined, t('nav_pricing'), () => context.go('/$locale/tarifs')),
            item(Icons.shield_outlined, t('nav_safety'), () => context.go('/$locale/securite')),
            item(Icons.help_outline, t('nav_faq'), () => context.go('/$locale/faq')),
            item(Icons.mail_outline, t('nav_contact'), () => context.go('/$locale/contact')),
            const Divider(),
            if (auth.isSignedIn) ...[
              item(Icons.dashboard_outlined, t('nav_dashboard'), () => context.go('/$locale/tableau-de-bord')),
              item(Icons.logout, t('nav_logout'), () => auth.signOut()),
            ] else
              item(Icons.login, t('nav_sign_in'), () => context.go('/$locale/connexion')),
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
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    Widget link(String label, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Text(label, style: const TextStyle(color: AppColors.textOnDarkSecondary)),
          ),
        );

    // Retourne le contenu "nu" de la colonne (sans Expanded) : c'est
    // l'appelant qui décide comment l'envelopper selon le layout
    // (Expanded direct dans le Row desktop ; Padding simple dans la Column
    // mobile — Expanded exige un ancêtre Flex DIRECT, donc ne doit jamais
    // être enveloppé par un Padding).
    Widget column(String title, List<Widget> links) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 10),
            ...links,
          ],
        );

    final columns = [
      column(t('nav_delivery'), [
        link(t('home_card_delivery_cta'), () => context.go('/$locale/livraison')),
        link(t('nav_become_driver'), () => context.go('/$locale/devenir-chauffeur')),
      ]),
      column(t('nav_mechanic'), [
        link(t('home_card_mechanic_cta'), () => context.go('/$locale/mecanique-mobile')),
        link(t('nav_become_mechanic'), () => context.go('/$locale/devenir-mecanicien')),
      ]),
      column('Movi-k', [
        link(t('nav_about'), () => context.go('/$locale/a-propos')),
        link(t('nav_contact'), () => context.go('/$locale/contact')),
        link(t('nav_faq'), () => context.go('/$locale/faq')),
        link(t('nav_safety'), () => context.go('/$locale/securite')),
      ]),
      column(t('footer_legal_column_title'), [
        link(t('footer_privacy'), () => context.go('/$locale/legal/privacy')),
        link(t('footer_terms'), () => context.go('/$locale/legal/terms')),
        link(t('footer_cancellation_policy'), () => context.go('/$locale/legal/cancellation')),
      ]),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      color: AppColors.primaryDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(gradient: AppColors.deliveryGradient, borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.bolt, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Text('Movi-k', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
            ],
          ),
          const SizedBox(height: 8),
          Text(t('tagline'), style: const TextStyle(color: AppColors.textOnDarkSecondary)),
          const SizedBox(height: 28),
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns.map((c) => Expanded(child: c)).toList(),
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: columns
                  .map((c) => Padding(padding: const EdgeInsets.only(bottom: 20), child: c))
                  .toList(),
            ),
          const SizedBox(height: 24),
          const Divider(color: AppColors.borderDark),
          const SizedBox(height: 16),
          Text('© ${DateTime.now().year} Movi-k. ${t('footer_rights')}',
              style: const TextStyle(color: AppColors.textOnDarkSecondary, fontSize: 13)),
        ],
      ),
    );
  }
}
