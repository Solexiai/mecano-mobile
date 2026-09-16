import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
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

  static List<String> _roles(Map<String, dynamic> data) {
    final raw = data['roles'];
    if (raw is List) return raw.whereType<String>().toList();
    final role = data['role'];
    return role is String && role.isNotEmpty ? [role] : ['customer'];
  }
}
