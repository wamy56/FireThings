/// Represents a shared company site for dispatch job creation
class CompanySite {
  final String id;
  final String name;
  final String address;
  final String? notes;
  final double? latitude;
  final double? longitude;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CompanySite({
    required this.id,
    required this.name,
    required this.address,
    this.notes,
    this.latitude,
    this.longitude,
    required this.createdBy,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'notes': notes,
      'latitude': latitude,
      'longitude': longitude,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory CompanySite.fromJson(Map<String, dynamic> json) {
    return CompanySite(
      id: json['id'] as String,
      name: json['name'] as String,
      address: json['address'] as String,
      notes: json['notes'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
    );
  }

  CompanySite copyWith({
    String? id,
    String? name,
    String? address,
    String? notes,
    double? latitude,
    double? longitude,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CompanySite(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() =>
      'CompanySite(id: $id, name: $name, address: $address)';
}
