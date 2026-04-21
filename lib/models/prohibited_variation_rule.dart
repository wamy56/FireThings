import 'asset.dart';
import 'bs5839_system_config.dart';

class ProhibitedVariationRule {
  final String id;
  final String clauseReference;
  final String description;
  final bool Function(Bs5839SystemConfig config, List<Asset> assets) check;

  const ProhibitedVariationRule({
    required this.id,
    required this.clauseReference,
    required this.description,
    required this.check,
  });
}
