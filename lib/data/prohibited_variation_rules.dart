import '../models/asset.dart';
import '../models/bs5839_system_config.dart';
import '../models/prohibited_variation_rule.dart';

class ProhibitedVariationRules {
  ProhibitedVariationRules._();

  static final List<ProhibitedVariationRule> all = [
    ProhibitedVariationRule(
      id: 'no_zone_plan_multi_zone_sleeping',
      clauseReference: '6.6a',
      description:
          'Zone plan absent in a multi-zone building with sleeping accommodation',
      check: (config, assets) {
        if (!config.hasSleepingAccommodation) return true;
        if (config.numberOfZones <= 1) return true;
        final hasZonePlan = assets.any((a) =>
            a.assetTypeId == 'zone_plan' &&
            a.complianceStatus != AssetComplianceStatus.decommissioned);
        return hasZonePlan;
      },
    ),
    ProhibitedVariationRule(
      id: 'heat_detector_in_sleeping_room',
      clauseReference: '6.6c',
      description:
          'Heat detector installed in a room used for sleeping (L2/L3 systems)',
      check: (config, assets) {
        if (config.category != Bs5839SystemCategory.l2 &&
            config.category != Bs5839SystemCategory.l3) {
          return true;
        }
        final violating = assets.any((a) =>
            a.assetTypeId == 'heat_detector' &&
            a.isInSleepingRoom &&
            a.complianceStatus != AssetComplianceStatus.decommissioned);
        return !violating;
      },
    ),
    ProhibitedVariationRule(
      id: 'no_zone_plan_url_multi_zone_sleeping',
      clauseReference: '6.6a',
      description:
          'Zone plan document not uploaded for multi-zone sleeping accommodation site',
      check: (config, assets) {
        if (!config.hasSleepingAccommodation) return true;
        if (config.numberOfZones <= 1) return true;
        return config.zonePlanUrl != null && config.zonePlanUrl!.isNotEmpty;
      },
    ),
    ProhibitedVariationRule(
      id: 'no_arc_signalling_l_system',
      clauseReference: '6.6b',
      description:
          'ARC signalling absent on an L-category system with sleeping accommodation',
      check: (config, assets) {
        if (!config.hasSleepingAccommodation) return true;
        final isLCategory = config.category == Bs5839SystemCategory.l1 ||
            config.category == Bs5839SystemCategory.l2 ||
            config.category == Bs5839SystemCategory.l3 ||
            config.category == Bs5839SystemCategory.l4 ||
            config.category == Bs5839SystemCategory.l5;
        if (!isLCategory) return true;
        return config.arcConnected;
      },
    ),
  ];

  static ProhibitedVariationRule? getById(String id) {
    try {
      return all.firstWhere((r) => r.id == id);
    } catch (_) {
      return null;
    }
  }
}
