import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';

class AdminUserDetailScreen extends StatefulWidget {
  const AdminUserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  State<AdminUserDetailScreen> createState() => _AdminUserDetailScreenState();
}

class _AdminUserDetailScreenState extends State<AdminUserDetailScreen> {
  bool _syncing = false;

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final fr = locale == 'fr';
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Compte utilisateur' : 'User account')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .snapshots(),
        builder: (context, userSnap) {
          if (!userSnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final user = userSnap.data!.data() ?? const <String, dynamic>{};
          final roles = _roles(user);
          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('driver_profiles')
                .doc(widget.userId)
                .snapshots(),
            builder: (context, driverSnap) {
              final hasDriverProfile = driverSnap.data?.exists == true;
              final name = (user['full_name'] ?? '').toString();
              final email = (user['email'] ?? '').toString();
              return ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
                      ),
                      title: Text(
                        name.isEmpty
                            ? (fr ? 'Nom non renseigné' : 'Name missing')
                            : name,
                      ),
                      subtitle: Text(email.isEmpty ? widget.userId : email),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    fr ? 'Rôles du compte' : 'Account roles',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: roles.map((r) => Chip(label: Text(r))).toList(),
                  ),
                  const SizedBox(height: 20),
                  // SEC-02 (2026-10-27) : compte de test interne. Le serveur
                  // lit le claim `internal_tester` ; `users.internal_tester`
                  // n'est qu'un miroir d'affichage écrit par setUserRole.
                  Card(
                    child: SwitchListTile(
                      secondary: const Icon(Icons.science_outlined),
                      title: Text(
                        fr ? 'Compte de test interne' : 'Internal test account',
                      ),
                      subtitle: Text(
                        fr
                            ? 'Peut créer des livraisons de test sans paiement. Réservé aux comptes de Movi-K.'
                            : 'Can create test deliveries without payment. Movi-K accounts only.',
                      ),
                      value: user['internal_tester'] == true,
                      onChanged: _syncing
                          ? null
                          : (value) => _setInternalTester(roles, value, fr),
                    ),
                  ),
                  // ADM-15 (2026-10-28) : rôle de personnel (analyste, admin,
                  // super-admin), réservé au super-admin — plus besoin du
                  // script bootstrap_super_admins.js pour nommer un admin.
                  if (context.watch<FirebaseAuthProvider>().isSuperAdmin) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.admin_panel_settings_outlined),
                        title: Text(fr ? 'Rôle de personnel' : 'Staff role'),
                        subtitle: Text(
                          fr
                              ? 'Analyste : consultation seulement. Admin : opérations et finances. Super-admin : tout, y compris les rôles.'
                              : 'Analyst: read-only. Admin: operations and finance. Super admin: everything, including roles.',
                        ),
                        trailing: DropdownButton<String>(
                          key: const ValueKey('staff-role'),
                          value: _staffRole(roles),
                          onChanged: _syncing
                              ? null
                              : (value) => _setStaffRole(roles, value ?? 'none', fr),
                          items: [
                            DropdownMenuItem(value: 'none', child: Text(fr ? 'Aucun' : 'None')),
                            DropdownMenuItem(value: 'analyst', child: Text(fr ? 'Analyste' : 'Analyst')),
                            const DropdownMenuItem(value: 'admin', child: Text('Admin')),
                            DropdownMenuItem(value: 'super_admin', child: Text(fr ? 'Super-admin' : 'Super admin')),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Card(
                    child: ListTile(
                      leading: Icon(
                        hasDriverProfile
                            ? Icons.local_shipping_outlined
                            : Icons.person_outline,
                        color: hasDriverProfile
                            ? AppColors.success
                            : AppColors.textSecondary,
                      ),
                      title: Text(
                        hasDriverProfile
                            ? (fr
                                  ? 'Dossier chauffeur relié'
                                  : 'Linked driver profile')
                            : (fr
                                  ? 'Aucun dossier chauffeur'
                                  : 'No driver profile'),
                      ),
                      subtitle: Text(
                        fr
                            ? 'La liaison est vérifiée avec le même identifiant Firebase.'
                            : 'The link is verified using the same Firebase ID.',
                      ),
                      trailing: hasDriverProfile
                          ? const Icon(Icons.chevron_right)
                          : null,
                      onTap: hasDriverProfile
                          ? () => context.push(
                              '/$locale/admin/chauffeurs/${widget.userId}',
                            )
                          : null,
                    ),
                  ),
                  if (hasDriverProfile && !roles.contains('driver')) ...[
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _syncing
                          ? null
                          : () => _syncRoles(roles, fr, locale),
                      icon: _syncing
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.merge_type),
                      label: Text(
                        fr
                            ? 'Réunir les rôles client et chauffeur'
                            : 'Combine customer and driver roles',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      fr
                          ? 'Cette action ne fusionne pas deux personnes : elle synchronise les rôles du même compte.'
                          : 'This does not merge two people; it synchronizes roles on the same account.',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _syncRoles(
    List<String> currentRoles,
    bool fr,
    String locale,
  ) async {
    setState(() => _syncing = true);
    final roles = <String>{'customer', ...currentRoles, 'driver'}.toList();
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('setUserRole')
          .call({'targetUid': widget.userId, 'roles': roles});
      final payload = result.data;
      final resolvedUid = payload is Map
          ? payload['targetUid']?.toString()
          : null;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fr
                ? 'Rôles client et chauffeur synchronisés.'
                : 'Customer and driver roles synchronized.',
          ),
        ),
      );
      if (resolvedUid != null && resolvedUid != widget.userId && mounted) {
        context.go('/$locale/admin/utilisateurs/$resolvedUid');
      }
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                (fr ? 'Synchronisation impossible.' : 'Unable to synchronize.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _setInternalTester(
    List<String> currentRoles,
    bool value,
    bool fr,
  ) async {
    setState(() => _syncing = true);
    final roles = currentRoles.isEmpty ? <String>['customer'] : currentRoles;
    try {
      await FirebaseFunctions.instance.httpsCallable('setUserRole').call({
        'targetUid': widget.userId,
        'roles': roles,
        'internalTester': value,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? (fr
                      ? 'Compte marqué comme test interne. La personne doit se reconnecter.'
                      : 'Account marked as internal test. The person must sign in again.')
                : (fr
                      ? 'Statut de test interne retiré. La personne doit se reconnecter.'
                      : 'Internal test status removed. The person must sign in again.'),
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                (fr ? 'Modification impossible.' : 'Unable to update.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  static const _staffRoles = ['super_admin', 'admin', 'analyst'];

  /// Rôle de personnel le plus élevé du compte (`none` s'il n'en a pas).
  static String _staffRole(List<String> roles) =>
      _staffRoles.firstWhere(roles.contains, orElse: () => 'none');

  Future<void> _setStaffRole(List<String> currentRoles, String staffRole, bool fr) async {
    if (_staffRole(currentRoles) == staffRole) return;
    final roleLabel = staffRole == 'none' ? (fr ? 'aucun rôle de personnel' : 'no staff role') : staffRole;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(fr ? 'Changer le rôle de personnel' : 'Change staff role'),
        content: Text(
          fr
              ? 'Ce compte aura : $roleLabel. La personne doit se reconnecter pour que le changement s’applique.'
              : 'This account will have: $roleLabel. The person must sign in again for the change to apply.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(fr ? 'Annuler' : 'Cancel'),
          ),
          FilledButton(
            key: const ValueKey('staff-role-confirm'),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(fr ? 'Confirmer' : 'Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _syncing = true);
    // Les rôles client/chauffeur sont conservés ; un seul rôle de personnel à la fois.
    final roles = <String>{
      ...currentRoles.where((r) => !_staffRoles.contains(r)),
      if (staffRole != 'none') staffRole,
    }.toList();
    if (roles.isEmpty) roles.add('customer');
    try {
      await FirebaseFunctions.instance.httpsCallable('setUserRole').call({
        'targetUid': widget.userId,
        'roles': roles,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fr
                ? 'Rôle mis à jour. La personne doit se reconnecter.'
                : 'Role updated. The person must sign in again.',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ?? (fr ? 'Modification impossible.' : 'Unable to update.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  static List<String> _roles(Map<String, dynamic> data) {
    final raw = data['roles'];
    if (raw is List) return raw.whereType<String>().toList();
    final role = data['role'];
    return role is String && role.isNotEmpty ? [role] : ['customer'];
  }
}
