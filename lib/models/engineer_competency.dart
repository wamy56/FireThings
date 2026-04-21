import 'dart:convert';

import '../utils/json_helpers.dart';

enum QualificationType {
  fiaUnit1,
  fiaUnit2,
  fiaUnit3,
  fiaUnit4,
  fiaUnit5,
  fiaUnit6,
  fiaUnit7,
  bafeSp203_1,
  eca,
  nicei,
  cityAndGuilds,
  ipaf,
  pasma,
  cscs,
  other;

  String get displayLabel {
    switch (this) {
      case QualificationType.fiaUnit1:
        return 'FIA Unit 1';
      case QualificationType.fiaUnit2:
        return 'FIA Unit 2';
      case QualificationType.fiaUnit3:
        return 'FIA Unit 3';
      case QualificationType.fiaUnit4:
        return 'FIA Unit 4';
      case QualificationType.fiaUnit5:
        return 'FIA Unit 5';
      case QualificationType.fiaUnit6:
        return 'FIA Unit 6';
      case QualificationType.fiaUnit7:
        return 'FIA Unit 7';
      case QualificationType.bafeSp203_1:
        return 'BAFE SP203-1';
      case QualificationType.eca:
        return 'ECA';
      case QualificationType.nicei:
        return 'NICEI';
      case QualificationType.cityAndGuilds:
        return 'City & Guilds';
      case QualificationType.ipaf:
        return 'IPAF';
      case QualificationType.pasma:
        return 'PASMA';
      case QualificationType.cscs:
        return 'CSCS';
      case QualificationType.other:
        return 'Other';
    }
  }

  static QualificationType fromString(String? value) {
    if (value == null) return QualificationType.other;
    for (final q in QualificationType.values) {
      if (q.name == value) return q;
    }
    return QualificationType.other;
  }
}

class Qualification {
  final String id;
  final QualificationType type;
  final String? customTypeName;
  final String issuingBody;
  final DateTime issuedDate;
  final DateTime? expiryDate;
  final String? certificateNumber;
  final String? evidenceFileUrl;

  Qualification({
    required this.id,
    required this.type,
    this.customTypeName,
    required this.issuingBody,
    required this.issuedDate,
    this.expiryDate,
    this.certificateNumber,
    this.evidenceFileUrl,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'customTypeName': customTypeName,
      'issuingBody': issuingBody,
      'issuedDate': issuedDate.toIso8601String(),
      'expiryDate': expiryDate?.toIso8601String(),
      'certificateNumber': certificateNumber,
      'evidenceFileUrl': evidenceFileUrl,
    };
  }

  factory Qualification.fromJson(Map<String, dynamic> json) {
    return Qualification(
      id: json['id'] as String,
      type: QualificationType.fromString(json['type'] as String?),
      customTypeName: json['customTypeName'] as String?,
      issuingBody: json['issuingBody'] as String? ?? '',
      issuedDate: jsonDateRequired(json['issuedDate']),
      expiryDate: jsonDateOptional(json['expiryDate']),
      certificateNumber: json['certificateNumber'] as String?,
      evidenceFileUrl: json['evidenceFileUrl'] as String?,
    );
  }

  Qualification copyWith({
    String? id,
    QualificationType? type,
    String? customTypeName,
    String? issuingBody,
    DateTime? issuedDate,
    DateTime? expiryDate,
    String? certificateNumber,
    String? evidenceFileUrl,
  }) {
    return Qualification(
      id: id ?? this.id,
      type: type ?? this.type,
      customTypeName: customTypeName ?? this.customTypeName,
      issuingBody: issuingBody ?? this.issuingBody,
      issuedDate: issuedDate ?? this.issuedDate,
      expiryDate: expiryDate ?? this.expiryDate,
      certificateNumber: certificateNumber ?? this.certificateNumber,
      evidenceFileUrl: evidenceFileUrl ?? this.evidenceFileUrl,
    );
  }
}

class CpdRecord {
  final String id;
  final DateTime date;
  final String topic;
  final double hours;
  final String? provider;
  final String? evidenceFileUrl;
  final String? notes;

  CpdRecord({
    required this.id,
    required this.date,
    required this.topic,
    required this.hours,
    this.provider,
    this.evidenceFileUrl,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'topic': topic,
      'hours': hours,
      'provider': provider,
      'evidenceFileUrl': evidenceFileUrl,
      'notes': notes,
    };
  }

  factory CpdRecord.fromJson(Map<String, dynamic> json) {
    return CpdRecord(
      id: json['id'] as String,
      date: jsonDateRequired(json['date']),
      topic: json['topic'] as String? ?? '',
      hours: (json['hours'] as num?)?.toDouble() ?? 0,
      provider: json['provider'] as String?,
      evidenceFileUrl: json['evidenceFileUrl'] as String?,
      notes: json['notes'] as String?,
    );
  }

  CpdRecord copyWith({
    String? id,
    DateTime? date,
    String? topic,
    double? hours,
    String? provider,
    String? evidenceFileUrl,
    String? notes,
  }) {
    return CpdRecord(
      id: id ?? this.id,
      date: date ?? this.date,
      topic: topic ?? this.topic,
      hours: hours ?? this.hours,
      provider: provider ?? this.provider,
      evidenceFileUrl: evidenceFileUrl ?? this.evidenceFileUrl,
      notes: notes ?? this.notes,
    );
  }
}

class EngineerCompetency {
  final String id;
  final String engineerId;
  final String engineerName;
  final List<Qualification> qualifications;
  final List<CpdRecord> cpdRecords;
  final double totalCpdHoursLast12Months;
  final DateTime? lastReviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  EngineerCompetency({
    required this.id,
    required this.engineerId,
    required this.engineerName,
    this.qualifications = const [],
    this.cpdRecords = const [],
    this.totalCpdHoursLast12Months = 0,
    this.lastReviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'engineerId': engineerId,
      'engineerName': engineerName,
      'qualifications': qualifications.map((q) => q.toJson()).toList(),
      'cpdRecords': cpdRecords.map((r) => r.toJson()).toList(),
      'totalCpdHoursLast12Months': totalCpdHoursLast12Months,
      'lastReviewedAt': lastReviewedAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory EngineerCompetency.fromJson(Map<String, dynamic> json) {
    return EngineerCompetency(
      id: json['id'] as String,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String? ?? '',
      qualifications: _parseQualifications(json['qualifications']),
      cpdRecords: _parseCpdRecords(json['cpdRecords']),
      totalCpdHoursLast12Months:
          (json['totalCpdHoursLast12Months'] as num?)?.toDouble() ?? 0,
      lastReviewedAt: jsonDateOptional(json['lastReviewedAt']),
      createdAt: jsonDateRequired(json['createdAt']),
      updatedAt: jsonDateRequired(json['updatedAt']),
    );
  }

  static List<Qualification> _parseQualifications(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      try {
        final list = jsonDecode(value) as List;
        return list
            .map((e) => Qualification.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [];
      }
    }
    if (value is List) {
      return value
          .map((e) => Qualification.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  static List<CpdRecord> _parseCpdRecords(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      try {
        final list = jsonDecode(value) as List;
        return list
            .map((e) => CpdRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [];
      }
    }
    if (value is List) {
      return value
          .map((e) => CpdRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  EngineerCompetency copyWith({
    String? id,
    String? engineerId,
    String? engineerName,
    List<Qualification>? qualifications,
    List<CpdRecord>? cpdRecords,
    double? totalCpdHoursLast12Months,
    DateTime? lastReviewedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EngineerCompetency(
      id: id ?? this.id,
      engineerId: engineerId ?? this.engineerId,
      engineerName: engineerName ?? this.engineerName,
      qualifications: qualifications ?? this.qualifications,
      cpdRecords: cpdRecords ?? this.cpdRecords,
      totalCpdHoursLast12Months:
          totalCpdHoursLast12Months ?? this.totalCpdHoursLast12Months,
      lastReviewedAt: lastReviewedAt ?? this.lastReviewedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
