import 'package:flutter_test/flutter_test.dart';
import 'package:firethings/services/bs5839_compliance_service.dart';
import 'package:firethings/services/lifecycle_service.dart';

void main() {
  group('LifecycleService BS 5839 window', () {
    final lifecycle = LifecycleService.instance;

    test('calculateBs5839ServiceWindow returns 5-7 month window', () {
      final lastService = DateTime(2026, 3, 15);
      final window = lifecycle.calculateBs5839ServiceWindow(lastService);
      expect(window.start, DateTime(2026, 8, 15));
      expect(window.end, DateTime(2026, 10, 15));
    });

    test('handles year boundary correctly', () {
      final lastService = DateTime(2026, 9, 1);
      final window = lifecycle.calculateBs5839ServiceWindow(lastService);
      expect(window.start, DateTime(2027, 2, 1));
      expect(window.end, DateTime(2027, 4, 1));
    });

    test('handles month-end date clamping', () {
      final lastService = DateTime(2026, 1, 31);
      final window = lifecycle.calculateBs5839ServiceWindow(lastService);
      expect(window.start, DateTime(2026, 6, 30));
      expect(window.end, DateTime(2026, 8, 31));
    });

    test('handles leap year February boundary', () {
      final lastService = DateTime(2027, 9, 30);
      final window = lifecycle.calculateBs5839ServiceWindow(lastService);
      expect(window.start, DateTime(2028, 2, 29));
      expect(window.end, DateTime(2028, 4, 30));
    });

    test('returns false for null last service date', () {
      expect(lifecycle.isBs5839ServiceOverdue(null), isFalse);
    });

    test('returns false for recent service', () {
      final recent = DateTime.now().subtract(const Duration(days: 60));
      expect(lifecycle.isBs5839ServiceOverdue(recent), isFalse);
    });

    test('returns true when past 7-month window', () {
      final old = DateTime.now().subtract(const Duration(days: 250));
      expect(lifecycle.isBs5839ServiceOverdue(old), isTrue);
    });
  });

  group('McpRotationStatus', () {
    test('empty site reports all covered', () {
      const status = McpRotationStatus(
        totalMcps: 0,
        testedThisVisit: 0,
        testedInLast12Months: 0,
        mcpIdsNotTestedInLast12Months: [],
        allCoveredInLast12Months: true,
        rollingPercentageThisQuarter: 100.0,
      );
      expect(status.allCoveredInLast12Months, isTrue);
      expect(status.totalMcps, 0);
    });

    test('partial coverage reports not all covered', () {
      const status = McpRotationStatus(
        totalMcps: 10,
        testedThisVisit: 3,
        testedInLast12Months: 7,
        mcpIdsNotTestedInLast12Months: ['mcp8', 'mcp9', 'mcp10'],
        allCoveredInLast12Months: false,
        rollingPercentageThisQuarter: 30.0,
      );
      expect(status.allCoveredInLast12Months, isFalse);
      expect(status.mcpIdsNotTestedInLast12Months, hasLength(3));
      expect(status.rollingPercentageThisQuarter, 30.0);
    });

    test('full coverage has empty untested list', () {
      const status = McpRotationStatus(
        totalMcps: 8,
        testedThisVisit: 2,
        testedInLast12Months: 8,
        mcpIdsNotTestedInLast12Months: [],
        allCoveredInLast12Months: true,
        rollingPercentageThisQuarter: 25.0,
      );
      expect(status.allCoveredInLast12Months, isTrue);
      expect(status.mcpIdsNotTestedInLast12Months, isEmpty);
    });
  });

  group('ComplianceIssue', () {
    test('constructs with all fields', () {
      const issue = ComplianceIssue(
        code: 'TEST_CODE',
        description: 'Test description',
        clauseReference: '25.4',
        severity: ComplianceIssueSeverity.critical,
      );
      expect(issue.code, 'TEST_CODE');
      expect(issue.severity, ComplianceIssueSeverity.critical);
      expect(issue.clauseReference, '25.4');
    });

    test('clauseReference is optional', () {
      const issue = ComplianceIssue(
        code: 'NO_CLAUSE',
        description: 'No clause ref',
        severity: ComplianceIssueSeverity.info,
      );
      expect(issue.clauseReference, isNull);
    });

    test('severity enum has all values', () {
      expect(ComplianceIssueSeverity.values, hasLength(3));
      expect(
        ComplianceIssueSeverity.values,
        containsAll([
          ComplianceIssueSeverity.critical,
          ComplianceIssueSeverity.warning,
          ComplianceIssueSeverity.info,
        ]),
      );
    });
  });
}
