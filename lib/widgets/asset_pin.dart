import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../data/default_asset_types.dart';
import '../utils/icon_map.dart';

/// A small pin widget representing an asset on a floor plan.
/// Coloured by compliance status, with an icon matching the asset type.
class AssetPin extends StatelessWidget {
  final Asset asset;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AssetPin({
    super.key,
    required this.asset,
    this.isSelected = false,
    this.onTap,
    this.onLongPress,
  });

  Color get _statusColor {
    switch (asset.complianceStatus) {
      case Asset.statusPass:
        return const Color(0xFF4CAF50);
      case Asset.statusFail:
        return const Color(0xFFD32F2F);
      case Asset.statusDecommissioned:
        return const Color(0xFF9E9E9E).withValues(alpha: 0.5);
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  IconData get _icon {
    final type = DefaultAssetTypes.getById(asset.assetTypeId);
    if (type == null) return AppIcons.setting;
    switch (type.iconName) {
      case 'cpu': return AppIcons.cpu;
      case 'radar': return AppIcons.radar;
      case 'danger': return AppIcons.danger;
      case 'volumeHigh': return AppIcons.volumeHigh;
      case 'securitySafe': return AppIcons.securitySafe;
      case 'lampCharge': return AppIcons.lampCharge;
      case 'wind': return AppIcons.wind;
      case 'drop': return AppIcons.drop;
      case 'box': return AppIcons.box;
      default: return AppIcons.setting;
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = isSelected ? 34.0 : 28.0;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: _statusColor,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.white, width: 2.5)
              : Border.all(color: Colors.white, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _statusColor.withValues(alpha: 0.4),
              blurRadius: isSelected ? 6 : 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          _icon,
          size: isSelected ? 16 : 13,
          color: Colors.white,
        ),
      ),
    );
  }
}
