/// Represents a defect found on an asset during inspection.
/// Lives as a first-class entity in Firestore with its own lifecycle (open/rectified).
class Defect {
  static const String statusOpen = 'open';
  static const String statusRectified = 'rectified';

  static const String severityMinor = 'minor';
  static const String severityMajor = 'major';
  static const String severityCritical = 'critical';

  final String id;
  final String assetId;
  final String siteId;
  final String severity; // minor, major, critical
  final String description;
  final String? commonFaultId; // matches an entry from AssetType.commonFaults
  final List<String> photoUrls;
  final String status; // open, rectified
  final String? action; // rectified_on_site, quote_required, replacement_needed
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final String? rectifiedBy;
  final String? rectifiedByName;
  final DateTime? rectifiedAt;
  final String? rectifiedNote;
  final String? serviceRecordId; // links to the service record that created it

  Defect({
    required this.id,
    required this.assetId,
    required this.siteId,
    required this.severity,
    required this.description,
    this.commonFaultId,
    this.photoUrls = const [],
    this.status = statusOpen,
    this.action,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.rectifiedBy,
    this.rectifiedByName,
    this.rectifiedAt,
    this.rectifiedNote,
    this.serviceRecordId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'assetId': assetId,
      'siteId': siteId,
      'severity': severity,
      'description': description,
      'commonFaultId': commonFaultId,
      'photoUrls': photoUrls,
      'status': status,
      'action': action,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': createdAt.toIso8601String(),
      'rectifiedBy': rectifiedBy,
      'rectifiedByName': rectifiedByName,
      'rectifiedAt': rectifiedAt?.toIso8601String(),
      'rectifiedNote': rectifiedNote,
      'serviceRecordId': serviceRecordId,
    };
  }

  factory Defect.fromJson(Map<String, dynamic> json) {
    return Defect(
      id: json['id'] as String,
      assetId: json['assetId'] as String,
      siteId: json['siteId'] as String,
      severity: json['severity'] as String,
      description: json['description'] as String,
      commonFaultId: json['commonFaultId'] as String?,
      photoUrls: (json['photoUrls'] as List<dynamic>?)
              ?.map((u) => u as String)
              .toList() ??
          [],
      status: json['status'] as String? ?? statusOpen,
      action: json['action'] as String?,
      createdBy: json['createdBy'] as String,
      createdByName: json['createdByName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      rectifiedBy: json['rectifiedBy'] as String?,
      rectifiedByName: json['rectifiedByName'] as String?,
      rectifiedAt: json['rectifiedAt'] != null
          ? DateTime.tryParse(json['rectifiedAt'] as String)
          : null,
      rectifiedNote: json['rectifiedNote'] as String?,
      serviceRecordId: json['serviceRecordId'] as String?,
    );
  }

  Defect copyWith({
    String? id,
    String? assetId,
    String? siteId,
    String? severity,
    String? description,
    String? commonFaultId,
    List<String>? photoUrls,
    String? status,
    String? action,
    String? createdBy,
    String? createdByName,
    DateTime? createdAt,
    String? rectifiedBy,
    String? rectifiedByName,
    DateTime? rectifiedAt,
    String? rectifiedNote,
    String? serviceRecordId,
  }) {
    return Defect(
      id: id ?? this.id,
      assetId: assetId ?? this.assetId,
      siteId: siteId ?? this.siteId,
      severity: severity ?? this.severity,
      description: description ?? this.description,
      commonFaultId: commonFaultId ?? this.commonFaultId,
      photoUrls: photoUrls ?? this.photoUrls,
      status: status ?? this.status,
      action: action ?? this.action,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      createdAt: createdAt ?? this.createdAt,
      rectifiedBy: rectifiedBy ?? this.rectifiedBy,
      rectifiedByName: rectifiedByName ?? this.rectifiedByName,
      rectifiedAt: rectifiedAt ?? this.rectifiedAt,
      rectifiedNote: rectifiedNote ?? this.rectifiedNote,
      serviceRecordId: serviceRecordId ?? this.serviceRecordId,
    );
  }

  @override
  String toString() =>
      'Defect(id: $id, assetId: $assetId, severity: $severity, status: $status)';
}
