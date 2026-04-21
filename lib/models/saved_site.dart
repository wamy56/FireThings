import '../utils/json_helpers.dart';

/// Represents a saved site/address that engineers visit frequently
class SavedSite {
  final String id;
  final String engineerId; // Which engineer saved this site
  final String siteName;
  final String address;
  final String? notes;
  final DateTime createdAt;
  final DateTime? lastModifiedAt;
  final bool isBs5839Site;
  final String? lastVisitId;
  final DateTime? nextServiceDueDate;

  SavedSite({
    required this.id,
    required this.engineerId,
    required this.siteName,
    required this.address,
    this.notes,
    required this.createdAt,
    this.lastModifiedAt,
    this.isBs5839Site = false,
    this.lastVisitId,
    this.nextServiceDueDate,
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
      'isBs5839Site': isBs5839Site,
      'lastVisitId': lastVisitId,
      'nextServiceDueDate': nextServiceDueDate?.toIso8601String(),
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
      createdAt: jsonDateRequired(json['createdAt']),
      lastModifiedAt: jsonDateOptional(json['lastModifiedAt']),
      isBs5839Site: json['isBs5839Site'] as bool? ?? false,
      lastVisitId: json['lastVisitId'] as String?,
      nextServiceDueDate: jsonDateOptional(json['nextServiceDueDate']),
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
    bool? isBs5839Site,
    String? lastVisitId,
    DateTime? nextServiceDueDate,
  }) {
    return SavedSite(
      id: id ?? this.id,
      engineerId: engineerId ?? this.engineerId,
      siteName: siteName ?? this.siteName,
      address: address ?? this.address,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      isBs5839Site: isBs5839Site ?? this.isBs5839Site,
      lastVisitId: lastVisitId ?? this.lastVisitId,
      nextServiceDueDate: nextServiceDueDate ?? this.nextServiceDueDate,
    );
  }

  @override
  String toString() {
    return 'SavedSite(id: $id, siteName: $siteName, address: $address)';
  }
}
