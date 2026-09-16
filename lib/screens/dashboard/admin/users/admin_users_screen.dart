import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/app_colors.dart';
import '../../../../providers/locale_provider.dart';

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
          }).toList();
          users.sort((a, b) {
            final aName = (a.data()['full_name'] ?? a.data()['email'] ?? '')
                .toString();
            final bName = (b.data()['full_name'] ?? b.data()['email'] ?? '')
                .toString();
            return aName.toLowerCase().compareTo(bName.toLowerCase());
          });

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
                ],
              ),
              const SizedBox(height: 18),
              Text(
                fr ? '${users.length} compte(s)' : '${users.length} account(s)',
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),
              if (users.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  child: Center(
                    child: Text(
                      fr ? 'Aucun utilisateur trouvé.' : 'No users found.',
                    ),
                  ),
                ),
              ...users.map((doc) {
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
