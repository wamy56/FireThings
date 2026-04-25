import 'package:flutter/foundation.dart';

import '../utils/json_helpers.dart';
import 'permission.dart';

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
  final Map<String, bool> permissions;

  CompanyMember({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    this.fcmToken,
    required this.joinedAt,
    this.isActive = true,
    Map<String, bool>? permissions,
  }) : permissions = permissions ?? AppPermission.defaultsForRole(role);

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'displayName': displayName,
      'email': email,
      'role': role.name,
      'fcmToken': fcmToken,
      'joinedAt': joinedAt.toIso8601String(),
      'isActive': isActive,
      'permissions': permissions,
    };
  }

  factory CompanyMember.fromJson(Map<String, dynamic> json) {
    final role = CompanyRole.values.firstWhere(
      (r) => r.name == json['role'],
      orElse: () => CompanyRole.engineer,
    );
    final defaults = AppPermission.defaultsForRole(role);
    final rawPerms = json['permissions'];
    final stored = <String, bool>{};
    if (rawPerms is Map) {
      for (final entry in rawPerms.entries) {
        if (entry.value is bool) {
          stored[entry.key.toString()] = entry.value as bool;
        } else {
          stored[entry.key.toString()] = false;
          debugPrint('CompanyMember.fromJson: permission ${entry.key} had '
              'non-bool value ${entry.value}, defaulting to false');
        }
      }
    }
    final merged = {...defaults, ...stored};

    return CompanyMember(
      uid: json['uid'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: role,
      fcmToken: json['fcmToken'] as String?,
      joinedAt: jsonDateRequired(json['joinedAt']),
      isActive: json['isActive'] as bool? ?? true,
      permissions: merged,
    );
  }

  /// Check if this member has a specific permission.
  /// Admin role always returns true as a safety net.
  bool hasPermission(AppPermission perm) {
    if (role == CompanyRole.admin) return true;
    return permissions[perm.key] ?? false;
  }

  CompanyMember copyWith({
    String? uid,
    String? displayName,
    String? email,
    CompanyRole? role,
    String? fcmToken,
    DateTime? joinedAt,
    bool? isActive,
    Map<String, bool>? permissions,
  }) {
    return CompanyMember(
      uid: uid ?? this.uid,
      displayName: displayName ?? this.displayName,
      email: email ?? this.email,
      role: role ?? this.role,
      fcmToken: fcmToken ?? this.fcmToken,
      joinedAt: joinedAt ?? this.joinedAt,
      isActive: isActive ?? this.isActive,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  String toString() {
    return 'CompanyMember(uid: $uid, name: $displayName, role: ${role.name})';
  }
}
