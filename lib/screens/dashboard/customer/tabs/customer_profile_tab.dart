import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/theme_provider.dart';
import '../../../../widgets/coming_soon_badge.dart';

class CustomerProfileTab extends StatefulWidget {
  const CustomerProfileTab({super.key});

  @override
  State<CustomerProfileTab> createState() => _CustomerProfileTabState();
}

class _CustomerProfileTabState extends State<CustomerProfileTab> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().currentUser!;
    _nameController = TextEditingController(text: user.fullName);
    _phoneController = TextEditingController(text: user.phone);
    _cityController = TextEditingController(text: user.city);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser!;
    final themeProvider = context.watch<ThemeProvider>();

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
              child: Text(user.fullName.isNotEmpty ? user.fullName.substring(0, 1).toUpperCase() : '?', style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(height: 24),
          TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Nom complet')),
          const SizedBox(height: 14),
          TextField(enabled: false, controller: TextEditingController(text: user.email), decoration: const InputDecoration(labelText: 'Adresse courriel')),
          const SizedBox(height: 14),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Téléphone')),
          const SizedBox(height: 14),
          TextField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ville')),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                auth.updateProfile(fullName: _nameController.text.trim(), phone: _phoneController.text.trim(), city: _cityController.text.trim());
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil mis à jour')));
              },
              child: const Text('Enregistrer'),
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
            onPressed: () => auth.logout(),
            icon: const Icon(Icons.logout),
            label: const Text('Se déconnecter'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Demande de suppression de compte enregistrée (démo).')));
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
