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
    expect(userCreatedAt(users[1]), DateTime.utc(2026, 11, 9));
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
}
