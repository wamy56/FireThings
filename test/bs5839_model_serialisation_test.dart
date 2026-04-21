import 'package:flutter_test/flutter_test.dart';
import 'package:firethings/models/bs5839_system_config.dart';
import 'package:firethings/models/inspection_visit.dart';
import 'package:firethings/models/bs5839_variation.dart';
import 'package:firethings/models/cause_effect_test.dart';
import 'package:firethings/models/engineer_competency.dart';
import 'package:firethings/models/logbook_entry.dart';

void main() {
  // ── Bs5839SystemConfig ──────────────────────────────────────

  group('Bs5839SystemConfig serialisation', () {
    late Bs5839SystemConfig config;

    setUp(() {
      config = Bs5839SystemConfig(
        id: 'cfg-1',
        siteId: 'site-1',
        category: Bs5839SystemCategory.l2,
        categoryJustification: 'Risk assessment outcome',
        responsiblePersonName: 'John Smith',
        responsiblePersonRole: 'Building Manager',
        responsiblePersonEmail: 'john@example.com',
        responsiblePersonPhone: '07700 900000',
        originalCommissionDate: DateTime(2020, 6, 15),
        lastModificationDate: DateTime(2025, 1, 10),
        arcConnected: true,
        arcTransmissionMethod: ArcTransmissionMethod.ip,
        arcProvider: 'Securitas',
        arcAccountRef: 'ACC-123',
        arcMaxTransmissionTimeSeconds: 60,
        zonePlanUrl: 'https://example.com/plan.png',
        zonePlanLastReviewedAt: DateTime(2025, 3, 1),
        hasSleepingAccommodation: true,
        numberOfZones: 4,
        cyberSecurityRequired: true,
        panelMake: 'Advanced',
        panelModel: 'MxPro 5',
        panelSerialNumber: 'SN-12345',
        standardVersion: 'BS 5839-1:2025',
        createdAt: DateTime(2025, 4, 1, 10, 30),
        updatedAt: DateTime(2025, 4, 2, 14, 0),
        createdBy: 'eng-1',
        updatedBy: 'eng-2',
      );
    });

    test('round-trips with all fields populated', () {
      final json = config.toJson();
      final restored = Bs5839SystemConfig.fromJson(json);

      expect(restored.id, config.id);
      expect(restored.siteId, config.siteId);
      expect(restored.category, Bs5839SystemCategory.l2);
      expect(restored.categoryJustification, 'Risk assessment outcome');
      expect(restored.responsiblePersonName, 'John Smith');
      expect(restored.responsiblePersonRole, 'Building Manager');
      expect(restored.responsiblePersonEmail, 'john@example.com');
      expect(restored.responsiblePersonPhone, '07700 900000');
      expect(restored.originalCommissionDate, DateTime(2020, 6, 15));
      expect(restored.lastModificationDate, DateTime(2025, 1, 10));
      expect(restored.arcConnected, isTrue);
      expect(restored.arcTransmissionMethod, ArcTransmissionMethod.ip);
      expect(restored.arcProvider, 'Securitas');
      expect(restored.arcAccountRef, 'ACC-123');
      expect(restored.arcMaxTransmissionTimeSeconds, 60);
      expect(restored.zonePlanUrl, 'https://example.com/plan.png');
      expect(restored.zonePlanLastReviewedAt, DateTime(2025, 3, 1));
      expect(restored.hasSleepingAccommodation, isTrue);
      expect(restored.numberOfZones, 4);
      expect(restored.cyberSecurityRequired, isTrue);
      expect(restored.panelMake, 'Advanced');
      expect(restored.panelModel, 'MxPro 5');
      expect(restored.panelSerialNumber, 'SN-12345');
      expect(restored.standardVersion, 'BS 5839-1:2025');
      expect(restored.createdBy, 'eng-1');
      expect(restored.updatedBy, 'eng-2');
    });

    test('round-trips with minimal fields (defaults)', () {
      final minimal = Bs5839SystemConfig(
        id: 'cfg-min',
        siteId: 'site-min',
        category: Bs5839SystemCategory.m,
        responsiblePersonName: 'Jane',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
        createdBy: 'eng',
        updatedBy: 'eng',
      );
      final restored = Bs5839SystemConfig.fromJson(minimal.toJson());

      expect(restored.arcConnected, isFalse);
      expect(restored.arcTransmissionMethod, ArcTransmissionMethod.none);
      expect(restored.hasSleepingAccommodation, isFalse);
      expect(restored.numberOfZones, 1);
      expect(restored.cyberSecurityRequired, isFalse);
      expect(restored.standardVersion, 'BS 5839-1:2025');
      expect(restored.categoryJustification, isNull);
      expect(restored.originalCommissionDate, isNull);
      expect(restored.panelMake, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      final updated = config.copyWith(category: Bs5839SystemCategory.p1);
      expect(updated.category, Bs5839SystemCategory.p1);
      expect(updated.responsiblePersonName, config.responsiblePersonName);
      expect(updated.arcConnected, config.arcConnected);
      expect(updated.numberOfZones, config.numberOfZones);
    });

    test('enum fromString handles unknown values', () {
      expect(Bs5839SystemCategory.fromString('unknown'),
          Bs5839SystemCategory.l1);
      expect(Bs5839SystemCategory.fromString(null), Bs5839SystemCategory.l1);
      expect(ArcTransmissionMethod.fromString('bogus'),
          ArcTransmissionMethod.none);
      expect(ArcTransmissionMethod.fromString(null),
          ArcTransmissionMethod.none);
    });
  });

  // ── InspectionVisit ─────────────────────────────────────────

  group('InspectionVisit serialisation', () {
    late InspectionVisit visit;

    setUp(() {
      visit = InspectionVisit(
        id: 'visit-1',
        siteId: 'site-1',
        engineerId: 'eng-1',
        engineerName: 'Alice Jones',
        visitType: InspectionVisitType.routineService,
        visitDate: DateTime(2025, 4, 15),
        completedAt: DateTime(2025, 4, 15, 17, 0),
        mcpIdsTestedThisVisit: ['mcp-1', 'mcp-2'],
        allDetectorsTestedThisVisit: true,
        serviceRecordIds: ['sr-1', 'sr-2', 'sr-3'],
        logbookReviewed: true,
        logbookReviewNotes: 'All entries accounted for',
        zonePlanVerified: true,
        causeAndEffectMatrixProvided: true,
        cyberSecurityChecksCompleted: false,
        batteryTestReadings: [
          BatteryLoadTestReading(
            powerSupplyAssetId: 'psu-1',
            restingVoltage: 27.4,
            loadedVoltage: 25.1,
            loadCurrentAmps: 3.5,
            passed: true,
            notes: 'Within tolerance',
          ),
        ],
        arcSignallingTested: true,
        arcTransmissionTimeMeasuredSeconds: 45,
        earthFaultTestPassed: true,
        earthFaultReadingKOhms: 150.5,
        declaration: InspectionDeclaration.satisfactory,
        declarationNotes: 'System in good order',
        nextServiceDueDate: DateTime(2025, 10, 15),
        engineerSignatureBase64: 'base64sig==',
        responsiblePersonSignatureBase64: 'base64rp==',
        responsiblePersonSignedName: 'Bob Manager',
        responsiblePersonSignedAt: DateTime(2025, 4, 15, 17, 30),
        reportPdfUrl: 'https://example.com/report.pdf',
        reportGeneratedAt: DateTime(2025, 4, 15, 18, 0),
        jobsheetId: 'js-1',
        dispatchedJobId: 'dj-1',
        createdAt: DateTime(2025, 4, 15, 9, 0),
        updatedAt: DateTime(2025, 4, 15, 18, 0),
      );
    });

    test('round-trips with all fields populated', () {
      final json = visit.toJson();
      final restored = InspectionVisit.fromJson(json);

      expect(restored.id, visit.id);
      expect(restored.engineerName, 'Alice Jones');
      expect(restored.visitType, InspectionVisitType.routineService);
      expect(restored.mcpIdsTestedThisVisit, ['mcp-1', 'mcp-2']);
      expect(restored.allDetectorsTestedThisVisit, isTrue);
      expect(restored.serviceRecordIds, hasLength(3));
      expect(restored.logbookReviewed, isTrue);
      expect(restored.logbookReviewNotes, 'All entries accounted for');
      expect(restored.zonePlanVerified, isTrue);
      expect(restored.causeAndEffectMatrixProvided, isTrue);
      expect(restored.batteryTestReadings, hasLength(1));
      expect(restored.batteryTestReadings.first.restingVoltage, 27.4);
      expect(restored.batteryTestReadings.first.loadedVoltage, 25.1);
      expect(restored.batteryTestReadings.first.loadCurrentAmps, 3.5);
      expect(restored.batteryTestReadings.first.passed, isTrue);
      expect(restored.arcSignallingTested, isTrue);
      expect(restored.arcTransmissionTimeMeasuredSeconds, 45);
      expect(restored.earthFaultTestPassed, isTrue);
      expect(restored.earthFaultReadingKOhms, 150.5);
      expect(restored.declaration, InspectionDeclaration.satisfactory);
      expect(restored.declarationNotes, 'System in good order');
      expect(restored.engineerSignatureBase64, 'base64sig==');
      expect(
          restored.responsiblePersonSignedName, 'Bob Manager');
      expect(restored.reportPdfUrl, 'https://example.com/report.pdf');
      expect(restored.jobsheetId, 'js-1');
      expect(restored.dispatchedJobId, 'dj-1');
    });

    test('round-trips with minimal fields (defaults)', () {
      final minimal = InspectionVisit(
        id: 'visit-min',
        siteId: 'site-1',
        engineerId: 'eng-1',
        engineerName: 'Bob',
        visitType: InspectionVisitType.commissioning,
        visitDate: DateTime(2025, 1, 1),
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final restored = InspectionVisit.fromJson(minimal.toJson());

      expect(restored.completedAt, isNull);
      expect(restored.mcpIdsTestedThisVisit, isEmpty);
      expect(restored.allDetectorsTestedThisVisit, isFalse);
      expect(restored.serviceRecordIds, isEmpty);
      expect(restored.logbookReviewed, isFalse);
      expect(restored.batteryTestReadings, isEmpty);
      expect(restored.declaration, InspectionDeclaration.notDeclared);
      expect(restored.jobsheetId, isNull);
      expect(restored.dispatchedJobId, isNull);
    });

    test('BatteryLoadTestReading round-trips', () {
      final reading = BatteryLoadTestReading(
        powerSupplyAssetId: 'psu-2',
        restingVoltage: 28.0,
        loadedVoltage: 24.8,
        passed: false,
        notes: 'Below threshold',
      );
      final restored = BatteryLoadTestReading.fromJson(reading.toJson());

      expect(restored.powerSupplyAssetId, 'psu-2');
      expect(restored.restingVoltage, 28.0);
      expect(restored.loadedVoltage, 24.8);
      expect(restored.loadCurrentAmps, isNull);
      expect(restored.passed, isFalse);
      expect(restored.notes, 'Below threshold');
    });

    test('copyWith preserves unmodified fields', () {
      final updated = visit.copyWith(
          declaration: InspectionDeclaration.unsatisfactory);
      expect(updated.declaration, InspectionDeclaration.unsatisfactory);
      expect(updated.engineerName, visit.engineerName);
      expect(updated.batteryTestReadings, hasLength(1));
    });
  });

  // ── Bs5839Variation ─────────────────────────────────────────

  group('Bs5839Variation serialisation', () {
    late Bs5839Variation variation;

    setUp(() {
      variation = Bs5839Variation(
        id: 'var-1',
        siteId: 'site-1',
        clauseReference: '6.6a',
        description: 'No zone plan on multi-zone sleeping site',
        justification: 'Plan being prepared by architect',
        isProhibited: true,
        prohibitedRuleId: 'no_zone_plan_multi_zone_sleeping',
        status: VariationStatus.active,
        agreedByName: 'Jane Manager',
        agreedByRole: 'Fire Safety Manager',
        dateAgreed: DateTime(2025, 3, 1),
        loggedByEngineerId: 'eng-1',
        loggedByEngineerName: 'Alice Jones',
        loggedAt: DateTime(2025, 3, 1, 14, 0),
        rectifiedAt: null,
        rectifiedByVisitId: null,
        evidencePhotoUrls: ['https://example.com/photo1.jpg'],
      );
    });

    test('round-trips with all fields populated', () {
      final restored = Bs5839Variation.fromJson(variation.toJson());

      expect(restored.id, 'var-1');
      expect(restored.clauseReference, '6.6a');
      expect(restored.description, contains('zone plan'));
      expect(restored.isProhibited, isTrue);
      expect(restored.prohibitedRuleId, 'no_zone_plan_multi_zone_sleeping');
      expect(restored.status, VariationStatus.active);
      expect(restored.agreedByName, 'Jane Manager');
      expect(restored.agreedByRole, 'Fire Safety Manager');
      expect(restored.dateAgreed, DateTime(2025, 3, 1));
      expect(restored.loggedByEngineerId, 'eng-1');
      expect(restored.loggedByEngineerName, 'Alice Jones');
      expect(restored.evidencePhotoUrls, hasLength(1));
    });

    test('round-trips with minimal fields', () {
      final minimal = Bs5839Variation(
        id: 'var-min',
        siteId: 'site-1',
        clauseReference: '25.4',
        description: 'Test variation',
        justification: 'Justified',
        loggedAt: DateTime(2025, 1, 1),
      );
      final restored = Bs5839Variation.fromJson(minimal.toJson());

      expect(restored.isProhibited, isFalse);
      expect(restored.status, VariationStatus.active);
      expect(restored.agreedByName, isNull);
      expect(restored.rectifiedAt, isNull);
      expect(restored.evidencePhotoUrls, isEmpty);
    });

    test('rectified status round-trips', () {
      final rectified = variation.copyWith(
        status: VariationStatus.rectified,
        rectifiedAt: DateTime(2025, 4, 1),
        rectifiedByVisitId: 'visit-2',
      );
      final restored = Bs5839Variation.fromJson(rectified.toJson());

      expect(restored.status, VariationStatus.rectified);
      expect(restored.rectifiedAt, DateTime(2025, 4, 1));
      expect(restored.rectifiedByVisitId, 'visit-2');
    });
  });

  // ── CauseEffectTest ─────────────────────────────────────────

  group('CauseEffectTest serialisation', () {
    late CauseEffectTest ceTest;

    setUp(() {
      ceTest = CauseEffectTest(
        id: 'ce-1',
        siteId: 'site-1',
        visitId: 'visit-1',
        triggerAssetId: 'mcp-1',
        triggerAssetReference: 'MCP/GF/01',
        triggerDescription: 'Ground floor MCP activation',
        expectedEffects: [
          ExpectedEffect(
            id: 'eff-1',
            effectType: EffectType.sounderActivation,
            targetDescription: 'All sounders',
            expectedBehaviour: 'Evacuate tone on all floors',
            actualBehaviour: 'Evacuate tone confirmed',
            measuredTimeSeconds: 2,
            passed: true,
          ),
          ExpectedEffect(
            id: 'eff-2',
            effectType: EffectType.arcSignalFire,
            targetDescription: 'ARC',
            expectedBehaviour: 'Fire signal transmitted',
            actualBehaviour: 'Signal received in 45s',
            measuredTimeSeconds: 45,
            passed: true,
          ),
          ExpectedEffect(
            id: 'eff-3',
            effectType: EffectType.doorHoldOpenRelease,
            targetAssetId: 'door-1',
            targetDescription: 'Corridor fire door',
            expectedBehaviour: 'Door releases and closes',
            actualBehaviour: null,
            passed: false,
            notes: 'Door stuck — closer mechanism faulty',
          ),
        ],
        testedAt: DateTime(2025, 4, 15, 14, 0),
        testedByEngineerId: 'eng-1',
        testedByEngineerName: 'Alice Jones',
        overallPassed: false,
        notes: 'One door hold-open failed to release',
        evidencePhotoUrls: ['https://example.com/ce1.jpg'],
      );
    });

    test('round-trips with nested ExpectedEffects', () {
      final restored = CauseEffectTest.fromJson(ceTest.toJson());

      expect(restored.id, 'ce-1');
      expect(restored.triggerAssetReference, 'MCP/GF/01');
      expect(restored.triggerDescription, 'Ground floor MCP activation');
      expect(restored.expectedEffects, hasLength(3));
      expect(restored.overallPassed, isFalse);
      expect(restored.notes, contains('door hold-open'));
      expect(restored.evidencePhotoUrls, hasLength(1));

      final eff1 = restored.expectedEffects[0];
      expect(eff1.effectType, EffectType.sounderActivation);
      expect(eff1.passed, isTrue);
      expect(eff1.measuredTimeSeconds, 2);

      final eff3 = restored.expectedEffects[2];
      expect(eff3.effectType, EffectType.doorHoldOpenRelease);
      expect(eff3.targetAssetId, 'door-1');
      expect(eff3.passed, isFalse);
      expect(eff3.notes, contains('closer mechanism'));
    });

    test('round-trips with empty effects list', () {
      final empty = CauseEffectTest(
        id: 'ce-empty',
        siteId: 'site-1',
        visitId: 'visit-1',
        triggerAssetId: 'mcp-2',
        triggerAssetReference: 'MCP/FF/01',
        triggerDescription: 'First floor MCP',
        testedAt: DateTime(2025, 1, 1),
        testedByEngineerId: 'eng-1',
        testedByEngineerName: 'Bob',
      );
      final restored = CauseEffectTest.fromJson(empty.toJson());

      expect(restored.expectedEffects, isEmpty);
      expect(restored.overallPassed, isFalse);
      expect(restored.notes, isNull);
      expect(restored.evidencePhotoUrls, isEmpty);
    });

    test('ExpectedEffect copyWith works', () {
      final original = ExpectedEffect(
        id: 'eff-x',
        effectType: EffectType.gasShutoff,
        expectedBehaviour: 'Gas valve closes',
      );
      final updated = original.copyWith(passed: true, actualBehaviour: 'Closed');
      expect(updated.passed, isTrue);
      expect(updated.actualBehaviour, 'Closed');
      expect(updated.effectType, EffectType.gasShutoff);
    });

    test('all EffectType values serialise correctly', () {
      for (final effectType in EffectType.values) {
        final effect = ExpectedEffect(
          id: 'test-${effectType.name}',
          effectType: effectType,
          expectedBehaviour: 'Test',
        );
        final restored = ExpectedEffect.fromJson(effect.toJson());
        expect(restored.effectType, effectType,
            reason: '${effectType.name} failed round-trip');
      }
    });
  });

  // ── EngineerCompetency ──────────────────────────────────────

  group('EngineerCompetency serialisation', () {
    late EngineerCompetency competency;

    setUp(() {
      competency = EngineerCompetency(
        id: 'current',
        engineerId: 'eng-1',
        engineerName: 'Alice Jones',
        qualifications: [
          Qualification(
            id: 'q-1',
            type: QualificationType.fiaUnit3,
            issuingBody: 'FIA',
            issuedDate: DateTime(2023, 6, 1),
            expiryDate: DateTime(2026, 6, 1),
            certificateNumber: 'FIA-2023-001',
            evidenceFileUrl: 'https://example.com/cert.pdf',
          ),
          Qualification(
            id: 'q-2',
            type: QualificationType.other,
            customTypeName: 'Manufacturer Training',
            issuingBody: 'Advanced Electronics',
            issuedDate: DateTime(2024, 1, 15),
          ),
        ],
        cpdRecords: [
          CpdRecord(
            id: 'cpd-1',
            date: DateTime(2025, 2, 10),
            topic: 'BS 5839-1:2025 Changes',
            hours: 8.0,
            provider: 'FIA',
            notes: 'Full day course',
          ),
          CpdRecord(
            id: 'cpd-2',
            date: DateTime(2025, 3, 5),
            topic: 'Cyber Security for Fire Systems',
            hours: 4.0,
          ),
        ],
        totalCpdHoursLast12Months: 12.0,
        lastReviewedAt: DateTime(2025, 4, 1),
        createdAt: DateTime(2023, 1, 1),
        updatedAt: DateTime(2025, 4, 1),
      );
    });

    test('round-trips with qualifications and CPD records', () {
      final restored = EngineerCompetency.fromJson(competency.toJson());

      expect(restored.id, 'current');
      expect(restored.engineerName, 'Alice Jones');
      expect(restored.qualifications, hasLength(2));
      expect(restored.cpdRecords, hasLength(2));
      expect(restored.totalCpdHoursLast12Months, 12.0);
      expect(restored.lastReviewedAt, DateTime(2025, 4, 1));

      final q1 = restored.qualifications[0];
      expect(q1.type, QualificationType.fiaUnit3);
      expect(q1.issuingBody, 'FIA');
      expect(q1.expiryDate, DateTime(2026, 6, 1));
      expect(q1.certificateNumber, 'FIA-2023-001');

      final q2 = restored.qualifications[1];
      expect(q2.type, QualificationType.other);
      expect(q2.customTypeName, 'Manufacturer Training');
      expect(q2.expiryDate, isNull);

      final cpd1 = restored.cpdRecords[0];
      expect(cpd1.topic, 'BS 5839-1:2025 Changes');
      expect(cpd1.hours, 8.0);
      expect(cpd1.provider, 'FIA');
      expect(cpd1.notes, 'Full day course');

      final cpd2 = restored.cpdRecords[1];
      expect(cpd2.provider, isNull);
      expect(cpd2.notes, isNull);
    });

    test('round-trips with empty qualifications and CPD', () {
      final empty = EngineerCompetency(
        id: 'current',
        engineerId: 'eng-new',
        engineerName: 'New Engineer',
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2025, 1, 1),
      );
      final restored = EngineerCompetency.fromJson(empty.toJson());

      expect(restored.qualifications, isEmpty);
      expect(restored.cpdRecords, isEmpty);
      expect(restored.totalCpdHoursLast12Months, 0.0);
      expect(restored.lastReviewedAt, isNull);
    });

    test('all QualificationType values serialise correctly', () {
      for (final qt in QualificationType.values) {
        final qual = Qualification(
          id: 'test-${qt.name}',
          type: qt,
          issuingBody: 'Test',
          issuedDate: DateTime(2025, 1, 1),
        );
        final restored = Qualification.fromJson(qual.toJson());
        expect(restored.type, qt,
            reason: '${qt.name} failed round-trip');
      }
    });

    test('Qualification copyWith works', () {
      final q = competency.qualifications[0];
      final updated =
          q.copyWith(expiryDate: DateTime(2027, 6, 1));
      expect(updated.expiryDate, DateTime(2027, 6, 1));
      expect(updated.type, q.type);
      expect(updated.certificateNumber, q.certificateNumber);
    });

    test('CpdRecord copyWith works', () {
      final r = competency.cpdRecords[0];
      final updated = r.copyWith(hours: 16.0);
      expect(updated.hours, 16.0);
      expect(updated.topic, r.topic);
      expect(updated.provider, r.provider);
    });
  });

  // ── LogbookEntry ────────────────────────────────────────────

  group('LogbookEntry serialisation', () {
    test('round-trips with all fields populated', () {
      final entry = LogbookEntry(
        id: 'log-1',
        siteId: 'site-1',
        type: LogbookEntryType.falseAlarm,
        occurredAt: DateTime(2025, 4, 10, 3, 15),
        description: 'False alarm from kitchen smoke detector',
        zoneOrDeviceReference: 'Zone 3 / SD-K-01',
        cause: 'Cooking fumes',
        actionTaken: 'Reset panel, advised on detector placement',
        loggedByName: 'Night security',
        loggedByRole: 'Security Staff',
        visitId: 'visit-1',
        createdAt: DateTime(2025, 4, 10, 8, 0),
      );
      final restored = LogbookEntry.fromJson(entry.toJson());

      expect(restored.id, 'log-1');
      expect(restored.type, LogbookEntryType.falseAlarm);
      expect(restored.description, contains('kitchen'));
      expect(restored.zoneOrDeviceReference, 'Zone 3 / SD-K-01');
      expect(restored.cause, 'Cooking fumes');
      expect(restored.actionTaken, contains('Reset panel'));
      expect(restored.loggedByName, 'Night security');
      expect(restored.loggedByRole, 'Security Staff');
      expect(restored.visitId, 'visit-1');
    });

    test('round-trips with minimal fields', () {
      final minimal = LogbookEntry(
        id: 'log-min',
        siteId: 'site-1',
        type: LogbookEntryType.other,
        occurredAt: DateTime(2025, 1, 1),
        description: 'Routine check',
        createdAt: DateTime(2025, 1, 1),
      );
      final restored = LogbookEntry.fromJson(minimal.toJson());

      expect(restored.zoneOrDeviceReference, isNull);
      expect(restored.cause, isNull);
      expect(restored.actionTaken, isNull);
      expect(restored.loggedByName, isNull);
      expect(restored.visitId, isNull);
    });

    test('all LogbookEntryType values serialise correctly', () {
      for (final entryType in LogbookEntryType.values) {
        final entry = LogbookEntry(
          id: 'test-${entryType.name}',
          siteId: 'site-1',
          type: entryType,
          occurredAt: DateTime(2025, 1, 1),
          description: 'Test',
          createdAt: DateTime(2025, 1, 1),
        );
        final restored = LogbookEntry.fromJson(entry.toJson());
        expect(restored.type, entryType,
            reason: '${entryType.name} failed round-trip');
      }
    });

    test('copyWith works', () {
      final entry = LogbookEntry(
        id: 'log-cw',
        siteId: 'site-1',
        type: LogbookEntryType.systemFault,
        occurredAt: DateTime(2025, 1, 1),
        description: 'Zone 2 fault',
        createdAt: DateTime(2025, 1, 1),
      );
      final updated = entry.copyWith(
        actionTaken: 'Replaced sounder base',
      );
      expect(updated.actionTaken, 'Replaced sounder base');
      expect(updated.type, LogbookEntryType.systemFault);
      expect(updated.description, 'Zone 2 fault');
    });
  });

  // ── InspectionVisit enum coverage ───────────────────────────

  group('InspectionVisit enums', () {
    test('all InspectionVisitType values serialise correctly', () {
      for (final vt in InspectionVisitType.values) {
        final visit = InspectionVisit(
          id: 'test-${vt.name}',
          siteId: 'site-1',
          engineerId: 'eng-1',
          engineerName: 'Test',
          visitType: vt,
          visitDate: DateTime(2025, 1, 1),
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );
        final restored = InspectionVisit.fromJson(visit.toJson());
        expect(restored.visitType, vt,
            reason: '${vt.name} failed round-trip');
      }
    });

    test('all InspectionDeclaration values serialise correctly', () {
      for (final d in InspectionDeclaration.values) {
        final visit = InspectionVisit(
          id: 'test-${d.name}',
          siteId: 'site-1',
          engineerId: 'eng-1',
          engineerName: 'Test',
          visitType: InspectionVisitType.routineService,
          visitDate: DateTime(2025, 1, 1),
          declaration: d,
          createdAt: DateTime(2025, 1, 1),
          updatedAt: DateTime(2025, 1, 1),
        );
        final restored = InspectionVisit.fromJson(visit.toJson());
        expect(restored.declaration, d,
            reason: '${d.name} failed round-trip');
      }
    });
  });

  // ── Bs5839Variation enum coverage ───────────────────────────

  group('Bs5839Variation enums', () {
    test('all VariationStatus values serialise correctly', () {
      for (final s in VariationStatus.values) {
        final v = Bs5839Variation(
          id: 'test-${s.name}',
          siteId: 'site-1',
          clauseReference: '6.6',
          description: 'Test',
          justification: 'Test',
          status: s,
          loggedAt: DateTime(2025, 1, 1),
        );
        final restored = Bs5839Variation.fromJson(v.toJson());
        expect(restored.status, s,
            reason: '${s.name} failed round-trip');
      }
    });
  });
}
