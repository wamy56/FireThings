/// Role of a company member
enum CompanyRole { admin, dispatcher, engineer }

/// Represents a member of a company
class CompanyMember {
  final String uid;
  final String displayName;
  final String email;
  final CompanyRole role;
  final String? fcmToken;
  final DateTime joinedAt;
  final bool isActive;
  final bool canManageAssetTypes;

  CompanyMember({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.fcmToken,
    required this.joinedAt,
    this.isActive = true,
    this.canManageAssetTypes = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'role': role.name,
      'fcmToken': fcmToken,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
      'canManageAssetTypes': canManageAssetTypes,
    };
  }

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    return CompanyMember(
      uid: json['uid'] as String,
      displayName: json['displayName'] as String,
      email: json['email'] as String,
      role: CompanyRole.values.firstWhere(
        (r) => r.name == json['role'],
        orElse: () => CompanyRole.engineer,
      ),
      fcmToken: json['fcmToken'] as String?,
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      isActive: json['isActive'] as bool? ?? true,
      canManageAssetTypes: json['canManageAssetTypes'] as bool? ?? false,
    );
  }

  CompanyMember copyWith({
    String? uid,
    String? displayName,
    String? email,
    CompanyRole? role,
    String? fcmToken,
    DateTime? joinedAt,
    bool? isActive,
    bool? canManageAssetTypes,
  }) {
    return CompanyMember(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      canManageAssetTypes: canManageAssetTypes ?? this.canManageAssetTypes,
    );
  }

  @override
  String toString() {
    return 'CompanyMember(uid: $uid, name: $displayName, role: ${role.name})';
  }
}
