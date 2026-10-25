import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../providers/theme_provider.dart';
import 'package:go_router/go_router.dart';

/// Onglet profil client — Phase 4 : identité réelle Firebase Auth.
///
/// L'édition (nom/téléphone/ville) écrit directement sur `users/{uid}`
/// (autorisé par firestore.rules tant que `roles`/`uid`/`created_at`/
/// `is_disabled`/`email_verified` ne changent pas) — pas de Cloud Function
/// nécessaire pour ces champs déclaratifs simples.
class CustomerProfileTab extends StatefulWidget {
  const CustomerProfileTab({super.key});

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _cityController = TextEditingController();
  bool _loaded = false;
  bool _saving = false;

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
      if (mounted) setState(() => _loaded = true);
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

    final displayName = _nameController.text.isNotEmpty ? _nameController.text : (user.email ?? '');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tr('Compte', 'Account', 'Cuenta'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: Text(
                displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w800),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextField(controller: _nameController, decoration: InputDecoration(labelText: t('auth_full_name'))),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            controller: TextEditingController(text: user.email ?? ''),
            decoration: InputDecoration(labelText: t('auth_email')),
          ),
          const SizedBox(height: 14),
          TextField(controller: _phoneController, decoration: InputDecoration(labelText: t('auth_phone'))),
          const SizedBox(height: 14),
          TextField(controller: _cityController, decoration: InputDecoration(labelText: t('customer_profile_city_label'))),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(user.uid),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(t('common_save')),
            ),
          ),
          const Divider(height: 40),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t('customer_profile_dark_mode')),
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
            activeThumbColor: AppColors.primary,
          ),
          const Divider(height: 20),
          ListTile(
            key: const ValueKey('account-help'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.help_outline),
            title: Text(tr('Aide et contact', 'Help and contact', 'Ayuda y contacto')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go('/$locale/contact'),
          ),
          ListTile(
            key: const ValueKey('account-terms'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.description_outlined),
            title: Text(tr('Conditions et confidentialité', 'Terms and privacy', 'Condiciones y privacidad')),
            trailing: const Icon(Icons.chevron_right),
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
