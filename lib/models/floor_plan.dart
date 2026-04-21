import '../utils/json_helpers.dart';

/// Represents a floor plan image for a site, onto which assets are pinned.
class FloorPlan {
  final String id;
  final String siteId;
  final String name;
  final int sortOrder;
  final String imageUrl;
  final double imageWidth;
  final double imageHeight;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastModifiedAt;
  final double pinScale;
  final String fileExtension;
  final bool showLabels;

  FloorPlan({
    required this.id,
    required this.siteId,
    required this.name,
    this.sortOrder = 0,
    required this.imageUrl,
    required this.imageWidth,
    required this.imageHeight,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.lastModifiedAt,
    this.pinScale = 1.0,
    this.fileExtension = 'jpg',
    this.showLabels = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'name': name,
      'sortOrder': sortOrder,
      'imageUrl': imageUrl,
      'imageWidth': imageWidth,
      'imageHeight': imageHeight,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
      'pinScale': pinScale,
      'fileExtension': fileExtension,
      'showLabels': showLabels,
    };
  }

  factory FloorPlan.fromJson(Map<String, dynamic> json) {
    return FloorPlan(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      name: json['name'] as String,
      sortOrder: json['sortOrder'] as int? ?? 0,
      imageUrl: json['imageUrl'] as String,
      imageWidth: (json['imageWidth'] as num).toDouble(),
      imageHeight: (json['imageHeight'] as num).toDouble(),
      createdBy: json['createdBy'] as String,
      createdAt: jsonDateRequired(json['createdAt']),
      updatedAt: jsonDateRequired(json['updatedAt']),
      lastModifiedAt: jsonDateOptional(json['lastModifiedAt']),
      pinScale: (json['pinScale'] as num?)?.toDouble() ?? 1.0,
      fileExtension: json['fileExtension'] as String? ?? 'jpg',
      showLabels: json['showLabels'] as bool? ?? true,
    );
  }

  FloorPlan copyWith({
    String? id,
    String? siteId,
    String? name,
    int? sortOrder,
    String? imageUrl,
    double? imageWidth,
    double? imageHeight,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastModifiedAt,
    double? pinScale,
    String? fileExtension,
    bool? showLabels,
  }) {
    return FloorPlan(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      name: name ?? this.name,
      sortOrder: sortOrder ?? this.sortOrder,
      imageUrl: imageUrl ?? this.imageUrl,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
      pinScale: pinScale ?? this.pinScale,
      fileExtension: fileExtension ?? this.fileExtension,
      showLabels: showLabels ?? this.showLabels,
    );
  }

  @override
  String toString() => 'FloorPlan(id: $id, name: $name, siteId: $siteId)';
}
