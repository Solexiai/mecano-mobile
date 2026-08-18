import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../widgets/coming_soon_badge.dart';

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
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'city': _cityController.text.trim(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Échec de la mise à jour du profil.')));
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
          const Text('Mon profil', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom complet')),
          const SizedBox(height: 14),
          TextField(
            enabled: false,
            controller: TextEditingController(text: user.email ?? ''),
            decoration: const InputDecoration(labelText: 'Adresse courriel'),
          ),
          const SizedBox(height: 14),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Téléphone')),
          const SizedBox(height: 14),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ville')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : () => _save(user.uid),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Enregistrer'),
            ),
          ),
          const Divider(height: 40),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mode sombre'),
            value: themeProvider.isDark,
            onChanged: (_) => themeProvider.toggle(),
            activeThumbColor: AppColors.primary,
          ),
          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.place_outlined),
            title: const Text('Adresses enregistrées'),
            trailing: const ComingSoonBadge(small: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.favorite_border),
            title: const Text('Fournisseurs favoris'),
            trailing: const ComingSoonBadge(small: true),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Préférences de notification'),
            trailing: const ComingSoonBadge(small: true),
          ),
          const Divider(height: 20),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
            onPressed: () => auth.signOut(),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('Demande de suppression de compte enregistrée.')));
            },
            child: const Text('Demander la suppression de mon compte', style: TextStyle(color: AppColors.textSecondary)),
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
