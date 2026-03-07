/// Represents a saved site/address that engineers visit frequently
class SavedSite {
  final String id;
  final String engineerId; // Which engineer saved this site
  final String siteName;
  final String address;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;

  SavedSite({
    required this.id,
    required this.engineerId,
    required this.siteName,
    required this.address,
    this.notes,
    required this.createdAt,
    this.lastModifiedAt,
  });

  /// Convert SavedSite to JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'engineerId': engineerId,
      'siteName': siteName,
      'address': address,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
    };
  }

  /// Create SavedSite from JSON map
  factory SavedSite.fromJson(Map<String, dynamic> json) {
    return SavedSite(
      id: json['id'] as String,
      engineerId: json['engineerId'] as String,
      siteName: json['siteName'] as String,
      address: json['address'] as String,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
    );
  }

  /// Create a copy of this site with some values changed
  SavedSite copyWith({
    String? id,
    String? engineerId,
    String? siteName,
    String? address,
    String? notes,
    DateTime? createdAt,
    DateTime? lastModifiedAt,
  }) {
    return SavedSite(
      id: id ?? this.id,
      engineerId: engineerId ?? this.engineerId,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  @override
  String toString() {
    return 'SavedSite(id: $id, siteName: $siteName, address: $address)';
  }
}
