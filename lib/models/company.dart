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
      createdAt: DateTime.parse(json['createdAt'] as String),
      logoUrl: json['logoUrl'] as String?,
      inviteCode: json['inviteCode'] as String?,
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
    );
  }

  @override
  String toString() {
    return 'Company(id: $id, name: $name)';
  }
}
