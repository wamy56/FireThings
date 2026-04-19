/// Status of a dispatched job
enum DispatchedJobStatus {
  created,
  assigned,
  accepted,
  enRoute,
  onSite,
  completed,
  declined,
}

/// Priority level of a dispatched job
enum JobPriority { normal, urgent, emergency }

/// Represents a job dispatched to an engineer
class DispatchedJob {
  final String id;
  final String companyId;

  // Job details
  final String title;
  final String? description;
  final String? jobNumber;
  final String? jobType;

  // Site information
  final String siteName;
  final String siteAddress;
  final String? companySiteId;
  final double? latitude;
  final double? longitude;
  final String? parkingNotes;
  final String? accessNotes;
  final String? siteNotes;

  // Contact
  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;

  // Assignment
  final String? assignedTo;
  final String? assignedToName;
  final String createdBy;
  final String createdByName;

  // Scheduling
  final DateTime? scheduledDate;
  final String? scheduledTime;
  final String? estimatedDuration;

  // Status
  final DispatchedJobStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? lastUpdatedBy;
  final DateTime? completedAt;

  // Linked records
  final String? linkedJobsheetId;
  final String? sourceQuoteId;
  final String? declineReason;

  // Priority
  final JobPriority priority;

  // System info (fire alarm specific)
  final String? systemCategory;
  final String? panelMake;
  final String? panelLocation;
  final int? numberOfZones;

  DispatchedJob({
    required this.id,
    required this.companyId,
    required this.title,
    this.description,
    this.jobNumber,
    this.jobType,
    required this.siteName,
    required this.siteAddress,
    this.companySiteId,
    this.latitude,
    this.longitude,
    this.parkingNotes,
    this.accessNotes,
    this.siteNotes,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.assignedTo,
    this.assignedToName,
    required this.createdBy,
    required this.createdByName,
    this.scheduledDate,
    this.scheduledTime,
    this.estimatedDuration,
    this.status = DispatchedJobStatus.created,
    required this.createdAt,
    required this.updatedAt,
    this.lastUpdatedBy,
    this.completedAt,
    this.linkedJobsheetId,
    this.sourceQuoteId,
    this.declineReason,
    this.priority = JobPriority.normal,
    this.systemCategory,
    this.panelMake,
    this.panelLocation,
    this.numberOfZones,
  });

  static const _statusMap = {
    'created': DispatchedJobStatus.created,
    'assigned': DispatchedJobStatus.assigned,
    'accepted': DispatchedJobStatus.accepted,
    'en_route': DispatchedJobStatus.enRoute,
    'on_site': DispatchedJobStatus.onSite,
    'completed': DispatchedJobStatus.completed,
    'declined': DispatchedJobStatus.declined,
  };

  static const _statusToString = {
    DispatchedJobStatus.created: 'created',
    DispatchedJobStatus.assigned: 'assigned',
    DispatchedJobStatus.accepted: 'accepted',
    DispatchedJobStatus.enRoute: 'en_route',
    DispatchedJobStatus.onSite: 'on_site',
    DispatchedJobStatus.completed: 'completed',
    DispatchedJobStatus.declined: 'declined',
  };

  static const _priorityMap = {
    'normal': JobPriority.normal,
    'urgent': JobPriority.urgent,
    'emergency': JobPriority.emergency,
  };

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'companyId': companyId,
      'title': title,
      'description': description,
      'jobNumber': jobNumber,
      'jobType': jobType,
      'siteName': siteName,
      'siteAddress': siteAddress,
      'companySiteId': companySiteId,
      'latitude': latitude,
      'longitude': longitude,
      'parkingNotes': parkingNotes,
      'accessNotes': accessNotes,
      'siteNotes': siteNotes,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'contactEmail': contactEmail,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'scheduledDate': scheduledDate?.toIso8601String(),
      'scheduledTime': scheduledTime,
      'estimatedDuration': estimatedDuration,
      'status': _statusToString[status],
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'lastUpdatedBy': lastUpdatedBy,
      'completedAt': completedAt?.toIso8601String(),
      'linkedJobsheetId': linkedJobsheetId,
      'sourceQuoteId': sourceQuoteId,
      'declineReason': declineReason,
      'priority': priority.name,
      'systemCategory': systemCategory,
      'panelMake': panelMake,
      'panelLocation': panelLocation,
      'numberOfZones': numberOfZones,
    };
  }

  factory DispatchedJob.fromJson(Map<String, dynamic> json) {
    return DispatchedJob(
      id: json['id'] as String,
      companyId: json['companyId'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      jobNumber: json['jobNumber'] as String?,
      jobType: json['jobType'] as String?,
      siteName: json['siteName'] as String,
      siteAddress: json['siteAddress'] as String,
      companySiteId: json['companySiteId'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      parkingNotes: json['parkingNotes'] as String?,
      accessNotes: json['accessNotes'] as String?,
      siteNotes: json['siteNotes'] as String?,
      contactName: json['contactName'] as String?,
      contactPhone: json['contactPhone'] as String?,
      contactEmail: json['contactEmail'] as String?,
      assignedTo: json['assignedTo'] as String?,
      assignedToName: json['assignedToName'] as String?,
      createdBy: json['createdBy'] as String,
      createdByName: json['createdByName'] as String,
      scheduledDate: json['scheduledDate'] != null
          ? DateTime.parse(json['scheduledDate'] as String)
          : null,
      scheduledTime: json['scheduledTime'] as String?,
      estimatedDuration: json['estimatedDuration'] as String?,
      status: _statusMap[json['status'] as String] ??
          DispatchedJobStatus.created,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      lastUpdatedBy: json['lastUpdatedBy'] as String?,
      completedAt: json['completedAt'] != null
          ? DateTime.parse(json['completedAt'] as String)
          : null,
      linkedJobsheetId: json['linkedJobsheetId'] as String?,
      sourceQuoteId: json['sourceQuoteId'] as String?,
      declineReason: json['declineReason'] as String?,
      priority: _priorityMap[json['priority'] as String?] ??
          JobPriority.normal,
      systemCategory: json['systemCategory'] as String?,
      panelMake: json['panelMake'] as String?,
      panelLocation: json['panelLocation'] as String?,
      numberOfZones: json['numberOfZones'] as int?,
    );
  }

  DispatchedJob copyWith({
    String? id,
    String? companyId,
    String? title,
    String? description,
    String? jobNumber,
    String? jobType,
    String? siteName,
    String? siteAddress,
    String? companySiteId,
    double? latitude,
    double? longitude,
    String? parkingNotes,
    String? accessNotes,
    String? siteNotes,
    String? contactName,
    String? contactPhone,
    String? contactEmail,
    String? assignedTo,
    String? assignedToName,
    String? createdBy,
    String? createdByName,
    DateTime? scheduledDate,
    String? scheduledTime,
    String? estimatedDuration,
    DispatchedJobStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastUpdatedBy,
    DateTime? completedAt,
    String? linkedJobsheetId,
    String? sourceQuoteId,
    String? declineReason,
    JobPriority? priority,
    String? systemCategory,
    String? panelMake,
    String? panelLocation,
    int? numberOfZones,
  }) {
    return DispatchedJob(
      id: id ?? this.id,
      companyId: companyId ?? this.companyId,
      title: title ?? this.title,
      description: description ?? this.description,
      jobNumber: jobNumber ?? this.jobNumber,
      jobType: jobType ?? this.jobType,
      siteName: siteName ?? this.siteName,
      siteAddress: siteAddress ?? this.siteAddress,
      companySiteId: companySiteId ?? this.companySiteId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      parkingNotes: parkingNotes ?? this.parkingNotes,
      accessNotes: accessNotes ?? this.accessNotes,
      siteNotes: siteNotes ?? this.siteNotes,
      contactName: contactName ?? this.contactName,
      contactPhone: contactPhone ?? this.contactPhone,
      contactEmail: contactEmail ?? this.contactEmail,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      scheduledDate: scheduledDate ?? this.scheduledDate,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastUpdatedBy: lastUpdatedBy ?? this.lastUpdatedBy,
      completedAt: completedAt ?? this.completedAt,
      linkedJobsheetId: linkedJobsheetId ?? this.linkedJobsheetId,
      sourceQuoteId: sourceQuoteId ?? this.sourceQuoteId,
      declineReason: declineReason ?? this.declineReason,
      priority: priority ?? this.priority,
      systemCategory: systemCategory ?? this.systemCategory,
      panelMake: panelMake ?? this.panelMake,
      panelLocation: panelLocation ?? this.panelLocation,
      numberOfZones: numberOfZones ?? this.numberOfZones,
    );
  }

  @override
  String toString() {
    return 'DispatchedJob(id: $id, title: $title, status: ${_statusToString[status]})';
  }
}
