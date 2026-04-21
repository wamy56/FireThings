import '../utils/json_helpers.dart';

/// Represents a company in the dispatch system
class Company {
  final String id;
  final String name;
  final String? address;
  final String? phone;
  final String? email;
  final String createdBy;
  final DateTime createdAt;
  final String? logoUrl;
  final String? inviteCode;
  final DateTime? inviteCodeExpiresAt;

  Company({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    this.email,
    required this.createdBy,
    required this.createdAt,
    this.logoUrl,
    this.inviteCode,
    this.inviteCodeExpiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'phone': phone,
      'email': email,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'logoUrl': logoUrl,
      'inviteCode': inviteCode,
      'inviteCodeExpiresAt': inviteCodeExpiresAt?.toIso8601String(),
    };
  }

  factory Company.fromJson(Map<String, dynamic> json) {
    return Company(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdBy: json['createdBy'] as String,
      createdAt: jsonDateRequired(json['createdAt']),
      logoUrl: json['logoUrl'] as String?,
      inviteCode: json['inviteCode'] as String?,
      inviteCodeExpiresAt: jsonDateOptional(json['inviteCodeExpiresAt']),
    );
  }

  Company copyWith({
    String? id,
    String? name,
    String? address,
    String? phone,
    String? email,
    String? createdBy,
    DateTime? createdAt,
    String? logoUrl,
    String? inviteCode,
    DateTime? inviteCodeExpiresAt,
  }) {
    return Company(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      logoUrl: logoUrl ?? this.logoUrl,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteCodeExpiresAt: inviteCodeExpiresAt ?? this.inviteCodeExpiresAt,
    );
  }

  @override
  String toString() {
    return 'Company(id: $id, name: $name)';
  }
}
