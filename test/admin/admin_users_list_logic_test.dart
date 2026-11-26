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
  test('un compte est une chose : client, chauffeur ou personnel', () {
    final client = {'roles': ['customer']};
    final chauffeur = {'roles': ['customer', 'driver']};
    final patron = {'roles': ['customer', 'driver', 'super_admin']};
    final ancien = {'role': 'driver'};
    expect(isCustomerAccount(client), isTrue);
    expect(isDriverAccount(client), isFalse);
    expect(isCustomerAccount(chauffeur), isFalse);
    expect(isDriverAccount(chauffeur), isTrue);
    expect(isCustomerAccount(patron), isFalse);
    expect(isDriverAccount(patron), isTrue);
    expect(isStaffAccount(patron), isTrue);
    expect(isCustomerAccount(ancien), isFalse);
    expect(isStaffAccount({'roles': ['customer', 'super_admin']}), isTrue);
    // 2026-11-19 : chauffeur dès les coordonnées, dossier pas envoyé.
    final inachevee = {'roles': ['customer', 'driver'], 'driver_signup': 'started'};
    expect(isCustomerAccount(inachevee), isFalse);
    expect(isUnfinishedDriverSignup(inachevee), isTrue);
    expect(isUnfinishedDriverSignup({'roles': ['customer', 'driver'], 'driver_signup': 'submitted'}), isFalse);
    expect(isUnfinishedDriverSignup({'roles': ['customer'], 'driver_signup': 'started'}), isFalse);
  });

  // 2026-11-26 : prix avec le courriel seulement.
  test('visiteur qui a laissé son courriel : client, marqué « courriel seulement »', () {
    final invite = {'roles': ['customer'], 'guest': true, 'email': 'marie@exemple.com'};
    expect(isCustomerAccount(invite), isTrue);
    expect(isGuestLead(invite), isTrue);
    // Il a choisi son mot de passe : client ordinaire.
    expect(isGuestLead({...invite, 'guest': false}), isFalse);
    expect(isGuestLead({'roles': ['customer']}), isFalse);
    expect(isGuestLead({'roles': ['customer', 'driver'], 'guest': true}), isFalse);
  });

  // 2026-11-22 (Daniel) : un chauffeur cherché depuis l'onglet Clients
  // restait introuvable. La recherche fouille tous les comptes et chaque
  // résultat dit sa catégorie.
  test('recherche : nom, courriel ou identifiant, sans égard à l’onglet', () {
    final sylvain = {
      'full_name': 'Sylvain Dupont',
      'email': 'dupontsylvainsd@gmail.com',
      'roles': ['customer', 'driver'],
      'driver_signup': 'started',
    };
    expect(userMatchesSearch(sylvain, 'w489', 'dupont'), isTrue);
    expect(userMatchesSearch(sylvain, 'w489', '  SYLVAIN '), isTrue);
    expect(userMatchesSearch(sylvain, 'w489', 'w48'), isTrue);
    expect(userMatchesSearch(sylvain, 'w489', 'tremblay'), isFalse);
    expect(userMatchesSearch(sylvain, 'w489', ''), isTrue);
    expect(accountKind(sylvain), AccountKind.driver);
    expect(accountKindLabel(accountKind(sylvain), true), 'Chauffeur');
    expect(accountKind({'roles': ['customer']}), AccountKind.customer);
    expect(accountKind({'roles': ['customer', 'driver', 'admin']}), AccountKind.staff);
    expect(accountKindLabel(AccountKind.staff, false), 'Staff');
  });
}
