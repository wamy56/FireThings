import 'dart:convert';

import '../utils/json_helpers.dart';

enum InspectionVisitType {
  commissioning,
  routineService,
  modification,
  reInspection,
  emergencyCallOut;

  String get displayLabel {
    switch (this) {
      case InspectionVisitType.commissioning:
        return 'Commissioning';
      case InspectionVisitType.routineService:
        return 'Routine Service';
      case InspectionVisitType.modification:
        return 'Modification';
      case InspectionVisitType.reInspection:
        return 'Re-inspection';
      case InspectionVisitType.emergencyCallOut:
        return 'Emergency Call Out';
    }
  }

  static InspectionVisitType fromString(String? value) {
    if (value == null) return InspectionVisitType.routineService;
    for (final v in InspectionVisitType.values) {
      if (v.name == value) return v;
    }
    return InspectionVisitType.routineService;
  }
}

enum InspectionDeclaration {
  satisfactory,
  satisfactoryWithVariations,
  unsatisfactory,
  notDeclared;

  String get displayLabel {
    switch (this) {
      case InspectionDeclaration.satisfactory:
        return 'Satisfactory';
      case InspectionDeclaration.satisfactoryWithVariations:
        return 'Satisfactory with Variations';
      case InspectionDeclaration.unsatisfactory:
        return 'Unsatisfactory';
      case InspectionDeclaration.notDeclared:
        return 'Not Declared';
    }
  }

  static InspectionDeclaration fromString(String? value) {
    if (value == null) return InspectionDeclaration.notDeclared;
    for (final d in InspectionDeclaration.values) {
      if (d.name == value) return d;
    }
    return InspectionDeclaration.notDeclared;
  }
}

class BatteryLoadTestReading {
  final String powerSupplyAssetId;
  final double restingVoltage;
  final double loadedVoltage;
  final double? loadCurrentAmps;
  final bool passed;
  final String? notes;

  BatteryLoadTestReading({
    required this.powerSupplyAssetId,
    required this.restingVoltage,
    required this.loadedVoltage,
    this.loadCurrentAmps,
    required this.passed,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'powerSupplyAssetId': powerSupplyAssetId,
      'restingVoltage': restingVoltage,
      'loadedVoltage': loadedVoltage,
      'loadCurrentAmps': loadCurrentAmps,
      'passed': passed,
      'notes': notes,
    };
  }

  factory BatteryLoadTestReading.fromJson(Map<String, dynamic> json) {
    return BatteryLoadTestReading(
      powerSupplyAssetId: json['powerSupplyAssetId'] as String,
      restingVoltage: (json['restingVoltage'] as num).toDouble(),
      loadedVoltage: (json['loadedVoltage'] as num).toDouble(),
      loadCurrentAmps: (json['loadCurrentAmps'] as num?)?.toDouble(),
      passed: json['passed'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }
}

class InspectionVisit {
  final String id;
  final String siteId;
  final String engineerId;
  final String engineerName;
  final InspectionVisitType visitType;
  final DateTime visitDate;
  final DateTime? completedAt;

  final List<String> mcpIdsTestedThisVisit;
  final bool allDetectorsTestedThisVisit;
  final List<String> serviceRecordIds;

  final bool logbookReviewed;
  final String? logbookReviewNotes;
  final bool zonePlanVerified;
  final String? zonePlanVariationNotes;
  final bool causeAndEffectMatrixProvided;
  final bool cyberSecurityChecksCompleted;

  final List<BatteryLoadTestReading> batteryTestReadings;

  final bool arcSignallingTested;
  final int? arcTransmissionTimeMeasuredSeconds;
  final bool earthFaultTestPassed;
  final double? earthFaultReadingKOhms;

  final InspectionDeclaration declaration;
  final String? declarationNotes;
  final DateTime? nextServiceDueDate;

  final String? engineerSignatureBase64;
  final String? responsiblePersonSignatureBase64;
  final String? responsiblePersonSignedName;
  final DateTime? responsiblePersonSignedAt;

  final String? reportPdfUrl;
  final DateTime? reportGeneratedAt;

  final String? jobsheetId;
  final String? dispatchedJobId;

  final DateTime createdAt;
  final DateTime updatedAt;

  InspectionVisit({
    required this.id,
    required this.siteId,
    required this.engineerId,
    required this.engineerName,
    required this.visitType,
    required this.visitDate,
    this.completedAt,
    this.mcpIdsTestedThisVisit = const [],
    this.allDetectorsTestedThisVisit = false,
    this.serviceRecordIds = const [],
    this.logbookReviewed = false,
    this.logbookReviewNotes,
    this.zonePlanVerified = false,
    this.zonePlanVariationNotes,
    this.causeAndEffectMatrixProvided = false,
    this.cyberSecurityChecksCompleted = false,
    this.batteryTestReadings = const [],
    this.arcSignallingTested = false,
    this.arcTransmissionTimeMeasuredSeconds,
    this.earthFaultTestPassed = false,
    this.earthFaultReadingKOhms,
    this.declaration = InspectionDeclaration.notDeclared,
    this.declarationNotes,
    this.nextServiceDueDate,
    this.engineerSignatureBase64,
    this.responsiblePersonSignatureBase64,
    this.responsiblePersonSignedName,
    this.responsiblePersonSignedAt,
    this.reportPdfUrl,
    this.reportGeneratedAt,
    this.jobsheetId,
    this.dispatchedJobId,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'engineerId': engineerId,
      'engineerName': engineerName,
      'visitType': visitType.name,
      'visitDate': visitDate.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
      'mcpIdsTestedThisVisit': mcpIdsTestedThisVisit,
      'allDetectorsTestedThisVisit': allDetectorsTestedThisVisit,
      'serviceRecordIds': serviceRecordIds,
      'logbookReviewed': logbookReviewed,
      'logbookReviewNotes': logbookReviewNotes,
      'zonePlanVerified': zonePlanVerified,
      'zonePlanVariationNotes': zonePlanVariationNotes,
      'causeAndEffectMatrixProvided': causeAndEffectMatrixProvided,
      'cyberSecurityChecksCompleted': cyberSecurityChecksCompleted,
      'batteryTestReadings':
          batteryTestReadings.map((r) => r.toJson()).toList(),
      'arcSignallingTested': arcSignallingTested,
      'arcTransmissionTimeMeasuredSeconds':
          arcTransmissionTimeMeasuredSeconds,
      'earthFaultTestPassed': earthFaultTestPassed,
      'earthFaultReadingKOhms': earthFaultReadingKOhms,
      'declaration': declaration.name,
      'declarationNotes': declarationNotes,
      'nextServiceDueDate': nextServiceDueDate?.toIso8601String(),
      'engineerSignatureBase64': engineerSignatureBase64,
      'responsiblePersonSignatureBase64': responsiblePersonSignatureBase64,
      'responsiblePersonSignedName': responsiblePersonSignedName,
      'responsiblePersonSignedAt':
          responsiblePersonSignedAt?.toIso8601String(),
      'reportPdfUrl': reportPdfUrl,
      'reportGeneratedAt': reportGeneratedAt?.toIso8601String(),
      'jobsheetId': jobsheetId,
      'dispatchedJobId': dispatchedJobId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory InspectionVisit.fromJson(Map<String, dynamic> json) {
    return InspectionVisit(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      engineerId: json['engineerId'] as String,
      engineerName: json['engineerName'] as String,
      visitType:
          InspectionVisitType.fromString(json['visitType'] as String?),
      visitDate: jsonDateRequired(json['visitDate']),
      completedAt: jsonDateOptional(json['completedAt']),
      mcpIdsTestedThisVisit:
          _parseStringList(json['mcpIdsTestedThisVisit']),
      allDetectorsTestedThisVisit:
          json['allDetectorsTestedThisVisit'] as bool? ?? false,
      serviceRecordIds: _parseStringList(json['serviceRecordIds']),
      logbookReviewed: json['logbookReviewed'] as bool? ?? false,
      logbookReviewNotes: json['logbookReviewNotes'] as String?,
      zonePlanVerified: json['zonePlanVerified'] as bool? ?? false,
      zonePlanVariationNotes: json['zonePlanVariationNotes'] as String?,
      causeAndEffectMatrixProvided:
          json['causeAndEffectMatrixProvided'] as bool? ?? false,
      cyberSecurityChecksCompleted:
          json['cyberSecurityChecksCompleted'] as bool? ?? false,
      batteryTestReadings: _parseBatteryReadings(json['batteryTestReadings']),
      arcSignallingTested: json['arcSignallingTested'] as bool? ?? false,
      arcTransmissionTimeMeasuredSeconds:
          json['arcTransmissionTimeMeasuredSeconds'] as int?,
      earthFaultTestPassed: json['earthFaultTestPassed'] as bool? ?? false,
      earthFaultReadingKOhms:
          (json['earthFaultReadingKOhms'] as num?)?.toDouble(),
      declaration: InspectionDeclaration.fromString(
          json['declaration'] as String?),
      declarationNotes: json['declarationNotes'] as String?,
      nextServiceDueDate: jsonDateOptional(json['nextServiceDueDate']),
      engineerSignatureBase64: json['engineerSignatureBase64'] as String?,
      responsiblePersonSignatureBase64:
          json['responsiblePersonSignatureBase64'] as String?,
      responsiblePersonSignedName:
          json['responsiblePersonSignedName'] as String?,
      responsiblePersonSignedAt:
          jsonDateOptional(json['responsiblePersonSignedAt']),
      reportPdfUrl: json['reportPdfUrl'] as String?,
      reportGeneratedAt: jsonDateOptional(json['reportGeneratedAt']),
      jobsheetId: json['jobsheetId'] as String?,
      dispatchedJobId: json['dispatchedJobId'] as String?,
      createdAt: jsonDateRequired(json['createdAt']),
      updatedAt: jsonDateRequired(json['updatedAt']),
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      try {
        return List<String>.from(jsonDecode(value) as List);
      } catch (_) {
        return const [];
      }
    }
    if (value is List) return value.map((e) => e as String).toList();
    return const [];
  }

  static List<BatteryLoadTestReading> _parseBatteryReadings(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      try {
        final list = jsonDecode(value) as List;
        return list
            .map((e) =>
                BatteryLoadTestReading.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [];
      }
    }
    if (value is List) {
      return value
          .map((e) =>
              BatteryLoadTestReading.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  InspectionVisit copyWith({
    String? id,
    String? siteId,
    String? engineerId,
    String? engineerName,
    InspectionVisitType? visitType,
    DateTime? visitDate,
    DateTime? completedAt,
    List<String>? mcpIdsTestedThisVisit,
    bool? allDetectorsTestedThisVisit,
    List<String>? serviceRecordIds,
    bool? logbookReviewed,
    String? logbookReviewNotes,
    bool? zonePlanVerified,
    String? zonePlanVariationNotes,
    bool? causeAndEffectMatrixProvided,
    bool? cyberSecurityChecksCompleted,
    List<BatteryLoadTestReading>? batteryTestReadings,
    bool? arcSignallingTested,
    int? arcTransmissionTimeMeasuredSeconds,
    bool? earthFaultTestPassed,
    double? earthFaultReadingKOhms,
    InspectionDeclaration? declaration,
    String? declarationNotes,
    DateTime? nextServiceDueDate,
    String? engineerSignatureBase64,
    String? responsiblePersonSignatureBase64,
    String? responsiblePersonSignedName,
    DateTime? responsiblePersonSignedAt,
    String? reportPdfUrl,
    DateTime? reportGeneratedAt,
    String? jobsheetId,
    String? dispatchedJobId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return InspectionVisit(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      engineerId: engineerId ?? this.engineerId,
      engineerName: engineerName ?? this.engineerName,
      visitType: visitType ?? this.visitType,
      visitDate: visitDate ?? this.visitDate,
      completedAt: completedAt ?? this.completedAt,
      mcpIdsTestedThisVisit:
          mcpIdsTestedThisVisit ?? this.mcpIdsTestedThisVisit,
      allDetectorsTestedThisVisit:
          allDetectorsTestedThisVisit ?? this.allDetectorsTestedThisVisit,
      serviceRecordIds: serviceRecordIds ?? this.serviceRecordIds,
      logbookReviewed: logbookReviewed ?? this.logbookReviewed,
      logbookReviewNotes: logbookReviewNotes ?? this.logbookReviewNotes,
      zonePlanVerified: zonePlanVerified ?? this.zonePlanVerified,
      zonePlanVariationNotes:
          zonePlanVariationNotes ?? this.zonePlanVariationNotes,
      causeAndEffectMatrixProvided:
          causeAndEffectMatrixProvided ?? this.causeAndEffectMatrixProvided,
      cyberSecurityChecksCompleted:
          cyberSecurityChecksCompleted ?? this.cyberSecurityChecksCompleted,
      batteryTestReadings: batteryTestReadings ?? this.batteryTestReadings,
      arcSignallingTested: arcSignallingTested ?? this.arcSignallingTested,
      arcTransmissionTimeMeasuredSeconds:
          arcTransmissionTimeMeasuredSeconds ??
              this.arcTransmissionTimeMeasuredSeconds,
      earthFaultTestPassed:
          earthFaultTestPassed ?? this.earthFaultTestPassed,
      earthFaultReadingKOhms:
          earthFaultReadingKOhms ?? this.earthFaultReadingKOhms,
      declaration: declaration ?? this.declaration,
      declarationNotes: declarationNotes ?? this.declarationNotes,
      nextServiceDueDate: nextServiceDueDate ?? this.nextServiceDueDate,
      engineerSignatureBase64:
          engineerSignatureBase64 ?? this.engineerSignatureBase64,
      responsiblePersonSignatureBase64:
          responsiblePersonSignatureBase64 ??
              this.responsiblePersonSignatureBase64,
      responsiblePersonSignedName:
          responsiblePersonSignedName ?? this.responsiblePersonSignedName,
      responsiblePersonSignedAt:
          responsiblePersonSignedAt ?? this.responsiblePersonSignedAt,
      reportPdfUrl: reportPdfUrl ?? this.reportPdfUrl,
      reportGeneratedAt: reportGeneratedAt ?? this.reportGeneratedAt,
      jobsheetId: jobsheetId ?? this.jobsheetId,
      dispatchedJobId: dispatchedJobId ?? this.dispatchedJobId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
