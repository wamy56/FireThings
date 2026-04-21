import 'dart:convert';

import '../utils/json_helpers.dart';

enum EffectType {
  sounderActivation,
  beaconActivation,
  voiceAlarmMessage,
  aovOpen,
  doorHoldOpenRelease,
  liftHomingGroundFloor,
  liftHomingOtherFloor,
  gasShutoff,
  ventilationShutdown,
  arcSignalFire,
  arcSignalFault,
  arcSignalPreAlarm,
  bmsSignal,
  sprinklerRelease,
  smokeCurtainDeploy,
  otherInterface;

  String get displayLabel {
    switch (this) {
      case EffectType.sounderActivation:
        return 'Sounder Activation';
      case EffectType.beaconActivation:
        return 'Beacon Activation';
      case EffectType.voiceAlarmMessage:
        return 'Voice Alarm Message';
      case EffectType.aovOpen:
        return 'AOV Open';
      case EffectType.doorHoldOpenRelease:
        return 'Door Hold-Open Release';
      case EffectType.liftHomingGroundFloor:
        return 'Lift Homing (Ground Floor)';
      case EffectType.liftHomingOtherFloor:
        return 'Lift Homing (Other Floor)';
      case EffectType.gasShutoff:
        return 'Gas Shutoff';
      case EffectType.ventilationShutdown:
        return 'Ventilation Shutdown';
      case EffectType.arcSignalFire:
        return 'ARC Signal — Fire';
      case EffectType.arcSignalFault:
        return 'ARC Signal — Fault';
      case EffectType.arcSignalPreAlarm:
        return 'ARC Signal — Pre-Alarm';
      case EffectType.bmsSignal:
        return 'BMS Signal';
      case EffectType.sprinklerRelease:
        return 'Sprinkler Release';
      case EffectType.smokeCurtainDeploy:
        return 'Smoke Curtain Deploy';
      case EffectType.otherInterface:
        return 'Other Interface';
    }
  }

  static EffectType fromString(String? value) {
    if (value == null) return EffectType.otherInterface;
    for (final e in EffectType.values) {
      if (e.name == value) return e;
    }
    return EffectType.otherInterface;
  }
}

class ExpectedEffect {
  final String id;
  final EffectType effectType;
  final String? targetAssetId;
  final String? targetDescription;
  final String expectedBehaviour;
  final String? actualBehaviour;
  final int? measuredTimeSeconds;
  final bool passed;
  final String? notes;

  ExpectedEffect({
    required this.id,
    required this.effectType,
    this.targetAssetId,
    this.targetDescription,
    required this.expectedBehaviour,
    this.actualBehaviour,
    this.measuredTimeSeconds,
    this.passed = false,
    this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'effectType': effectType.name,
      'targetAssetId': targetAssetId,
      'targetDescription': targetDescription,
      'expectedBehaviour': expectedBehaviour,
      'actualBehaviour': actualBehaviour,
      'measuredTimeSeconds': measuredTimeSeconds,
      'passed': passed,
      'notes': notes,
    };
  }

  factory ExpectedEffect.fromJson(Map<String, dynamic> json) {
    return ExpectedEffect(
      id: json['id'] as String,
      effectType: EffectType.fromString(json['effectType'] as String?),
      targetAssetId: json['targetAssetId'] as String?,
      targetDescription: json['targetDescription'] as String?,
      expectedBehaviour: json['expectedBehaviour'] as String? ?? '',
      actualBehaviour: json['actualBehaviour'] as String?,
      measuredTimeSeconds: json['measuredTimeSeconds'] as int?,
      passed: json['passed'] as bool? ?? false,
      notes: json['notes'] as String?,
    );
  }

  ExpectedEffect copyWith({
    String? id,
    EffectType? effectType,
    String? targetAssetId,
    String? targetDescription,
    String? expectedBehaviour,
    String? actualBehaviour,
    int? measuredTimeSeconds,
    bool? passed,
    String? notes,
  }) {
    return ExpectedEffect(
      id: id ?? this.id,
      effectType: effectType ?? this.effectType,
      targetAssetId: targetAssetId ?? this.targetAssetId,
      targetDescription: targetDescription ?? this.targetDescription,
      expectedBehaviour: expectedBehaviour ?? this.expectedBehaviour,
      actualBehaviour: actualBehaviour ?? this.actualBehaviour,
      measuredTimeSeconds: measuredTimeSeconds ?? this.measuredTimeSeconds,
      passed: passed ?? this.passed,
      notes: notes ?? this.notes,
    );
  }
}

class CauseEffectTest {
  final String id;
  final String siteId;
  final String visitId;
  final String triggerAssetId;
  final String triggerAssetReference;
  final String triggerDescription;
  final List<ExpectedEffect> expectedEffects;
  final DateTime testedAt;
  final String testedByEngineerId;
  final String testedByEngineerName;
  final bool overallPassed;
  final String? notes;
  final List<String> evidencePhotoUrls;

  CauseEffectTest({
    required this.id,
    required this.siteId,
    required this.visitId,
    required this.triggerAssetId,
    required this.triggerAssetReference,
    required this.triggerDescription,
    this.expectedEffects = const [],
    required this.testedAt,
    required this.testedByEngineerId,
    required this.testedByEngineerName,
    this.overallPassed = false,
    this.notes,
    this.evidencePhotoUrls = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'siteId': siteId,
      'visitId': visitId,
      'triggerAssetId': triggerAssetId,
      'triggerAssetReference': triggerAssetReference,
      'triggerDescription': triggerDescription,
      'expectedEffects':
          expectedEffects.map((e) => e.toJson()).toList(),
      'testedAt': testedAt.toIso8601String(),
      'testedByEngineerId': testedByEngineerId,
      'testedByEngineerName': testedByEngineerName,
      'overallPassed': overallPassed,
      'notes': notes,
      'evidencePhotoUrls': evidencePhotoUrls,
    };
  }

  factory CauseEffectTest.fromJson(Map<String, dynamic> json) {
    return CauseEffectTest(
      id: json['id'] as String,
      siteId: json['siteId'] as String,
      visitId: json['visitId'] as String,
      triggerAssetId: json['triggerAssetId'] as String,
      triggerAssetReference: json['triggerAssetReference'] as String? ?? '',
      triggerDescription: json['triggerDescription'] as String? ?? '',
      expectedEffects: _parseEffects(json['expectedEffects']),
      testedAt: jsonDateRequired(json['testedAt']),
      testedByEngineerId: json['testedByEngineerId'] as String,
      testedByEngineerName: json['testedByEngineerName'] as String,
      overallPassed: json['overallPassed'] as bool? ?? false,
      notes: json['notes'] as String?,
      evidencePhotoUrls: _parsePhotoUrls(json['evidencePhotoUrls']),
    );
  }

  static List<ExpectedEffect> _parseEffects(dynamic value) {
    if (value == null) return const [];
    if (value is String) {
      try {
        final list = jsonDecode(value) as List;
        return list
            .map((e) => ExpectedEffect.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return const [];
      }
    }
    if (value is List) {
      return value
          .map((e) => ExpectedEffect.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return const [];
  }

  static List<String> _parsePhotoUrls(dynamic value) {
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

  CauseEffectTest copyWith({
    String? id,
    String? siteId,
    String? visitId,
    String? triggerAssetId,
    String? triggerAssetReference,
    String? triggerDescription,
    List<ExpectedEffect>? expectedEffects,
    DateTime? testedAt,
    String? testedByEngineerId,
    String? testedByEngineerName,
    bool? overallPassed,
    String? notes,
    List<String>? evidencePhotoUrls,
  }) {
    return CauseEffectTest(
      id: id ?? this.id,
      siteId: siteId ?? this.siteId,
      visitId: visitId ?? this.visitId,
      triggerAssetId: triggerAssetId ?? this.triggerAssetId,
      triggerAssetReference:
          triggerAssetReference ?? this.triggerAssetReference,
      triggerDescription: triggerDescription ?? this.triggerDescription,
      expectedEffects: expectedEffects ?? this.expectedEffects,
      testedAt: testedAt ?? this.testedAt,
      testedByEngineerId: testedByEngineerId ?? this.testedByEngineerId,
      testedByEngineerName:
          testedByEngineerName ?? this.testedByEngineerName,
      overallPassed: overallPassed ?? this.overallPassed,
      notes: notes ?? this.notes,
      evidencePhotoUrls: evidencePhotoUrls ?? this.evidencePhotoUrls,
    );
  }
}
