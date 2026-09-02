import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import '../../../../widgets/coming_soon_badge.dart';
import '../../../../backend/backend_locator.dart';
import '../../../../backend/models/driver_profile_v2.dart';
import '../../../../models/enums.dart';
import 'provider_stripe_connect_section.dart';

class ProviderProfileTab extends StatelessWidget {
  const ProviderProfileTab({super.key});

  // Réutilise les clés i18n `driver_status_*` déjà existantes et complètes
  // FR/EN/ES (voir app_strings.dart) au lieu de dupliquer des libellés en
  // dur (Bloc K, gap K-3) — même signification sémantique exacte.
  String _statusLabel(String Function(String) t, DriverStatus? status) {
    switch (status) {
      case DriverStatus.approved:
        return t('driver_status_approved');
      case DriverStatus.pendingReview:
        return t('driver_status_pending_review');
      case DriverStatus.documentsRequired:
        return t('driver_status_documents_required');
      case DriverStatus.rejected:
        return t('driver_status_rejected');
      case DriverStatus.suspended:
        return t('driver_status_suspended');
      case DriverStatus.inactive:
        return t('driver_status_inactive');
      case DriverStatus.registrationIncomplete:
      case null:
        return t('driver_status_registration_incomplete');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<FirebaseAuthProvider>();
    final user = auth.user;
    final t = context.watch<LocaleProvider>().t;
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
              Text(t('provider_profile_title'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
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
                        _statusLabel(t, profile?.status),
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
                title: t('provider_profile_my_services'),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.local_shipping_outlined),
                    title: Text(t('provider_profile_accepted_vehicles')),
                    trailing: Text(
                      (profile?.acceptedVehicleCategories.isNotEmpty ?? false)
                          ? profile!.acceptedVehicleCategories.map((c) => c.name).join(', ')
                          : '—',
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.attach_money),
                    title: Text(t('provider_profile_pricing')),
                    trailing: const ComingSoonBadge(small: true),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: t('provider_profile_documents'),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.badge_outlined),
                    title: Text(t('provider_profile_id_document')),
                    trailing: Icon(
                      profile?.status == DriverStatus.approved ? Icons.check_circle : Icons.hourglass_top,
                      color: profile?.status == DriverStatus.approved ? AppColors.success : AppColors.warning,
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.description_outlined),
                    title: Text(t('provider_profile_insurance')),
                    trailing: Icon(
                      profile?.status == DriverStatus.approved ? Icons.check_circle : Icons.hourglass_top,
                      color: profile?.status == DriverStatus.approved ? AppColors.success : AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Bloc 8B (PRIORITÉ 1, Connect Onboarding Flutter) —
              // configuration paiement/payout : seul écran d'entrée réel
              // vers Stripe Connect (voir provider_stripe_connect_section.dart
              // pour la justification complète du gap corrigé et du flow).
              // Affiché uniquement pour un chauffeur déjà approuvé : un
              // chauffeur en attente de revue ne peut pas encore recevoir
              // de missions, donc pas encore de versement à configurer, et
              // afficher ce CTA prématurément créerait une confusion inutile.
              if (profile?.status == DriverStatus.approved) ...[
                ProviderStripeConnectSection(profile: profile, t: t),
                const SizedBox(height: 20),
              ],
              _SectionCard(
                title: t('provider_profile_reviews_received'),
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(t('provider_profile_no_reviews_yet'), style: const TextStyle(color: AppColors.textSecondary)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text(t('provider_profile_support'), style: const TextStyle(fontWeight: FontWeight.w700))),
                const ComingSoonBadge(small: true),
              ]),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error, side: const BorderSide(color: AppColors.error)),
                onPressed: () => auth.signOut(),
                icon: const Icon(Icons.logout),
                label: Text(t('nav_logout')),
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
