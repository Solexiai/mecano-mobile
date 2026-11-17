// Admin › Utilisateurs (Daniel, 2026-11-10) : trier par date, isoler les
// courriels, cacher les clients effacés. Calculs purs, testés à part.
import 'package:cloud_firestore/cloud_firestore.dart';

enum UserSort { recent, oldest, name }

/// Date d'inscription : texte ISO (création du compte dans l'app) ou
/// Timestamp (anciens profils). Null si absente.
DateTime? userCreatedAt(Map<String, dynamic> data) {
  final raw = data['created_at'];
  if (raw is Timestamp) return raw.toDate();
  if (raw is DateTime) return raw;
  if (raw is String) return DateTime.tryParse(raw);
  return null;
}

/// Profil d'un client effacé (anonymisé) : il ne s'affiche plus dans la liste.
bool isDeletedUser(Map<String, dynamic> data) => data['deleted'] == true;

/// Rôles du compte (`roles`, sinon l'ancien champ `role`, sinon client).
List<String> userRoles(Map<String, dynamic> data) {
  final raw = data['roles'];
  if (raw is List) return raw.whereType<String>().toList();
  final role = data['role'];
  return role is String && role.isNotEmpty ? [role] : const ['customer'];
}

const _staffRoles = {'analyst', 'admin', 'super_admin'};

/// Chauffeur = a (ou a eu) un dossier chauffeur, quel que soit son statut.
bool isDriverAccount(Map<String, dynamic> data) =>
    userRoles(data).contains('driver');

bool isStaffAccount(Map<String, dynamic> data) =>
    userRoles(data).any(_staffRoles.contains);

/// Client (Daniel, 2026-11-17) : un compte est UNE chose. Tout compte naît
/// « customer », mais dès qu'il est chauffeur ou personnel, ce n'est plus un
/// client. Un chauffeur qui veut réserver crée un compte client à part
/// (deux inscriptions).
bool isCustomerAccount(Map<String, dynamic> data) =>
    userRoles(data).contains('customer') &&
    !isDriverAccount(data) &&
    !isStaffAccount(data);

String _nameKey(Map<String, dynamic> data) =>
    (data['full_name'] ?? data['email'] ?? '').toString().trim().toLowerCase();

/// Tri de la liste. Les comptes sans date d'inscription vont à la fin.
List<T> sortUsers<T>(
  Iterable<T> users,
  Map<String, dynamic> Function(T) dataOf,
  UserSort sort,
) {
  final list = users.toList();
  int byName(T a, T b) => _nameKey(dataOf(a)).compareTo(_nameKey(dataOf(b)));
  list.sort((a, b) {
    if (sort == UserSort.name) return byName(a, b);
    final da = userCreatedAt(dataOf(a));
    final db = userCreatedAt(dataOf(b));
    if (da == null && db == null) return byName(a, b);
    if (da == null) return 1;
    if (db == null) return -1;
    final c = sort == UserSort.recent ? db.compareTo(da) : da.compareTo(db);
    return c != 0 ? c : byName(a, b);
  });
  return list;
}

/// Courriels de la liste affichée, sans doublon ni vide, prêts à coller dans
/// le champ « Cci » d'un courriel.
List<String> uniqueEmails(Iterable<Map<String, dynamic>> users) {
  final seen = <String>{};
  final out = <String>[];
  for (final data in users) {
    final email = (data['email'] ?? '').toString().trim();
    if (email.isEmpty || !email.contains('@')) continue;
    if (seen.add(email.toLowerCase())) out.add(email);
  }
  return out;
}

const _monthsFr = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _monthsEn = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// « Inscrit le 10 nov. 2026 » / « Joined Nov 10, 2026 ».
String signupLabel(DateTime? date, bool fr) {
  if (date == null) return fr ? 'Date d’inscription inconnue' : 'Join date unknown';
  final d = date.toLocal();
  return fr
      ? 'Inscrit le ${d.day} ${_monthsFr[d.month - 1]} ${d.year}'
      : 'Joined ${_monthsEn[d.month - 1]} ${d.day}, ${d.year}';
}
