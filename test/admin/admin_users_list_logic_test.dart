// Admin › Utilisateurs (Daniel, 2026-11-10) : tri par date, courriels, effacés.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movik_connect/screens/dashboard/admin/users/admin_users_list_logic.dart';

void main() {
  final users = <Map<String, dynamic>>[
    {'full_name': 'Bob', 'email': 'bob@example.test', 'created_at': '2026-11-05T10:00:00.000Z'},
    {'full_name': 'alice', 'email': 'Alice@example.test', 'created_at': Timestamp.fromDate(DateTime.utc(2026, 11, 9))},
    {'full_name': 'Zoé', 'email': 'alice@example.test'},
    {'full_name': 'Carl', 'email': '', 'created_at': '2026-10-01T10:00:00.000Z'},
  ];

  test('date d’inscription : texte ISO ou Timestamp', () {
    expect(userCreatedAt(users[0]), DateTime.utc(2026, 11, 5, 10));
    expect(userCreatedAt(users[1])!.isAtSameMomentAs(DateTime.utc(2026, 11, 9)), isTrue);
    expect(userCreatedAt(users[2]), isNull);
  });

  test('tri : plus récents, plus anciens (sans date à la fin), nom', () {
    names(UserSort s) => sortUsers(users, (u) => u, s).map((u) => u['full_name']).toList();
    expect(names(UserSort.recent), ['alice', 'Bob', 'Carl', 'Zoé']);
    expect(names(UserSort.oldest), ['Carl', 'Bob', 'alice', 'Zoé']);
    expect(names(UserSort.name), ['alice', 'Bob', 'Carl', 'Zoé']);
  });

  test('courriels : sans doublon (majuscules comprises) ni vide', () {
    expect(uniqueEmails(users), ['bob@example.test', 'Alice@example.test']);
  });

  test('client effacé caché ; libellé d’inscription', () {
    expect(isDeletedUser({'deleted': true}), isTrue);
    expect(isDeletedUser({'full_name': 'Bob'}), isFalse);
    expect(signupLabel(DateTime(2026, 11, 10), true), 'Inscrit le 10 nov. 2026');
    expect(signupLabel(DateTime(2026, 11, 10), false), 'Joined Nov 10, 2026');
    expect(signupLabel(null, true), 'Date d’inscription inconnue');
  });

  // 2026-11-17 (Daniel) : séparer les clients des chauffeurs.
  test('client / chauffeur : un chauffeur n’est client que s’il a demandé un prix', () {
    final client = {'roles': ['customer']};
    final chauffeur = {'roles': ['customer', 'driver']};
    final chauffeurClient = {'roles': ['customer', 'driver'], 'is_customer': true};
    final ancien = {'role': 'driver'};
    expect(isCustomerAccount(client), isTrue);
    expect(isDriverAccount(client), isFalse);
    expect(isCustomerAccount(chauffeur), isFalse);
    expect(isDriverAccount(chauffeur), isTrue);
    expect(isCustomerAccount(chauffeurClient), isTrue);
    expect(isDriverAccount(chauffeurClient), isTrue);
    expect(isCustomerAccount(ancien), isFalse);
    expect(isCustomerAccount({'roles': ['driver'], 'is_customer': true}), isTrue);
    expect(isStaffAccount({'roles': ['customer', 'super_admin']}), isTrue);
  });

  test('mentions « Aussi chauffeur » / « Aussi client »', () {
    final chauffeurClient = {'roles': ['customer', 'driver'], 'is_customer': true};
    final chauffeur = {'roles': ['customer', 'driver']};
    expect(alsoLabel(chauffeurClient, inCustomers: true, fr: true), 'Aussi chauffeur');
    expect(alsoLabel(chauffeurClient, inCustomers: false, fr: true), 'Aussi client');
    expect(alsoLabel(chauffeur, inCustomers: false, fr: true), isNull);
    expect(alsoLabel({'roles': ['customer']}, inCustomers: true, fr: false), isNull);
  });
}
