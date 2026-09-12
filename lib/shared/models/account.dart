/// Account identity.
///
/// Role is assigned at registration and retained for this phone account.
enum AccountRole { artisan, buyer }

AccountRole? accountRoleFromName(String? name) {
  if (name == null) return null;
  for (final role in AccountRole.values) {
    if (role.name == name) return role;
  }
  return null;
}

class Account {
  final String id;
  final String firebaseUid;
  final AccountRole role;
  final String? name;
  final String? phone;
  final String? email;
  final String languagePref;
  final bool isNew;
  final Map<String, dynamic> profile;

  const Account({
    required this.id,
    required this.firebaseUid,
    required this.role,
    required this.languagePref,
    this.name,
    this.phone,
    this.email,
    this.isNew = false,
    this.profile = const {},
  });

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json['id'] as String,
        firebaseUid: json['firebase_uid'] as String,
        role:
            accountRoleFromName(json['role'] as String?) ?? AccountRole.artisan,
        name: json['name'] as String?,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        languagePref: json['language_pref'] as String? ?? 'hi',
        isNew: json['is_new'] as bool? ?? false,
        profile: (json['profile'] as Map?)?.cast<String, dynamic>() ?? const {},
      );

  String? get craftCategory => profile['craft_category'] as String?;
  String? get businessName => profile['business_name'] as String?;
  String? get businessType => profile['business_type'] as String?;
  String? get industry => profile['industry'] as String?;
  String? get state => profile['state'] as String?;
  String? get district => profile['district'] as String?;
  bool get isVerified => profile['is_verified'] as bool? ?? false;

  String get displayName {
    final trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) return trimmed;
    final business = businessName?.trim() ?? '';
    if (business.isNotEmpty) return business;
    return email ?? phone ?? '';
  }
}
