// ---------------------------------------------------------------------------
// AppUserV2 — représentation locale (Flutter) d'un utilisateur dont la
// source de vérité est Firebase Authentication + Firestore (`users`).
//
// IMPORTANT SÉCURITÉ :
// - `roles` ici est un MIROIR en lecture des custom claims Firebase Auth
//   et/ou du document Firestore `users/{uid}`. Ce champ ne doit JAMAIS être
//   modifiable depuis Flutter directement (pas de write client sur les
//   rôles). Toute élévation de rôle doit passer par une Cloud Function
//   protégée exécutée par un admin/super_admin.
// - Ce modèle coexiste temporairement avec `AppUser`/`UserRole` (legacy,
//   authentification simulée) pendant la migration progressive. Ne pas
//   supprimer l'ancien modèle avant que tous les écrans soient migrés.
// ---------------------------------------------------------------------------

import '../../models/enums.dart';

class AppUserV2 {
  final String uid; // Firebase Auth UID
  final String email;
  final String? phone;
  final String fullName;
  final String? profilePhotoUrl;
  final List<PlatformRole> roles;
  final DateTime createdAt;
  final bool isDisabled;

  /// true seulement si le compte a vérifié son adresse courriel via
  /// Firebase Authentication (source de vérité serveur).
  final bool emailVerified;

  const AppUserV2({
    required this.uid,
    required this.email,
    this.phone,
    required this.fullName,
    this.profilePhotoUrl,
    required this.roles,
    required this.createdAt,
    this.isDisabled = false,
    this.emailVerified = false,
  });

  bool hasRole(PlatformRole role) => roles.contains(role);

  bool get isPrivileged =>
      hasRole(PlatformRole.analyst) ||
      hasRole(PlatformRole.admin) ||
      hasRole(PlatformRole.superAdmin);

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'email': email,
    'phone': phone,
    'full_name': fullName,
    'profile_photo_url': profilePhotoUrl,
    'roles': roles.map((r) => r.claimValue).toList(),
    'created_at': createdAt.toIso8601String(),
    'is_disabled': isDisabled,
    'email_verified': emailVerified,
  };

  factory AppUserV2.fromJson(String uid, Map<String, dynamic> json) {
    final rawRoles =
        (json['roles'] as List?)?.cast<String>() ?? const ['customer'];
    return AppUserV2(
      uid: uid,
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      fullName: json['full_name'] as String? ?? '',
      profilePhotoUrl: json['profile_photo_url'] as String?,
      roles: rawRoles
          .map(PlatformRoleX.tryFromClaim)
          .whereType<PlatformRole>()
          .toList(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      isDisabled: json['is_disabled'] as bool? ?? false,
      emailVerified: json['email_verified'] as bool? ?? false,
    );
  }
}
