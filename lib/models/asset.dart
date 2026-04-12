import 'dart:convert';

/// Represents a fire safety asset (detector, call point, extinguisher, etc.)
/// belonging to a site's asset register.
class Asset {
  static const String statusPass = 'pass';
  static const String statusFail = 'fail';
  static const String statusUntested = 'untested';
  static const String statusDecommissioned = 'decommissioned';

  final String id;
  final String siteId;
  final String assetTypeId;
  final String? variant;
  final String? make;
  final String? model;
  final String? serialNumber;
  final String? reference;
  final String? barcode;
  final String? floorPlanId;
  final double? xPercent;
  final double? yPercent;
  final String? locationDescription;
  final String? zone;
  final DateTime? installDate;
  final DateTime? warrantyExpiry;
  final int? expectedLifespanYears;
  final DateTime? decommissionDate;
  final String? decommissionReason;
  final String complianceStatus;
  final DateTime? lastServiceDate;
  final String? lastServiceBy;
  final String? lastServiceByName;
  final DateTime? nextServiceDue;
  final List<String> photoUrls;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? notes;
  final DateTime? lastModifiedAt;

  Asset({
    required this.id,
    required this.siteId,
    required this.assetTypeId,
    this.variant,
    this.make,
    this.model,
    this.serialNumber,
    this.reference,
    this.barcode,
    this.floorPlanId,
    this.xPercent,
    this.yPercent,
    this.locationDescription,
    this.zone,
    this.installDate,
    this.warrantyExpiry,
    this.expectedLifespanYears,
    this.decommissionDate,
    this.decommissionReason,
    this.complianceStatus = statusUntested,
    this.lastServiceDate,
    this.lastServiceBy,
    this.lastServiceByName,
    this.nextServiceDue,
    this.photoUrls = const [],
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.notes,
    this.lastModifiedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'assetTypeId': assetTypeId,
      'variant': variant,
      'make': make,
      'model': model,
      'serialNumber': serialNumber,
      'reference': reference,
      'barcode': barcode,
      'floorPlanId': floorPlanId,
      'xPercent': xPercent,
      'yPercent': yPercent,
      'locationDescription': locationDescription,
      'zone': zone,
      'installDate': installDate?.toIso8601String(),
      'warrantyExpiry': warrantyExpiry?.toIso8601String(),
      'expectedLifespanYears': expectedLifespanYears,
      'decommissionDate': decommissionDate?.toIso8601String(),
      'decommissionReason': decommissionReason,
      'complianceStatus': complianceStatus,
      'lastServiceDate': lastServiceDate?.toIso8601String(),
      'lastServiceBy': lastServiceBy,
      'lastServiceByName': lastServiceByName,
      'nextServiceDue': nextServiceDue?.toIso8601String(),
      'photoUrls': photoUrls,
      'createdBy': createdBy,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'notes': notes,
      'lastModifiedAt': lastModifiedAt?.toIso8601String(),
    };
  }

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      assetTypeId: json['assetTypeId'] as String,
      variant: json['variant'] as String?,
      make: json['make'] as String?,
      model: json['model'] as String?,
      serialNumber: json['serialNumber'] as String?,
      reference: json['reference'] as String?,
      barcode: json['barcode'] as String?,
      floorPlanId: json['floorPlanId'] as String?,
      xPercent: (json['xPercent'] as num?)?.toDouble(),
      yPercent: (json['yPercent'] as num?)?.toDouble(),
      locationDescription: json['locationDescription'] as String?,
      zone: json['zone'] as String?,
      installDate: json['installDate'] != null
          ? DateTime.tryParse(json['installDate'] as String)
          : null,
      warrantyExpiry: json['warrantyExpiry'] != null
          ? DateTime.tryParse(json['warrantyExpiry'] as String)
          : null,
      expectedLifespanYears: json['expectedLifespanYears'] as int?,
      decommissionDate: json['decommissionDate'] != null
          ? DateTime.tryParse(json['decommissionDate'] as String)
          : null,
      decommissionReason: json['decommissionReason'] as String?,
      complianceStatus:
          json['complianceStatus'] as String? ?? statusUntested,
      lastServiceDate: json['lastServiceDate'] != null
          ? DateTime.tryParse(json['lastServiceDate'] as String)
          : null,
      lastServiceBy: json['lastServiceBy'] as String?,
      lastServiceByName: json['lastServiceByName'] as String?,
      nextServiceDue: json['nextServiceDue'] != null
          ? DateTime.tryParse(json['nextServiceDue'] as String)
          : null,
      photoUrls: _parsePhotoUrls(json),
      createdBy: json['createdBy'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      notes: json['notes'] as String?,
      lastModifiedAt: json['lastModifiedAt'] != null
          ? DateTime.tryParse(json['lastModifiedAt'] as String)
          : null,
    );
  }

  /// Parse photoUrls from JSON, handling both:
  /// - String (from SQLite, JSON-encoded)
  /// - List (from Firestore, direct)
  /// - Old single photoUrl field (migration)
  static List<String> _parsePhotoUrls(Map<String, dynamic> json) {
    final photoUrls = json['photoUrls'];
    if (photoUrls == null) {
      // Migration: convert old single photoUrl to list
      final legacyUrl = json['photoUrl'] as String?;
      return legacyUrl != null ? [legacyUrl] : const [];
    }
    if (photoUrls is String) {
      // From SQLite: JSON-encoded string
      try {
        return List<String>.from(jsonDecode(photoUrls) as List);
      } catch (_) {
        return const [];
      }
    }
    if (photoUrls is List) {
      // From Firestore: direct list
      return photoUrls.map((e) => e as String).toList();
    }
    return const [];
  }

  Asset copyWith({
    String? id,
    String? siteId,
    String? assetTypeId,
    String? variant,
    String? make,
    String? model,
    String? serialNumber,
    String? reference,
    String? barcode,
    String? floorPlanId,
    double? xPercent,
    double? yPercent,
    String? locationDescription,
    String? zone,
    DateTime? installDate,
    DateTime? warrantyExpiry,
    int? expectedLifespanYears,
    DateTime? decommissionDate,
    String? decommissionReason,
    String? complianceStatus,
    DateTime? lastServiceDate,
    String? lastServiceBy,
    String? lastServiceByName,
    DateTime? nextServiceDue,
    List<String>? photoUrls,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? notes,
    DateTime? lastModifiedAt,
  }) {
    return Asset(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      assetTypeId: assetTypeId ?? this.assetTypeId,
      variant: variant ?? this.variant,
      make: make ?? this.make,
      model: model ?? this.model,
      serialNumber: serialNumber ?? this.serialNumber,
      reference: reference ?? this.reference,
      barcode: barcode ?? this.barcode,
      floorPlanId: floorPlanId ?? this.floorPlanId,
      xPercent: xPercent ?? this.xPercent,
      yPercent: yPercent ?? this.yPercent,
      locationDescription: locationDescription ?? this.locationDescription,
      zone: zone ?? this.zone,
      installDate: installDate ?? this.installDate,
      warrantyExpiry: warrantyExpiry ?? this.warrantyExpiry,
      expectedLifespanYears:
          expectedLifespanYears ?? this.expectedLifespanYears,
      decommissionDate: decommissionDate ?? this.decommissionDate,
      decommissionReason: decommissionReason ?? this.decommissionReason,
      complianceStatus: complianceStatus ?? this.complianceStatus,
      lastServiceDate: lastServiceDate ?? this.lastServiceDate,
      lastServiceBy: lastServiceBy ?? this.lastServiceBy,
      lastServiceByName: lastServiceByName ?? this.lastServiceByName,
      nextServiceDue: nextServiceDue ?? this.nextServiceDue,
      photoUrls: photoUrls ?? this.photoUrls,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      notes: notes ?? this.notes,
      lastModifiedAt: lastModifiedAt ?? this.lastModifiedAt,
    );
  }

  @override
  String toString() =>
      'Asset(id: $id, reference: $reference, type: $assetTypeId, status: $complianceStatus)';
}
