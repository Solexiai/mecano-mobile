import 'enums.dart';

class AppUser {
  final String id;
  String fullName;
  String email;
  String phone;
  String? profilePhotoUrl;
  List<UserRole> roles;
  DateTime memberSince;
  String city;
  bool identityVerified;
  bool documentsVerified;

  AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.profilePhotoUrl,
    List<UserRole>? roles,
    DateTime? memberSince,
    this.city = 'Montréal, QC',
    this.identityVerified = false,
    this.documentsVerified = false,
  })  : roles = roles ?? [UserRole.customer],
        memberSince = memberSince ?? DateTime.now();

  bool hasRole(UserRole role) => roles.contains(role);

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullName': fullName,
        'email': email,
        'phone': phone,
        'profilePhotoUrl': profilePhotoUrl,
        'roles': roles.map((r) => r.name).toList(),
        'memberSince': memberSince.toIso8601String(),
        'city': city,
        'identityVerified': identityVerified,
        'documentsVerified': documentsVerified,
      };

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'],
        fullName: json['fullName'],
        email: json['email'],
        phone: json['phone'],
        profilePhotoUrl: json['profilePhotoUrl'],
        roles: (json['roles'] as List)
            .map((r) => UserRole.values.firstWhere((e) => e.name == r))
            .toList(),
        memberSince: DateTime.parse(json['memberSince']),
        city: json['city'] ?? 'Montréal, QC',
        identityVerified: json['identityVerified'] ?? false,
        documentsVerified: json['documentsVerified'] ?? false,
      );
}
