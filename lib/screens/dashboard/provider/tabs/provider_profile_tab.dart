import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../widgets/coming_soon_badge.dart';
import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../models/enums.dart';

class ProviderProfileTab extends StatelessWidget {
  const ProviderProfileTab({super.key});

  String _statusLabel(DriverStatus? status) {
    switch (status) {
      case DriverStatus.approved:
        return 'Chauffeur approuvé';
      case DriverStatus.pendingReview:
        return 'En attente de vérification';
      case DriverStatus.documentsRequired:
        return 'Documents requis';
      case DriverStatus.rejected:
        return 'Dossier refusé';
      case DriverStatus.suspended:
        return 'Compte suspendu';
      case DriverStatus.inactive:
        return 'Compte inactif';
      case DriverStatus.registrationIncomplete:
      case null:
        return 'Inscription incomplète';
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final user = auth.user;
    if (user == null) return const Center(child: CircularProgressIndicator());
    final displayName = user.displayName ?? user.email ?? '';

    return StreamBuilder<DriverProfileV2?>(
      stream: BackendLocator.driverRepository.watchDriverProfile(user.uid),
      builder: (context, snap) {
        final profile = snap.data;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mon profil fournisseur', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      child: Text(
                        displayName.isNotEmpty ? displayName.substring(0, 1).toUpperCase() : '?',
                        style: const TextStyle(fontSize: 28, color: AppColors.primary, fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(displayName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: (profile?.status == DriverStatus.approved ? AppColors.success : AppColors.warning)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _statusLabel(profile?.status),
                        style: TextStyle(
                          color: profile?.status == DriverStatus.approved ? AppColors.success : AppColors.warning,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              _SectionCard(
                title: 'Mes services',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: const Text('Véhicules acceptés'),
                    trailing: Text(
                      (profile?.acceptedVehicleCategories.isNotEmpty ?? false)
                          ? profile!.acceptedVehicleCategories.map((c) => c.name).join(', ')
                          : '—',
                    ),
                  ),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.attach_money),
                    title: Text('Tarification'),
                    trailing: ComingSoonBadge(small: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Documents',
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: const Text('Pièce d\'identité'),
                    trailing: Icon(
                      profile?.status == DriverStatus.approved ? Icons.check_circle : Icons.hourglass_top,
                      color: profile?.status == DriverStatus.approved ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: const Text('Assurance'),
                    trailing: Icon(
                      profile?.status == DriverStatus.approved ? Icons.check_circle : Icons.hourglass_top,
                      color: profile?.status == DriverStatus.approved ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Avis reçus',
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('Aucun avis pour le moment.', style: TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(children: [
                const Expanded(child: Text('Support technique', style: TextStyle(fontWeight: FontWeight.w700))),
                const ComingSoonBadge(small: true),
              ]),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _SectionCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}
