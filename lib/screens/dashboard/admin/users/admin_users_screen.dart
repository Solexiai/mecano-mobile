import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
import '../../../../providers/locale_provider.dart';
import 'admin_users_list_logic.dart';

enum _UserFilter { all, customers, drivers, administrators }

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key, this.initialFilter = 'all'});
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
  Set<String>? _optIns;
  bool _loadingOptIns = false;

  @override
  void initState() {
    super.initState();
    _filter = switch (widget.initialFilter) {
      'customers' => _UserFilter.customers,
      'drivers' => _UserFilter.drivers,
      'administrators' => _UserFilter.administrators,
      _ => _UserFilter.all,
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
          final users = snapshot.data!.docs.where((doc) {
            final data = doc.data();
            if ((data['migrated_to_uid'] ?? '').toString().isNotEmpty) {
              return false;
            }
            if (isDeletedUser(data)) return false;
            if (_offersOnly && !(_optIns?.contains(doc.id) ?? false)) {
              return false;
            }
            final roles = _roles(data);
            final matchesFilter = switch (_filter) {
              _UserFilter.all => true,
              _UserFilter.customers => roles.contains('customer'),
              _UserFilter.drivers => roles.contains('driver'),
              _UserFilter.administrators => roles.any(
                (r) => r == 'analyst' || r == 'admin' || r == 'super_admin',
              ),
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
                  _filterChip(_UserFilter.all, fr ? 'Tous' : 'All'),
                  _filterChip(
                    _UserFilter.customers,
                    fr ? 'Clients' : 'Customers',
                  ),
                  _filterChip(
                    _UserFilter.drivers,
                    fr ? 'Chauffeurs' : 'Drivers',
                  ),
                  _filterChip(_UserFilter.administrators, 'Administration'),
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
                final roles = _roles(data);
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
                          children: roles
                              .map(
                                (role) => Chip(
                                  visualDensity: VisualDensity.compact,
                                  label: Text(_roleLabel(role, fr)),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                    isThreeLine: true,
                    trailing: const Icon(Icons.chevron_right),
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

  static List<String> _roles(Map<String, dynamic> data) {
    final raw = data['roles'];
    if (raw is List) return raw.whereType<String>().toList();
    final role = data['role'];
    return role is String && role.isNotEmpty ? [role] : const ['customer'];
  }

  static String _roleLabel(String role, bool fr) => switch (role) {
    'customer' => fr ? 'Client' : 'Customer',
    'driver' => fr ? 'Chauffeur' : 'Driver',
    'analyst' => fr ? 'Analyste' : 'Analyst',
    'admin' => 'Admin',
    'super_admin' => fr ? 'Super administrateur' : 'Super admin',
    _ => role,
  };
}
