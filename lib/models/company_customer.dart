import '../utils/json_helpers.dart';

/// Represents a shared company customer for dispatch job creation
class CompanyCustomer {
  final String id;
  final String name;
  final String? address;
  final String? email;
  final String? phone;
  final String? notes;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CompanyCustomer({
    required this.id,
    required this.name,
    this.address,
    this.email,
    this.phone,
    this.notes,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'email': email,
      'phone': phone,
      'notes': notes,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory CompanyCustomer.fromJson(Map<String, dynamic> json) {
    return CompanyCustomer(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['createdBy'] as String,
      createdAt: jsonDateRequired(json['createdAt']),
      updatedAt: jsonDateOptional(json['updatedAt']),
    );
  }

  CompanyCustomer copyWith({
    String? id,
    String? name,
    String? address,
    String? email,
    String? phone,
    String? notes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanyCustomer(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      notes: notes ?? this.notes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'CompanyCustomer(id: $id, name: $name)';
}
