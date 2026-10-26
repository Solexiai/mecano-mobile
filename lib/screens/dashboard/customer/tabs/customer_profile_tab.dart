import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../../widgets/language_selector.dart';

/// Onglet profil client — Phase 4 : identité réelle Firebase Auth.
///
/// L'édition (nom/téléphone/ville) écrit directement sur `users/{uid}`
/// (autorisé par firestore.rules tant que `roles`/`uid`/`created_at`/
/// `is_disabled`/`email_verified` ne changent pas) — pas de Cloud Function
/// nécessaire pour ces champs déclaratifs simples.
class CustomerProfileTab extends StatefulWidget {
  const CustomerProfileTab({super.key, this.onGoToTab});

  /// Opens another tab of the customer space (1 = Activité).
  final ValueChanged<int>? onGoToTab;

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProfile());
  }

  Future<void> _loadProfile() async {
    final auth = context.read<FirebaseAuthProvider>();
    final user = auth.user;
    if (user == null) return;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data();
      _nameController.text = (data?['full_name'] as String?) ?? user.displayName ?? '';
      _phoneController.text = (data?['phone'] as String?) ?? '';
      _cityController.text = (data?['city'] as String?) ?? '';
    } catch (_) {
      _nameController.text = user.displayName ?? '';
    } finally {
      // No name yet: the form opens by itself so the customer can add it.
      if (mounted) {
        setState(() {
          _loaded = true;
          _editing = _nameController.text.trim().isEmpty;
        });
      }
    }
  }

  Future<void> _save(String uid) async {
    setState(() => _saving = true);
    final t = context.read<LocaleProvider>().t;
    final auth = context.read<FirebaseAuthProvider>();
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
      }, SetOptions(merge: true));
      // The home screen greets the customer by first name (2026-10-25).
      try {
        await auth.user?.updateDisplayName(_nameController.text.trim());
        await auth.reloadCurrentUser();
      } catch (_) {
        /* The name stays saved in the profile even if Auth is not updated. */
      }
      if (mounted) {
        setState(() => _editing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('customer_profile_update_success'))));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t('customer_profile_update_error'))));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final user = auth.user;
    final themeProvider = context.watch<ThemeProvider>();
    final t = context.watch<LocaleProvider>().t;
    final locale = context.watch<LocaleProvider>().locale;
    String tr(String fr, String en, String es) =>
        locale == 'en' ? en : (locale == 'es' ? es : fr);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }

    final name = _nameController.text.trim();
    final displayName = name.isNotEmpty ? name : (user.email ?? '');
    final phone = _phoneController.text.trim();
    Widget row({
      required Key key,
      required IconData icon,
      required String title,
      String? subtitle,
      Widget? trailing,
      VoidCallback? onTap,
    }) => ListTile(
      key: key,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right)),
      onTap: onTap,
    );

    // Compte, like the owner mockup (2026-10-25): who you are on top, then
    // short rows. Only rows that lead somewhere real are shown.
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(tr('Compte', 'Account', 'Cuenta'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            key: const ValueKey('account-header'),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: Text(
                    displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, color: AppColors.primary, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        key: const ValueKey('account-name'),
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
                      ),
                      if ((user.email ?? '').isNotEmpty && user.email != displayName)
                        Text(user.email!, style: const TextStyle(color: AppColors.textSecondary)),
                      if (phone.isNotEmpty)
                        Text(phone, style: const TextStyle(color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                  key: const ValueKey('account-edit'),
                  onPressed: () => setState(() => _editing = !_editing),
                  child: Text(_editing
                      ? tr('Fermer', 'Close', 'Cerrar')
                      : tr('Modifier', 'Edit', 'Editar')),
                ),
              ],
            ),
          ),
          if (_editing) ...[
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('account-name-field'),
              controller: _nameController,
              decoration: InputDecoration(labelText: t('auth_full_name')),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(labelText: t('auth_phone')),
            ),
            const SizedBox(height: 14),
            TextField(controller: _cityController, decoration: InputDecoration(labelText: t('customer_profile_city_label'))),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('account-save'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _saving ? null : () => _save(user.uid),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t('common_save')),
            ),
          ],
          const SizedBox(height: 20),
          Text(tr('Mon compte', 'My account', 'Mi cuenta'),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const SizedBox(height: 4),
          if (widget.onGoToTab != null)
            row(
              key: const ValueKey('account-receipts'),
              icon: Icons.receipt_long_outlined,
              title: tr('Mes livraisons et reçus', 'My deliveries and receipts', 'Mis entregas y recibos'),
              subtitle: tr('Dans Activité, touchez une livraison', 'In Activity, tap a delivery', 'En Actividad, toca una entrega'),
              onTap: () => widget.onGoToTab!(1),
            ),
          row(
            key: const ValueKey('account-notifications'),
            icon: Icons.notifications_none,
            title: tr('Notifications', 'Notifications', 'Notificaciones'),
            subtitle: tr('Les nouvelles de vos livraisons', 'News about your deliveries', 'Novedades de tus entregas'),
            onTap: () => context.go('/$locale/notifications'),
          ),
          row(
            key: const ValueKey('account-language'),
            icon: Icons.language,
            title: tr('Langue', 'Language', 'Idioma'),
            subtitle: switch (locale) { 'en' => 'English', 'es' => 'Español', _ => 'Français' },
            trailing: const LanguageSelector(compact: true),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.dark_mode_outlined),
            title: Text(t('customer_profile_dark_mode'), style: const TextStyle(fontWeight: FontWeight.w600)),
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
            activeThumbColor: AppColors.primary,
          ),
          row(
            key: const ValueKey('account-help'),
            icon: Icons.help_outline,
            title: tr('Aide et contact', 'Help and contact', 'Ayuda y contacto'),
            subtitle: tr('Questions, problème avec une livraison', 'Questions, a problem with a delivery', 'Preguntas, un problema con una entrega'),
            onTap: () => context.go('/$locale/contact'),
          ),
          row(
            key: const ValueKey('account-terms'),
            icon: Icons.description_outlined,
            title: tr('Conditions et confidentialité', 'Terms and privacy', 'Condiciones y privacidad'),
            onTap: () => context.go('/$locale/legal/terms'),
          ),
          const Divider(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
            label: Text(t('nav_logout')),
          ),
          const SizedBox(height: 8),
          // Honest path (2026-10-25): the request goes through the contact
          // form; nothing claims it was recorded automatically.
          TextButton(
            key: const ValueKey('account-delete'),
            onPressed: () => context.go('/$locale/contact'),
            child: Text(t('customer_profile_delete_account_request'), style: const TextStyle(color: AppColors.textSecondary)),
          ),
          Text(
            tr(
              'Écrivez-nous depuis la page Contact : nous supprimons votre compte et vos données.',
              'Write to us from the Contact page: we delete your account and your data.',
              'Escríbenos desde la página de contacto: eliminamos tu cuenta y tus datos.',
            ),
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _cityController.dispose();
    super.dispose();
  }
}
