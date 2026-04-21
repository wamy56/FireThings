import '../utils/json_helpers.dart';

enum LogbookEntryType {
  falseAlarm,
  realAlarm,
  systemFault,
  disablement,
  reinstatement,
  serviceVisit,
  modification,
  testOfSystem,
  other;

  String get displayLabel {
    switch (this) {
      case LogbookEntryType.falseAlarm:
        return 'False Alarm';
      case LogbookEntryType.realAlarm:
        return 'Real Alarm';
      case LogbookEntryType.systemFault:
        return 'System Fault';
      case LogbookEntryType.disablement:
        return 'Disablement';
      case LogbookEntryType.reinstatement:
        return 'Reinstatement';
      case LogbookEntryType.serviceVisit:
        return 'Service Visit';
      case LogbookEntryType.modification:
        return 'Modification';
      case LogbookEntryType.testOfSystem:
        return 'Test of System';
      case LogbookEntryType.other:
        return 'Other';
    }
  }

  static LogbookEntryType fromString(String? value) {
    if (value == null) return LogbookEntryType.other;
    for (final t in LogbookEntryType.values) {
      if (t.name == value) return t;
    }
    return LogbookEntryType.other;
  }
}

class LogbookEntry {
  final String id;
  final String siteId;
  final LogbookEntryType type;
  final DateTime occurredAt;
  final String description;
  final String? zoneOrDeviceReference;
  final String? cause;
  final String? actionTaken;
  final String? loggedByName;
  final String? loggedByRole;
  final String? visitId;
  final DateTime createdAt;

  LogbookEntry({
    required this.id,
    required this.siteId,
    required this.type,
    required this.occurredAt,
    required this.description,
    this.zoneOrDeviceReference,
    this.cause,
    this.actionTaken,
    this.loggedByName,
    this.loggedByRole,
    this.visitId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'type': type.name,
      'occurredAt': occurredAt.toIso8601String(),
      'description': description,
      'zoneOrDeviceReference': zoneOrDeviceReference,
      'cause': cause,
      'actionTaken': actionTaken,
      'loggedByName': loggedByName,
      'loggedByRole': loggedByRole,
      'visitId': visitId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory LogbookEntry.fromJson(Map<String, dynamic> json) {
    return LogbookEntry(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      type: LogbookEntryType.fromString(json['type'] as String?),
      occurredAt: jsonDateRequired(json['occurredAt']),
      description: json['description'] as String? ?? '',
      zoneOrDeviceReference: json['zoneOrDeviceReference'] as String?,
      cause: json['cause'] as String?,
      actionTaken: json['actionTaken'] as String?,
      loggedByName: json['loggedByName'] as String?,
      loggedByRole: json['loggedByRole'] as String?,
      visitId: json['visitId'] as String?,
      createdAt: jsonDateRequired(json['createdAt']),
    );
  }

  LogbookEntry copyWith({
    String? id,
    String? siteId,
    LogbookEntryType? type,
    DateTime? occurredAt,
    String? description,
    String? zoneOrDeviceReference,
    String? cause,
    String? actionTaken,
    String? loggedByName,
    String? loggedByRole,
    String? visitId,
    DateTime? createdAt,
  }) {
    return LogbookEntry(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      type: type ?? this.type,
      occurredAt: occurredAt ?? this.occurredAt,
      description: description ?? this.description,
      zoneOrDeviceReference:
          zoneOrDeviceReference ?? this.zoneOrDeviceReference,
      cause: cause ?? this.cause,
      actionTaken: actionTaken ?? this.actionTaken,
      loggedByName: loggedByName ?? this.loggedByName,
      loggedByRole: loggedByRole ?? this.loggedByRole,
      visitId: visitId ?? this.visitId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
