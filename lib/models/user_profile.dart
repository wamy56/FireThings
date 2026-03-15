import 'company_member.dart';

/// Represents a user's profile with company association
class UserProfile {
  final String uid;
  final String? companyId;
  final CompanyRole? companyRole;
  final String? fcmToken;

  UserProfile({
    required this.uid,
    this.companyId,
    this.companyRole,
    this.fcmToken,
  });

  bool get hasCompany => companyId != null;

  bool get isAdmin => companyRole == CompanyRole.admin;
  bool get isDispatcher => companyRole == CompanyRole.dispatcher;
  bool get isDispatcherOrAdmin =>
      companyRole == CompanyRole.admin ||
      companyRole == CompanyRole.dispatcher;

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'companyId': companyId,
      'companyRole': companyRole?.name,
      'fcmToken': fcmToken,
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      companyId: json['companyId'] as String?,
      companyRole: json['companyRole'] != null
          ? CompanyRole.values.firstWhere(
              (r) => r.name == json['companyRole'],
              orElse: () => CompanyRole.engineer,
            )
          : null,
      fcmToken: json['fcmToken'] as String?,
    );
  }

  UserProfile copyWith({
    String? uid,
    String? companyId,
    CompanyRole? companyRole,
    String? fcmToken,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      companyId: companyId ?? this.companyId,
      companyRole: companyRole ?? this.companyRole,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }

  @override
  String toString() {
    return 'UserProfile(uid: $uid, companyId: $companyId, role: ${companyRole?.name})';
  }
}
