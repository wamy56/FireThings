import 'package:flutter_test/flutter_test.dart';
import 'package:firethings/data/prohibited_variation_rules.dart';
import 'package:firethings/models/asset.dart';
import 'package:firethings/models/bs5839_system_config.dart';

Bs5839SystemConfig _makeConfig({
  Bs5839SystemCategory category = Bs5839SystemCategory.l1,
  bool hasSleepingAccommodation = false,
  int numberOfZones = 1,
  bool arcConnected = false,
  String? zonePlanUrl,
}) {
  final now = DateTime.now();
  return Bs5839SystemConfig(
    id: 'test',
    siteId: 'site1',
    category: category,
    responsiblePersonName: 'Test Person',
    hasSleepingAccommodation: hasSleepingAccommodation,
    numberOfZones: numberOfZones,
    arcConnected: arcConnected,
    zonePlanUrl: zonePlanUrl,
    createdAt: now,
    updatedAt: now,
    createdBy: 'tester',
    updatedBy: 'tester',
  );
}

Asset _makeAsset({
  String id = 'a1',
  String assetTypeId = 'smoke_detector',
  AssetComplianceStatus complianceStatus = AssetComplianceStatus.pass,
  bool isInSleepingRoom = false,
}) {
  final now = DateTime.now();
  return Asset(
    id: id,
    siteId: 'site1',
    assetTypeId: assetTypeId,
    complianceStatus: complianceStatus,
    isInSleepingRoom: isInSleepingRoom,
    createdBy: 'tester',
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('no_zone_plan_multi_zone_sleeping', () {
    final rule = ProhibitedVariationRules.getById(
        'no_zone_plan_multi_zone_sleeping')!;

    test('passes when no sleeping accommodation', () {
      final config = _makeConfig(
        hasSleepingAccommodation: false,
        numberOfZones: 3,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes when single zone', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 1,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes when zone plan asset exists', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 3,
      );
      final assets = [_makeAsset(assetTypeId: 'zone_plan')];
      expect(rule.check(config, assets), isTrue);
    });

    test('fails when multi-zone sleeping site has no zone plan asset', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 3,
      );
      expect(rule.check(config, []), isFalse);
    });

    test('fails when zone plan is decommissioned', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 2,
      );
      final assets = [
        _makeAsset(
          assetTypeId: 'zone_plan',
          complianceStatus: AssetComplianceStatus.decommissioned,
        ),
      ];
      expect(rule.check(config, assets), isFalse);
    });
  });

  group('heat_detector_in_sleeping_room', () {
    final rule =
        ProhibitedVariationRules.getById('heat_detector_in_sleeping_room')!;

    test('passes on non-L2/L3 systems', () {
      final config = _makeConfig(category: Bs5839SystemCategory.p1);
      final assets = [
        _makeAsset(
          assetTypeId: 'heat_detector',
          isInSleepingRoom: true,
        ),
      ];
      expect(rule.check(config, assets), isTrue);
    });

    test('passes on L2 with no heat detectors in sleeping rooms', () {
      final config = _makeConfig(category: Bs5839SystemCategory.l2);
      final assets = [
        _makeAsset(assetTypeId: 'heat_detector', isInSleepingRoom: false),
        _makeAsset(id: 'a2', assetTypeId: 'smoke_detector', isInSleepingRoom: true),
      ];
      expect(rule.check(config, assets), isTrue);
    });

    test('fails on L2 with heat detector in sleeping room', () {
      final config = _makeConfig(category: Bs5839SystemCategory.l2);
      final assets = [
        _makeAsset(
          assetTypeId: 'heat_detector',
          isInSleepingRoom: true,
        ),
      ];
      expect(rule.check(config, assets), isFalse);
    });

    test('fails on L3 with heat detector in sleeping room', () {
      final config = _makeConfig(category: Bs5839SystemCategory.l3);
      final assets = [
        _makeAsset(
          assetTypeId: 'heat_detector',
          isInSleepingRoom: true,
        ),
      ];
      expect(rule.check(config, assets), isFalse);
    });

    test('passes when heat detector in sleeping room is decommissioned', () {
      final config = _makeConfig(category: Bs5839SystemCategory.l2);
      final assets = [
        _makeAsset(
          assetTypeId: 'heat_detector',
          isInSleepingRoom: true,
          complianceStatus: AssetComplianceStatus.decommissioned,
        ),
      ];
      expect(rule.check(config, assets), isTrue);
    });
  });

  group('no_zone_plan_url_multi_zone_sleeping', () {
    final rule = ProhibitedVariationRules.getById(
        'no_zone_plan_url_multi_zone_sleeping')!;

    test('passes when no sleeping accommodation', () {
      final config = _makeConfig(
        hasSleepingAccommodation: false,
        numberOfZones: 5,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes when single zone', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 1,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes when zone plan URL is set', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 3,
        zonePlanUrl: 'https://example.com/plan.png',
      );
      expect(rule.check(config, []), isTrue);
    });

    test('fails when multi-zone sleeping site has no zone plan URL', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 3,
      );
      expect(rule.check(config, []), isFalse);
    });

    test('fails when zone plan URL is empty string', () {
      final config = _makeConfig(
        hasSleepingAccommodation: true,
        numberOfZones: 2,
        zonePlanUrl: '',
      );
      expect(rule.check(config, []), isFalse);
    });
  });

  group('no_arc_signalling_l_system', () {
    final rule =
        ProhibitedVariationRules.getById('no_arc_signalling_l_system')!;

    test('passes when no sleeping accommodation', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.l1,
        hasSleepingAccommodation: false,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes on P-category systems', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.p1,
        hasSleepingAccommodation: true,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes on M-category systems', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.m,
        hasSleepingAccommodation: true,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('passes when L-category sleeping site has ARC', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.l1,
        hasSleepingAccommodation: true,
        arcConnected: true,
      );
      expect(rule.check(config, []), isTrue);
    });

    test('fails when L1 sleeping site has no ARC', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.l1,
        hasSleepingAccommodation: true,
        arcConnected: false,
      );
      expect(rule.check(config, []), isFalse);
    });

    test('fails when L3 sleeping site has no ARC', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.l3,
        hasSleepingAccommodation: true,
        arcConnected: false,
      );
      expect(rule.check(config, []), isFalse);
    });

    test('fails when L5 sleeping site has no ARC', () {
      final config = _makeConfig(
        category: Bs5839SystemCategory.l5,
        hasSleepingAccommodation: true,
        arcConnected: false,
      );
      expect(rule.check(config, []), isFalse);
    });
  });

  group('ProhibitedVariationRules.getById', () {
    test('returns rule by id', () {
      final rule = ProhibitedVariationRules.getById(
          'no_zone_plan_multi_zone_sleeping');
      expect(rule, isNotNull);
      expect(rule!.clauseReference, '6.6a');
    });

    test('returns null for unknown id', () {
      expect(ProhibitedVariationRules.getById('nonexistent'), isNull);
    });
  });
}
