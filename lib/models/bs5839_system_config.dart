import '../utils/json_helpers.dart';

enum Bs5839SystemCategory {
  l1,
  l2,
  l3,
  l4,
  l5,
  p1,
  p2,
  m;

  String get displayLabel {
    switch (this) {
      case Bs5839SystemCategory.l1:
        return 'L1 — Life protection (full coverage)';
      case Bs5839SystemCategory.l2:
        return 'L2 — Life protection (defined areas)';
      case Bs5839SystemCategory.l3:
        return 'L3 — Life protection (escape routes)';
      case Bs5839SystemCategory.l4:
        return 'L4 — Life protection (circulation areas)';
      case Bs5839SystemCategory.l5:
        return 'L5 — Life protection (engineered)';
      case Bs5839SystemCategory.p1:
        return 'P1 — Property protection (full coverage)';
      case Bs5839SystemCategory.p2:
        return 'P2 — Property protection (defined areas)';
      case Bs5839SystemCategory.m:
        return 'M — Manual system only';
    }
  }

  static Bs5839SystemCategory fromString(String? value) {
    if (value == null) return Bs5839SystemCategory.l1;
    for (final c in Bs5839SystemCategory.values) {
      if (c.name == value.toLowerCase()) return c;
    }
    return Bs5839SystemCategory.l1;
  }
}

enum ArcTransmissionMethod {
  none,
  digital,
  ip,
  psdn,
  other;

  String get displayLabel {
    switch (this) {
      case ArcTransmissionMethod.none:
        return 'Not connected to ARC';
      case ArcTransmissionMethod.digital:
        return 'Digital (Redcare/DualCom)';
      case ArcTransmissionMethod.ip:
        return 'All-IP';
      case ArcTransmissionMethod.psdn:
        return 'Legacy PSTN';
      case ArcTransmissionMethod.other:
        return 'Other';
    }
  }

  static ArcTransmissionMethod fromString(String? value) {
    if (value == null) return ArcTransmissionMethod.none;
    for (final m in ArcTransmissionMethod.values) {
      if (m.name == value.toLowerCase()) return m;
    }
    return ArcTransmissionMethod.none;
  }
}

class Bs5839SystemConfig {
  final String id;
  final String siteId;
  final Bs5839SystemCategory category;
  final String? categoryJustification;
  final String responsiblePersonName;
  final String? responsiblePersonRole;
  final String? responsiblePersonEmail;
  final String? responsiblePersonPhone;
  final DateTime? originalCommissionDate;
  final DateTime? lastModificationDate;
  final bool arcConnected;
  final ArcTransmissionMethod arcTransmissionMethod;
  final String? arcProvider;
  final String? arcAccountRef;
  final int? arcMaxTransmissionTimeSeconds;
  final String? zonePlanUrl;
  final DateTime? zonePlanLastReviewedAt;
  final bool hasSleepingAccommodation;
  final int numberOfZones;
  final bool cyberSecurityRequired;
  final String? panelMake;
  final String? panelModel;
  final String? panelSerialNumber;
  final String standardVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String updatedBy;

  Bs5839SystemConfig({
    required this.id,
    required this.siteId,
    required this.category,
    this.categoryJustification,
    required this.responsiblePersonName,
    this.responsiblePersonRole,
    this.responsiblePersonEmail,
    this.responsiblePersonPhone,
    this.originalCommissionDate,
    this.lastModificationDate,
    this.arcConnected = false,
    this.arcTransmissionMethod = ArcTransmissionMethod.none,
    this.arcProvider,
    this.arcAccountRef,
    this.arcMaxTransmissionTimeSeconds,
    this.zonePlanUrl,
    this.zonePlanLastReviewedAt,
    this.hasSleepingAccommodation = false,
    this.numberOfZones = 1,
    this.cyberSecurityRequired = false,
    this.panelMake,
    this.panelModel,
    this.panelSerialNumber,
    this.standardVersion = 'BS 5839-1:2025',
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.updatedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'category': category.name,
      'categoryJustification': categoryJustification,
      'responsiblePersonName': responsiblePersonName,
      'responsiblePersonRole': responsiblePersonRole,
      'responsiblePersonEmail': responsiblePersonEmail,
      'responsiblePersonPhone': responsiblePersonPhone,
      'originalCommissionDate': originalCommissionDate?.toIso8601String(),
      'lastModificationDate': lastModificationDate?.toIso8601String(),
      'arcConnected': arcConnected,
      'arcTransmissionMethod': arcTransmissionMethod.name,
      'arcProvider': arcProvider,
      'arcAccountRef': arcAccountRef,
      'arcMaxTransmissionTimeSeconds': arcMaxTransmissionTimeSeconds,
      'zonePlanUrl': zonePlanUrl,
      'zonePlanLastReviewedAt': zonePlanLastReviewedAt?.toIso8601String(),
      'hasSleepingAccommodation': hasSleepingAccommodation,
      'numberOfZones': numberOfZones,
      'cyberSecurityRequired': cyberSecurityRequired,
      'panelMake': panelMake,
      'panelModel': panelModel,
      'panelSerialNumber': panelSerialNumber,
      'standardVersion': standardVersion,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'updatedBy': updatedBy,
    };
  }

  factory Bs5839SystemConfig.fromJson(Map<String, dynamic> json) {
    return Bs5839SystemConfig(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      category:
          Bs5839SystemCategory.fromString(json['category'] as String?),
      categoryJustification: json['categoryJustification'] as String?,
      responsiblePersonName: json['responsiblePersonName'] as String? ?? '',
      responsiblePersonRole: json['responsiblePersonRole'] as String?,
      responsiblePersonEmail: json['responsiblePersonEmail'] as String?,
      responsiblePersonPhone: json['responsiblePersonPhone'] as String?,
      originalCommissionDate:
          jsonDateOptional(json['originalCommissionDate']),
      lastModificationDate: jsonDateOptional(json['lastModificationDate']),
      arcConnected: json['arcConnected'] as bool? ?? false,
      arcTransmissionMethod: ArcTransmissionMethod.fromString(
          json['arcTransmissionMethod'] as String?),
      arcProvider: json['arcProvider'] as String?,
      arcAccountRef: json['arcAccountRef'] as String?,
      arcMaxTransmissionTimeSeconds:
          json['arcMaxTransmissionTimeSeconds'] as int?,
      zonePlanUrl: json['zonePlanUrl'] as String?,
      zonePlanLastReviewedAt:
          jsonDateOptional(json['zonePlanLastReviewedAt']),
      hasSleepingAccommodation:
          json['hasSleepingAccommodation'] as bool? ?? false,
      numberOfZones: json['numberOfZones'] as int? ?? 1,
      cyberSecurityRequired: json['cyberSecurityRequired'] as bool? ?? false,
      panelMake: json['panelMake'] as String?,
      panelModel: json['panelModel'] as String?,
      panelSerialNumber: json['panelSerialNumber'] as String?,
      standardVersion:
          json['standardVersion'] as String? ?? 'BS 5839-1:2025',
      createdAt: jsonDateRequired(json['createdAt']),
      updatedAt: jsonDateRequired(json['updatedAt']),
      createdBy: json['createdBy'] as String? ?? '',
      updatedBy: json['updatedBy'] as String? ?? '',
    );
  }

  Bs5839SystemConfig copyWith({
    String? id,
    String? siteId,
    Bs5839SystemCategory? category,
    String? categoryJustification,
    String? responsiblePersonName,
    String? responsiblePersonRole,
    String? responsiblePersonEmail,
    String? responsiblePersonPhone,
    DateTime? originalCommissionDate,
    DateTime? lastModificationDate,
    bool? arcConnected,
    ArcTransmissionMethod? arcTransmissionMethod,
    String? arcProvider,
    String? arcAccountRef,
    int? arcMaxTransmissionTimeSeconds,
    String? zonePlanUrl,
    DateTime? zonePlanLastReviewedAt,
    bool? hasSleepingAccommodation,
    int? numberOfZones,
    bool? cyberSecurityRequired,
    String? panelMake,
    String? panelModel,
    String? panelSerialNumber,
    String? standardVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? updatedBy,
  }) {
    return Bs5839SystemConfig(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      category: category ?? this.category,
      categoryJustification:
          categoryJustification ?? this.categoryJustification,
      responsiblePersonName:
          responsiblePersonName ?? this.responsiblePersonName,
      responsiblePersonRole:
          responsiblePersonRole ?? this.responsiblePersonRole,
      responsiblePersonEmail:
          responsiblePersonEmail ?? this.responsiblePersonEmail,
      responsiblePersonPhone:
          responsiblePersonPhone ?? this.responsiblePersonPhone,
      originalCommissionDate:
          originalCommissionDate ?? this.originalCommissionDate,
      lastModificationDate:
          lastModificationDate ?? this.lastModificationDate,
      arcConnected: arcConnected ?? this.arcConnected,
      arcTransmissionMethod:
          arcTransmissionMethod ?? this.arcTransmissionMethod,
      arcProvider: arcProvider ?? this.arcProvider,
      arcAccountRef: arcAccountRef ?? this.arcAccountRef,
      arcMaxTransmissionTimeSeconds:
          arcMaxTransmissionTimeSeconds ?? this.arcMaxTransmissionTimeSeconds,
      zonePlanUrl: zonePlanUrl ?? this.zonePlanUrl,
      zonePlanLastReviewedAt:
          zonePlanLastReviewedAt ?? this.zonePlanLastReviewedAt,
      hasSleepingAccommodation:
          hasSleepingAccommodation ?? this.hasSleepingAccommodation,
      numberOfZones: numberOfZones ?? this.numberOfZones,
      cyberSecurityRequired:
          cyberSecurityRequired ?? this.cyberSecurityRequired,
      panelMake: panelMake ?? this.panelMake,
      panelModel: panelModel ?? this.panelModel,
      panelSerialNumber: panelSerialNumber ?? this.panelSerialNumber,
      standardVersion: standardVersion ?? this.standardVersion,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      updatedBy: updatedBy ?? this.updatedBy,
    );
  }
}
