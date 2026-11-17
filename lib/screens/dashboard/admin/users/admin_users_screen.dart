import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
import '../../../../providers/firebase_auth_provider.dart';
import '../../../../providers/locale_provider.dart';
import 'admin_users_list_logic.dart';
import 'customer_deletion_card.dart';

// 2026-11-17 (Daniel) : « séparer les clients des chauffeurs ». La liste
// s'ouvre sur les clients ; un chauffeur n'y figure que s'il a demandé un
// prix ou réservé (mention « Aussi chauffeur »), et un client-chauffeur porte
// « Aussi client » dans l'onglet Chauffeurs. Le super-admin peut effacer un
// compte depuis le menu « ⋮ » de chaque carte.
enum _UserFilter { customers, drivers, administrators, all }

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.initialFilter = 'customers'});
  final String initialFilter;
  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _searchController = TextEditingController();
  late _UserFilter _filter;
  // 2026-11-10 (Daniel) : trier par date, isoler les courriels, filtre
  // « Accepte les offres » (dernière réservation, loi anti-pourriel).
  UserSort _sort = UserSort.recent;
  bool _offersOnly = false;
  /// Onglet Clients : cacher ceux qui sont aussi chauffeurs.
  bool _hideDrivers = false;
  Set<String>? _optIns;
  bool _loadingOptIns = false;
  bool _recomputing = false;

  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialFilter) {
      'customers' => _UserFilter.customers,
      'drivers' => _UserFilter.drivers,
      'administrators' => _UserFilter.administrators,
      'all' => _UserFilter.all,
      _ => _UserFilter.customers,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = context.watch<LocaleProvider>().locale;
    final fr = locale == 'fr';
    final isSuperAdmin = context.watch<FirebaseAuthProvider>().isSuperAdmin;
    return Scaffold(
      appBar: AppBar(title: Text(fr ? 'Utilisateurs' : 'Users')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                fr
                    ? 'Impossible de charger les utilisateurs.'
                    : 'Unable to load users.',
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final query = _searchController.text.trim().toLowerCase();
          final live = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            if ((data['migrated_to_uid'] ?? '').toString().isNotEmpty) {
              return false;
            }
            return !isDeletedUser(data);
          }).toList();
          final counts = {
            _UserFilter.customers: live.where((d) => isCustomerAccount(d.data())).length,
            _UserFilter.drivers: live.where((d) => isDriverAccount(d.data())).length,
            _UserFilter.administrators: live.where((d) => isStaffAccount(d.data())).length,
            _UserFilter.all: live.length,
          };
          final users = live.where((doc) {
            final data = doc.data();
            if (_offersOnly && !(_optIns?.contains(doc.id) ?? false)) {
              return false;
            }
            final matchesFilter = switch (_filter) {
              _UserFilter.all => true,
              _UserFilter.customers =>
                isCustomerAccount(data) && !(_hideDrivers && isDriverAccount(data)),
              _UserFilter.drivers => isDriverAccount(data),
              _UserFilter.administrators => isStaffAccount(data),
            };
            final haystack =
                '${data['full_name'] ?? ''} ${data['email'] ?? ''} ${doc.id}'
                    .toLowerCase();
            return matchesFilter && (query.isEmpty || haystack.contains(query));
          });
          final sorted = sortUsers(users, (doc) => doc.data(), _sort);
          final emails = uniqueEmails(sorted.map((doc) => doc.data()));

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: fr
                      ? 'Rechercher par nom ou courriel'
                      : 'Search by name or email',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _filterChip(
                    _UserFilter.customers,
                    '${fr ? 'Clients' : 'Customers'} · ${counts[_UserFilter.customers]}',
                  ),
                  _filterChip(
                    _UserFilter.drivers,
                    '${fr ? 'Chauffeurs' : 'Drivers'} · ${counts[_UserFilter.drivers]}',
                  ),
                  _filterChip(
                    _UserFilter.administrators,
                    '${fr ? 'Personnel' : 'Staff'} · ${counts[_UserFilter.administrators]}',
                  ),
                  _filterChip(
                    _UserFilter.all,
                    '${fr ? 'Tous' : 'All'} · ${counts[_UserFilter.all]}',
                  ),
                  if (_filter == _UserFilter.customers)
                    FilterChip(
                      key: const ValueKey('users-hide-drivers'),
                      avatar: const Icon(Icons.person_off_outlined, size: 18),
                      label: Text(fr ? 'Masquer les chauffeurs' : 'Hide drivers'),
                      selected: _hideDrivers,
                      onSelected: (v) => setState(() => _hideDrivers = v),
                    ),
                  FilterChip(
                    key: const ValueKey('users-offers-only'),
                    avatar: _loadingOptIns
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.campaign_outlined, size: 18),
                    label: Text(fr ? 'Accepte les offres' : 'Accepts offers'),
                    selected: _offersOnly,
                    onSelected: _loadingOptIns ? null : (v) => _toggleOffers(v, fr),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      fr ? '${sorted.length} compte(s)' : '${sorted.length} account(s)',
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                  DropdownButton<UserSort>(
                    key: const ValueKey('users-sort'),
                    value: _sort,
                    underline: const SizedBox.shrink(),
                    icon: const Icon(Icons.sort),
                    onChanged: (v) => setState(() => _sort = v ?? _sort),
                    items: [
                      DropdownMenuItem(
                        value: UserSort.recent,
                        child: Text(fr ? 'Plus récents' : 'Newest'),
                      ),
                      DropdownMenuItem(
                        value: UserSort.oldest,
                        child: Text(fr ? 'Plus anciens' : 'Oldest'),
                      ),
                      DropdownMenuItem(
                        value: UserSort.name,
                        child: Text(fr ? 'Nom A à Z' : 'Name A–Z'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('users-copy-emails'),
                  onPressed: emails.isEmpty ? null : () => _copyEmails(emails, fr),
                  icon: const Icon(Icons.copy_all_outlined),
                  label: Text(
                    fr
                        ? 'Copier les ${emails.length} courriel(s)'
                        : 'Copy ${emails.length} email(s)',
                  ),
                ),
              ),
              if (!_offersOnly)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    fr
                        ? 'Pour une promotion, cochez d’abord « Accepte les offres » (loi anti-pourriel).'
                        : 'For a promotion, first select “Accepts offers” (anti-spam law).',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              if (_filter == _UserFilter.customers)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    fr
                        ? 'Un chauffeur apparaît ici seulement s’il a demandé un prix ou réservé (« Aussi chauffeur »).'
                        : 'A driver appears here only after requesting a price or booking (“Also a driver”).',
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              if (isSuperAdmin)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('users-recompute-flags'),
                    onPressed: _recomputing ? null : () => _recomputeFlags(fr),
                    icon: _recomputing
                        ? const SizedBox.square(
                            dimension: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.sync_outlined, size: 18),
                    label: Text(
                      fr ? 'Recalculer qui est client' : 'Recompute who is a customer',
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              if (sorted.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      fr ? 'Aucun utilisateur trouvé.' : 'No users found.',
                    ),
                  ),
                ),
              ...sorted.map((doc) {
                final data = doc.data();
                final name = (data['full_name'] ?? '').toString().trim();
                final email = (data['email'] ?? '').toString().trim();
                final roles = _cardRoles(data, _filter);
                final also = alsoLabel(
                  data,
                  inCustomers: _filter == _UserFilter.customers,
                  fr: fr,
                );
                final display = name.isNotEmpty ? name : email;
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        display.isNotEmpty ? display[0].toUpperCase() : '?',
                      ),
                    ),
                    title: Text(
                      name.isNotEmpty
                          ? name
                          : (fr ? 'Nom non renseigné' : 'Name missing'),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(email.isNotEmpty ? email : doc.id),
                        Text(
                          signupLabel(userCreatedAt(data), fr),
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final role in roles)
                              Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text(_roleLabel(role, fr)),
                              ),
                            if (also != null)
                              Chip(
                                key: ValueKey('also-${doc.id}'),
                                visualDensity: VisualDensity.compact,
                                avatar: const Icon(Icons.swap_horiz, size: 16),
                                label: Text(also),
                              ),
                          ],
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: isSuperAdmin
                        ? PopupMenuButton<String>(
                            key: ValueKey('user-menu-${doc.id}'),
                            tooltip: 'Actions',
                            onSelected: (value) {
                              if (value == 'open') {
                                context.push('/$locale/admin/utilisateurs/${doc.id}');
                              } else if (value == 'delete') {
                                startAccountDeletion(context, userId: doc.id, locale: locale);
                              }
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                value: 'open',
                                child: Text(fr ? 'Ouvrir la fiche' : 'Open file'),
                              ),
                              PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  fr ? 'Effacer le compte…' : 'Delete account…',
                                  style: const TextStyle(color: AppColors.error),
                                ),
                              ),
                            ],
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push('/$locale/admin/utilisateurs/${doc.id}'),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  Future<void> _toggleOffers(bool selected, bool fr) async {
    if (!selected) {
      setState(() => _offersOnly = false);
      return;
    }
    setState(() => _loadingOptIns = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getMarketingOptIns')
          .call(<String, dynamic>{});
      final ids = (result.data as Map)['userIds'];
      if (!mounted) return;
      setState(() {
        _optIns = ids is List ? ids.whereType<String>().toSet() : <String>{};
        _offersOnly = true;
      });
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.message ??
                (fr ? 'Liste des offres indisponible.' : 'Offers list unavailable.'),
          ),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _loadingOptIns = false);
    }
  }

  Future<void> _recomputeFlags(bool fr) async {
    setState(() => _recomputing = true);
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('backfillCustomerFlags')
          .call(<String, dynamic>{});
      final data = Map<String, dynamic>.from(result.data as Map);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            fr
                ? '${data['customers']} client(s), ${data['driversOnly']} chauffeur(s) seulement, sur ${data['total']} compte(s).'
                : '${data['customers']} customer(s), ${data['driversOnly']} driver(s) only, out of ${data['total']} account(s).',
          ),
        ),
      );
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? (fr ? 'Recalcul impossible.' : 'Unable to recompute.')),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _recomputing = false);
    }
  }

  Future<void> _copyEmails(List<String> emails, bool fr) async {
    await Clipboard.setData(ClipboardData(text: emails.join(', ')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          fr
              ? '${emails.length} courriel(s) copié(s). Collez-les dans le champ « Cci ».'
              : '${emails.length} email(s) copied. Paste them in the “Bcc” field.',
        ),
      ),
    );
  }

  Widget _filterChip(_UserFilter value, String label) => ChoiceChip(
    label: Text(label),
    selected: _filter == value,
    onSelected: (_) => setState(() => _filter = value),
  );

  /// Pastilles de rôle : « Client » seulement si c'en est vraiment un ; le
  /// rôle de l'onglet courant est sous-entendu (la mention « Aussi… » dit
  /// le reste).
  static List<String> _cardRoles(Map<String, dynamic> data, _UserFilter filter) => [
    for (final role in userRoles(data))
      if ((role != 'customer' || isCustomerAccount(data)) &&
          !(filter == _UserFilter.customers && (role == 'customer' || role == 'driver')) &&
          !(filter == _UserFilter.drivers && (role == 'driver' || role == 'customer')))
        role,
  ];

  static String _roleLabel(String role, bool fr) => switch (role) {
    'customer' => fr ? 'Client' : 'Customer',
    'driver' => fr ? 'Chauffeur' : 'Driver',
    'analyst' => fr ? 'Analyste' : 'Analyst',
    'admin' => 'Admin',
    'super_admin' => fr ? 'Super administrateur' : 'Super admin',
    _ => role,
  };
}
