import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show DateUtils;

import '../data/prohibited_variation_rules.dart';
import '../models/asset.dart';
import '../models/bs5839_system_config.dart';
import '../models/bs5839_variation.dart';
import '../models/engineer_competency.dart';
import '../models/inspection_visit.dart';
import '../models/prohibited_variation_rule.dart';
import '../models/service_record.dart';
import '../services/remote_config_service.dart';

class ComplianceIssue {
  final String code;
  final String description;
  final String? clauseReference;
  final ComplianceIssueSeverity severity;

  const ComplianceIssue({
    required this.code,
    required this.description,
    this.clauseReference,
    required this.severity,
  });
}

enum ComplianceIssueSeverity { critical, warning, info }

class McpRotationStatus {
  final int totalMcps;
  final int testedThisVisit;
  final int testedInLast12Months;
  final List<String> mcpIdsNotTestedInLast12Months;
  final bool allCoveredInLast12Months;
  final double rollingPercentageThisQuarter;

  const McpRotationStatus({
    required this.totalMcps,
    required this.testedThisVisit,
    required this.testedInLast12Months,
    required this.mcpIdsNotTestedInLast12Months,
    required this.allCoveredInLast12Months,
    required this.rollingPercentageThisQuarter,
  });
}

class ProhibitedVariationFinding {
  final ProhibitedVariationRule rule;
  final String description;

  const ProhibitedVariationFinding({
    required this.rule,
    required this.description,
  });
}

class Bs5839ComplianceService {
  Bs5839ComplianceService._();
  static final Bs5839ComplianceService instance = Bs5839ComplianceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _assetsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/assets');
  }

  CollectionReference<Map<String, dynamic>> _variationsCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/variations');
  }

  CollectionReference<Map<String, dynamic>> _serviceHistoryCol(
      String basePath, String siteId) {
    return _firestore.collection('$basePath/sites/$siteId/service_history');
  }

  DocumentReference<Map<String, dynamic>> _configDoc(
      String basePath, String siteId) {
    return _firestore.doc('$basePath/sites/$siteId/bs5839_config/current');
  }

  DocumentReference<Map<String, dynamic>> _visitDoc(
      String basePath, String siteId, String visitId) {
    return _firestore
        .doc('$basePath/sites/$siteId/inspection_visits/$visitId');
  }

  // ─── Prohibited Variation Detection ─────────────────────────

  Future<List<ProhibitedVariationFinding>> detectProhibitedVariations({
    required String basePath,
    required String siteId,
    Bs5839SystemConfig? config,
    List<Asset>? assets,
  }) async {
    final siteConfig = config ??
        await _configDoc(basePath, siteId).get().then((snap) {
          if (!snap.exists || snap.data() == null) return null;
          return Bs5839SystemConfig.fromJson(snap.data()!);
        });

    if (siteConfig == null) return [];

    final List<Asset> siteAssets = assets ??
        await _assetsCol(basePath, siteId).get().then((snap) => snap.docs
            .map((d) {
              try {
                return Asset.fromJson(d.data());
              } catch (_) {
                return null;
              }
            })
            .whereType<Asset>()
            .toList());

    final findings = <ProhibitedVariationFinding>[];

    for (final rule in ProhibitedVariationRules.all) {
      if (!rule.check(siteConfig, siteAssets)) {
        findings.add(ProhibitedVariationFinding(
          rule: rule,
          description: rule.description,
        ));
      }
    }

    return findings;
  }

  // ─── Site Compliance Validation ─────────────────────────────

  Future<List<ComplianceIssue>> validateSiteCompliance({
    required String basePath,
    required String siteId,
    required Bs5839SystemConfig config,
    required List<Asset> assets,
    required List<Bs5839Variation> existingVariations,
  }) async {
    final issues = <ComplianceIssue>[];

    final prohibitedFindings = await detectProhibitedVariations(
      basePath: basePath,
      siteId: siteId,
      config: config,
      assets: assets,
    );
    for (final finding in prohibitedFindings) {
      issues.add(ComplianceIssue(
        code: 'PROHIBITED_${finding.rule.id.toUpperCase()}',
        description: finding.description,
        clauseReference: finding.rule.clauseReference,
        severity: ComplianceIssueSeverity.critical,
      ));
    }

    final activeVariations = existingVariations
        .where((v) =>
            !v.isProhibited && v.status == VariationStatus.active)
        .toList();
    for (final v in activeVariations) {
      issues.add(ComplianceIssue(
        code: 'PERMISSIBLE_VARIATION',
        description: v.description,
        clauseReference: v.clauseReference,
        severity: ComplianceIssueSeverity.warning,
      ));
    }

    if (config.zonePlanUrl == null || config.zonePlanUrl!.isEmpty) {
      issues.add(const ComplianceIssue(
        code: 'NO_ZONE_PLAN',
        description: 'No zone plan uploaded for this site',
        clauseReference: '25.2',
        severity: ComplianceIssueSeverity.warning,
      ));
    }

    if (config.arcConnected &&
        (config.arcProvider == null || config.arcProvider!.isEmpty)) {
      issues.add(const ComplianceIssue(
        code: 'ARC_PROVIDER_MISSING',
        description: 'ARC connection enabled but provider not specified',
        clauseReference: '25.5',
        severity: ComplianceIssueSeverity.info,
      ));
    }

    if (config.cyberSecurityRequired) {
      final hasRemoteAccessAssets =
          assets.any((a) => a.hasRemoteAccess);
      if (hasRemoteAccessAssets) {
        issues.add(const ComplianceIssue(
          code: 'CYBER_SECURITY_REQUIRED',
          description:
              'Assets with remote access detected — cyber security checks required during visits',
          clauseReference: '46',
          severity: ComplianceIssueSeverity.info,
        ));
      }
    }

    return issues;
  }

  // ─── Declaration Calculation ─────────────────────────────────

  Future<InspectionDeclaration> calculateDeclaration({
    required String basePath,
    required String siteId,
    required String visitId,
  }) async {
    final visitSnap =
        await _visitDoc(basePath, siteId, visitId).get();
    if (!visitSnap.exists || visitSnap.data() == null) {
      return InspectionDeclaration.notDeclared;
    }
    final visit = InspectionVisit.fromJson(visitSnap.data()!);

    final configSnap = await _configDoc(basePath, siteId).get();
    Bs5839SystemConfig? config;
    if (configSnap.exists && configSnap.data() != null) {
      config = Bs5839SystemConfig.fromJson(configSnap.data()!);
    }

    final variationsSnap = await _variationsCol(basePath, siteId)
        .where('status', isEqualTo: 'active')
        .get();
    final variations = variationsSnap.docs
        .map((d) {
          try {
            return Bs5839Variation.fromJson(d.data());
          } catch (_) {
            return null;
          }
        })
        .whereType<Bs5839Variation>()
        .toList();

    // 1. Any prohibited variation → unsatisfactory
    if (variations.any(
        (v) => v.isProhibited && v.status == VariationStatus.active)) {
      return InspectionDeclaration.unsatisfactory;
    }

    // 2. Critical failures in service records for this visit → unsatisfactory
    final serviceSnap = await _serviceHistoryCol(basePath, siteId)
        .where('visitId', isEqualTo: visitId)
        .get();
    final serviceRecords = serviceSnap.docs
        .map((d) {
          try {
            return ServiceRecord.fromJson(d.data());
          } catch (_) {
            return null;
          }
        })
        .whereType<ServiceRecord>()
        .toList();

    final hasCriticalFailures = serviceRecords.any(
        (r) => r.overallResult == 'fail' && r.defectSeverity == 'critical');
    if (hasCriticalFailures) {
      return InspectionDeclaration.unsatisfactory;
    }

    // 3. MCP rotation incomplete → satisfactoryWithVariations
    if (config != null) {
      final mcpStatus = await getMcpRotationStatus(
        basePath: basePath,
        siteId: siteId,
      );
      if (!mcpStatus.allCoveredInLast12Months && mcpStatus.totalMcps > 0) {
        return InspectionDeclaration.satisfactoryWithVariations;
      }
    }

    // 4. Logbook not reviewed → satisfactoryWithVariations
    if (!visit.logbookReviewed) {
      return InspectionDeclaration.satisfactoryWithVariations;
    }

    // 5. Commissioning without cause & effect matrix → satisfactoryWithVariations
    if (visit.visitType == InspectionVisitType.commissioning &&
        !visit.causeAndEffectMatrixProvided) {
      return InspectionDeclaration.satisfactoryWithVariations;
    }

    // 6. Permissible variations exist → satisfactoryWithVariations
    if (variations.any(
        (v) => !v.isProhibited && v.status == VariationStatus.active)) {
      return InspectionDeclaration.satisfactoryWithVariations;
    }

    return InspectionDeclaration.satisfactory;
  }

  // ─── Service Window Calculation ──────────────────────────────

  ({DateTime start, DateTime end}) calculateNextServiceWindow(
      DateTime lastServiceDate) {
    return (
      start: _addMonthsSafely(lastServiceDate, 5),
      end: _addMonthsSafely(lastServiceDate, 7),
    );
  }

  bool isServiceOverdue(DateTime? lastServiceDate) {
    if (lastServiceDate == null) return false;
    final window = calculateNextServiceWindow(lastServiceDate);
    return DateTime.now().isAfter(window.end);
  }

  String formatServiceWindow(DateTime lastServiceDate) {
    final window = calculateNextServiceWindow(lastServiceDate);
    final startStr =
        '${window.start.day} ${_monthName(window.start.month)} ${window.start.year}';
    final endStr =
        '${window.end.day} ${_monthName(window.end.month)} ${window.end.year}';
    return 'Due between $startStr and $endStr';
  }

  // ─── MCP 25% Rotation Tracking ──────────────────────────────

  Future<McpRotationStatus> getMcpRotationStatus({
    required String basePath,
    required String siteId,
  }) async {
    final assetsSnap = await _assetsCol(basePath, siteId)
        .where('assetTypeId', isEqualTo: 'call_point')
        .get();
    final mcpAssets = assetsSnap.docs
        .map((d) {
          try {
            return Asset.fromJson(d.data());
          } catch (_) {
            return null;
          }
        })
        .whereType<Asset>()
        .where(
            (a) => a.complianceStatus != AssetComplianceStatus.decommissioned)
        .toList();

    if (mcpAssets.isEmpty) {
      return const McpRotationStatus(
        totalMcps: 0,
        testedThisVisit: 0,
        testedInLast12Months: 0,
        mcpIdsNotTestedInLast12Months: [],
        allCoveredInLast12Months: true,
        rollingPercentageThisQuarter: 100.0,
      );
    }

    final twelveMonthsAgo =
        DateTime.now().subtract(const Duration(days: 365));

    final serviceSnap = await _serviceHistoryCol(basePath, siteId)
        .where('serviceDate',
            isGreaterThanOrEqualTo: twelveMonthsAgo.toIso8601String())
        .get();

    final mcpIds = mcpAssets.map((a) => a.id).toSet();
    final testedMcpIds = <String>{};
    int testedThisVisitCount = 0;

    for (final doc in serviceSnap.docs) {
      try {
        final record = ServiceRecord.fromJson(doc.data());
        if (mcpIds.contains(record.assetId)) {
          testedMcpIds.add(record.assetId);
          if (record.mcpTestedThisVisit) testedThisVisitCount++;
        }
      } catch (_) {}
    }

    final notTestedIds =
        mcpIds.where((id) => !testedMcpIds.contains(id)).toList();

    final threeMonthsAgo =
        DateTime.now().subtract(const Duration(days: 91));
    final quarterServiceSnap = await _serviceHistoryCol(basePath, siteId)
        .where('serviceDate',
            isGreaterThanOrEqualTo: threeMonthsAgo.toIso8601String())
        .get();

    final quarterTestedMcpIds = <String>{};
    for (final doc in quarterServiceSnap.docs) {
      try {
        final record = ServiceRecord.fromJson(doc.data());
        if (mcpIds.contains(record.assetId) && record.mcpTestedThisVisit) {
          quarterTestedMcpIds.add(record.assetId);
        }
      } catch (_) {}
    }

    final rollingPct = mcpAssets.isEmpty
        ? 100.0
        : (quarterTestedMcpIds.length / mcpAssets.length) * 100.0;

    return McpRotationStatus(
      totalMcps: mcpAssets.length,
      testedThisVisit: testedThisVisitCount,
      testedInLast12Months: testedMcpIds.length,
      mcpIdsNotTestedInLast12Months: notTestedIds,
      allCoveredInLast12Months: notTestedIds.isEmpty,
      rollingPercentageThisQuarter: rollingPct,
    );
  }

  // ─── Competency Check ────────────────────────────────────────

  Future<bool> isCompetencyCurrent({
    required String basePath,
    required String engineerId,
  }) async {
    final snap = await _firestore
        .doc('$basePath/members/$engineerId/competency/current')
        .get();
    if (!snap.exists || snap.data() == null) return false;

    final EngineerCompetency competency;
    try {
      competency = EngineerCompetency.fromJson(snap.data()!);
    } catch (_) {
      return false;
    }

    final hasExpired = competency.qualifications.any(
        (q) => q.expiryDate != null && q.expiryDate!.isBefore(DateTime.now()));
    if (hasExpired) return false;

    if (competency.totalCpdHoursLast12Months <
        RemoteConfigService.instance.bs5839MinCpdHoursPerYear) {
      return false;
    }

    return true;
  }

  // ─── Helpers ─────────────────────────────────────────────────

  DateTime _addMonthsSafely(DateTime date, int months) {
    final totalMonths = date.month - 1 + months;
    final newYear = date.year + (totalMonths ~/ 12);
    final newMonth = (totalMonths % 12) + 1;
    final daysInNewMonth = DateUtils.getDaysInMonth(newYear, newMonth);
    final newDay = date.day > daysInNewMonth ? daysInNewMonth : date.day;
    return DateTime(newYear, newMonth, newDay, date.hour, date.minute);
  }

  static String _monthName(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return months[month - 1];
  }
}
