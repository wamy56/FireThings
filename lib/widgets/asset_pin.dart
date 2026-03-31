import 'package:flutter/material.dart';
import '../models/asset.dart';
import '../models/asset_type.dart';
import '../data/default_asset_types.dart';
import 'bs5839_symbols.dart';

/// A floor plan pin rendered as a BS 5839 schematic symbol.
/// Coloured by compliance status, shape and label determined by asset type.
/// Optionally shows a reference label above the symbol.
///
/// The widget's layout size is always the symbol size. When [showLabel] is true,
/// the label overflows above the symbol so that the symbol centre remains at
/// the positioned coordinate on the floor plan.
class AssetPin extends StatelessWidget {
  final Asset asset;
  final AssetType? assetType;
  final bool isSelected;
  final double pinScale;
  /// When set, overrides the default `28.0 * pinScale` base size.
  final double? basePinSize;
  final bool showLabel;
  final String? label;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const AssetPin({
    super.key,
    required this.asset,
    this.assetType,
    this.isSelected = false,
    this.pinScale = 1.0,
    this.basePinSize,
    this.showLabel = false,
    this.label,
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

  BS5839Symbol get _symbol {
    final type = assetType ?? DefaultAssetTypes.getById(asset.assetTypeId);
    if (type == null) return BS5839Symbol.other;
    return symbolFromIconName(type.iconName);
  }

  bool get _hasLabel => showLabel && label != null && label!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final baseSize = basePinSize ?? (28.0 * pinScale);
    final size = isSelected ? baseSize * 1.2 : baseSize;

    final symbolWidget = CustomPaint(
      size: Size(size, size),
      painter: BS5839SymbolPainter(
        symbol: _symbol,
        color: _statusColor,
        isSelected: isSelected,
      ),
    );

    final child = _hasLabel
        ? SizedBox(
            width: size,
            height: size,
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 4 * pinScale,
                      vertical: 1 * pinScale,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: Colors.grey.shade400,
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      label!,
                      style: TextStyle(
                        fontSize: 9 * pinScale,
                        color: Colors.black87,
                        fontWeight: FontWeight.w600,
                        height: 1.1,
                      ),
                    ),
                  ),
                  SizedBox(height: 2 * pinScale),
                  symbolWidget,
                ],
              ),
            ),
          )
        : symbolWidget;

    if (onTap == null && onLongPress == null) return child;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}
