import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../models/floor_plan.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/floor_plan_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/asset_pin.dart';
import '../../widgets/widgets.dart';
import '../assets/asset_detail_screen.dart';
import '../assets/add_edit_asset_screen.dart';

class InteractiveFloorPlanScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final FloorPlan floorPlan;

  const InteractiveFloorPlanScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.floorPlan,
  });

  @override
  State<InteractiveFloorPlanScreen> createState() =>
      _InteractiveFloorPlanScreenState();
}

class _InteractiveFloorPlanScreenState
    extends State<InteractiveFloorPlanScreen> {
  final TransformationController _transformController =
      TransformationController();
  bool _isPlacementMode = false;
  String? _selectedAssetId;
  String? _filterType;
  String? _filterStatus;
  String? _draggingAssetId;
  Offset? _dragPosition; // Current drag position in image coordinates
  late double _pinScale;
  late bool _showLabels;
  Map<String, AssetType> _assetTypes = {};

  @override
  void initState() {
    super.initState();
    _pinScale = widget.floorPlan.pinScale;
    _showLabels = widget.floorPlan.showLabels;
    _loadAssetTypes();
  }

  Future<void> _loadAssetTypes() async {
    final types = await AssetTypeService.instance
        .getAssetTypes(widget.basePath);
    if (mounted) {
      setState(() {
        _assetTypes = {for (final t in types) t.id: t};
      });
    }
  }

  AssetType? _getAssetType(String typeId) {
    return _assetTypes[typeId] ?? DefaultAssetTypes.getById(typeId);
  }

  @override
  void dispose() {
    _transformController.dispose();
    super.dispose();
  }

  Future<void> _savePinScale() async {
    try {
      await FloorPlanService.instance.updateFloorPlan(
        widget.basePath,
        widget.siteId,
        widget.floorPlan.copyWith(pinScale: _pinScale),
      );
    } catch (_) {
      if (mounted) context.showErrorToast('Failed to save pin size');
    }
  }

  Future<void> _saveShowLabels() async {
    try {
      await FloorPlanService.instance.updateFloorPlan(
        widget.basePath,
        widget.siteId,
        widget.floorPlan.copyWith(showLabels: _showLabels),
      );
    } catch (_) {
      if (mounted) context.showErrorToast('Failed to save label setting');
    }
  }

  List<Asset> _filterAssets(List<Asset> assets) {
    var filtered = assets
        .where((a) => a.floorPlanId == widget.floorPlan.id)
        .toList();

    if (_filterType != null) {
      filtered = filtered.where((a) => a.assetTypeId == _filterType).toList();
    }
    if (_filterStatus != null) {
      filtered =
          filtered.where((a) => a.complianceStatus == _filterStatus).toList();
    }
    return filtered;
  }

  void _onPinTap(Asset asset) {
    setState(() => _selectedAssetId = asset.id);
    _showAssetBottomSheet(asset);
  }

  void _showAssetBottomSheet(Asset asset) {
    final type = DefaultAssetTypes.getById(asset.assetTypeId);
    final statusColor = _colorForStatus(asset.complianceStatus);

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          asset.reference ?? type?.name ?? 'Asset',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          [
                            type?.name,
                            if (asset.variant != null) asset.variant,
                          ].whereType<String>().join(' · '),
                          style: TextStyle(
                            color:
                                Theme.of(ctx).brightness == Brightness.dark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _statusLabel(asset.complianceStatus),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (asset.lastServiceDate != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Last service: ${_formatDate(asset.lastServiceDate!)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(ctx).brightness == Brightness.dark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AssetDetailScreen(
                              basePath: widget.basePath,
                              siteId: widget.siteId,
                              assetId: asset.id,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(AppIcons.eye, size: 18),
                      label: const Text('View Details'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        // Placeholder — Phase 3 will implement testing
                        context.showWarningToast(
                            'Testing coming in next update');
                      },
                      icon: const Icon(AppIcons.clipboardTick, size: 18),
                      label: const Text('Test Now'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() => _selectedAssetId = null);
    });
  }

  void _onFloorPlanTap(TapDownDetails details, BoxConstraints constraints) {
    if (!_isPlacementMode) return;

    // Get the tap position relative to the image
    final renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(details.globalPosition);

    // Account for the transformation
    final matrix = _transformController.value;
    final inverseMatrix = Matrix4.inverted(matrix);
    final transformedPoint = MatrixUtils.transformPoint(
        inverseMatrix, localPosition);

    // Account for AppBar offset (roughly 56 + status bar)
    final appBarHeight = MediaQuery.of(context).padding.top + kToolbarHeight;
    final adjustedY = transformedPoint.dy - appBarHeight;

    final xPercent = transformedPoint.dx / widget.floorPlan.imageWidth;
    final yPercent = adjustedY / widget.floorPlan.imageHeight;

    // Clamp to valid range
    if (xPercent < 0 || xPercent > 1 || yPercent < 0 || yPercent > 1) return;

    _showPlacementOptions(xPercent, yPercent);
  }

  void _showPlacementOptions(double xPercent, double yPercent) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Place Asset',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(AppIcons.add),
              title: const Text('Create New Asset'),
              subtitle: const Text('Add a new asset at this location'),
              onTap: () {
                Navigator.pop(ctx);
                _createAssetAtPosition(xPercent, yPercent);
              },
            ),
            ListTile(
              leading: const Icon(AppIcons.location),
              title: const Text('Place Existing Asset'),
              subtitle: const Text('Choose an unplaced asset'),
              onTap: () {
                Navigator.pop(ctx);
                _placeExistingAsset(xPercent, yPercent);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _createAssetAtPosition(double xPercent, double yPercent) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditAssetScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          presetFloorPlanId: widget.floorPlan.id,
          presetXPercent: xPercent,
          presetYPercent: yPercent,
        ),
      ),
    );
  }

  Future<void> _placeExistingAsset(
      double xPercent, double yPercent) async {
    // Get unplaced assets
    final snapshot = await AssetService.instance
        .getAssetsStream(widget.basePath, widget.siteId)
        .first;
    final unplaced = snapshot.where((a) => a.floorPlanId == null).toList();

    if (!mounted) return;

    if (unplaced.isEmpty) {
      context.showWarningToast('No unplaced assets available');
      return;
    }

    final selected = await showModalBottomSheet<Asset>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Select Asset to Place',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: unplaced.length,
                itemBuilder: (_, index) {
                  final asset = unplaced[index];
                  final type =
                      DefaultAssetTypes.getById(asset.assetTypeId);
                  return ListTile(
                    leading: Icon(AppIcons.clipboardTick),
                    title: Text(
                        asset.reference ?? type?.name ?? 'Asset'),
                    subtitle: Text([
                      type?.name,
                      if (asset.variant != null) asset.variant,
                    ].whereType<String>().join(' · ')),
                    onTap: () => Navigator.pop(ctx, asset),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null && mounted) {
      try {
        final updated = selected.copyWith(
          floorPlanId: widget.floorPlan.id,
          xPercent: xPercent,
          yPercent: yPercent,
        );
        await AssetService.instance
            .updateAsset(widget.basePath, widget.siteId, updated);
        AnalyticsService.instance.logFloorPlanPinPlaced(
          siteId: widget.siteId,
          assetType: selected.assetTypeId,
        );
        if (mounted) context.showSuccessToast('Asset placed');
      } catch (_) {
        if (mounted) context.showErrorToast('Failed to place asset');
      }
    }
  }

  Future<void> _updateAssetPosition(
      Asset asset, double xPercent, double yPercent) async {
    try {
      final updated = asset.copyWith(
        xPercent: xPercent,
        yPercent: yPercent,
      );
      await AssetService.instance
          .updateAsset(widget.basePath, widget.siteId, updated);
    } catch (_) {
      if (mounted) context.showErrorToast('Failed to move pin');
    }
  }

  Color _colorForStatus(String status) {
    switch (status) {
      case Asset.statusPass:
        return const Color(0xFF4CAF50);
      case Asset.statusFail:
        return const Color(0xFFD32F2F);
      case Asset.statusDecommissioned:
        return Colors.grey;
      default:
        return const Color(0xFF9E9E9E);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case Asset.statusPass:
        return 'Pass';
      case Asset.statusFail:
        return 'Fail';
      case Asset.statusDecommissioned:
        return 'Decommissioned';
      default:
        return 'Untested';
    }
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.floorPlan.name),
        actions: [
          // Label visibility toggle
          IconButton(
            icon: Icon(
              AppIcons.tag,
              color: _showLabels ? AppTheme.primaryBlue : null,
            ),
            tooltip: _showLabels ? 'Hide labels' : 'Show labels',
            onPressed: () {
              setState(() => _showLabels = !_showLabels);
              _saveShowLabels();
            },
          ),
          // Placement mode toggle
          IconButton(
            icon: Icon(
              _isPlacementMode ? AppIcons.close : AppIcons.addCircle,
              color: _isPlacementMode ? Colors.orange : null,
            ),
            tooltip:
                _isPlacementMode ? 'Exit placement mode' : 'Place assets',
            onPressed: () =>
                setState(() => _isPlacementMode = !_isPlacementMode),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Floor plan with pins
          StreamBuilder<List<Asset>>(
            stream: AssetService.instance
                .getAssetsStream(widget.basePath, widget.siteId),
            builder: (context, snapshot) {
              final allAssets = snapshot.data ?? [];
              final assets = _filterAssets(allAssets);

              AnalyticsService.instance.logFloorPlanViewed(
                siteId: widget.siteId,
                assetCount: assets.length,
              );

              return GestureDetector(
                onTapDown: (details) => _onFloorPlanTap(
                  details,
                  BoxConstraints(
                    maxWidth: widget.floorPlan.imageWidth,
                    maxHeight: widget.floorPlan.imageHeight,
                  ),
                ),
                child: InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.3,
                  maxScale: 5.0,
                  panEnabled: _draggingAssetId == null,
                  boundaryMargin:
                      const EdgeInsets.all(double.infinity),
                  child: SizedBox(
                    width: widget.floorPlan.imageWidth,
                    height: widget.floorPlan.imageHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Floor plan image
                        Positioned.fill(
                          child: kIsWeb
                              ? Image.network(
                                  widget.floorPlan.imageUrl,
                                  fit: BoxFit.contain,
                                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                                  errorBuilder: (_, _, _) => Center(
                                    child: Icon(AppIcons.image,
                                        size: 64,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textSecondary),
                                  ),
                                )
                              : CachedNetworkImage(
                                  imageUrl: widget.floorPlan.imageUrl,
                                  fit: BoxFit.contain,
                                  placeholder: (_, _) =>
                                      const Center(child: AdaptiveLoadingIndicator()),
                                  errorWidget: (_, _, _) => Center(
                                    child: Icon(AppIcons.image,
                                        size: 64,
                                        color: isDark
                                            ? AppTheme.darkTextSecondary
                                            : AppTheme.textSecondary),
                                  ),
                                ),
                        ),
                        // Asset pins
                        ...assets.map((asset) {
                          if (asset.xPercent == null ||
                              asset.yPercent == null) {
                            return const SizedBox.shrink();
                          }
                          final isDragging = _draggingAssetId == asset.id;
                          final isSelected = _selectedAssetId == asset.id || isDragging;
                          final pinSize = 28.0 * _pinScale;
                          final actualSize = isSelected ? pinSize * 1.2 : pinSize;
                          final halfPin = actualSize / 2;
                          final type = _getAssetType(asset.assetTypeId);

                          // Use drag position if actively dragging this pin
                          final displayX = isDragging && _dragPosition != null
                              ? _dragPosition!.dx
                              : asset.xPercent! * widget.floorPlan.imageWidth;
                          final displayY = isDragging && _dragPosition != null
                              ? _dragPosition!.dy
                              : asset.yPercent! * widget.floorPlan.imageHeight;

                          final left = displayX - halfPin;
                          final top = displayY - halfPin;

                          // In placement mode: pins are directly draggable
                          if (_isPlacementMode) {
                            return Positioned(
                              left: left,
                              top: top,
                              child: GestureDetector(
                                onPanStart: (_) {
                                  setState(() {
                                    _draggingAssetId = asset.id;
                                    _dragPosition = Offset(
                                      asset.xPercent! * widget.floorPlan.imageWidth,
                                      asset.yPercent! * widget.floorPlan.imageHeight,
                                    );
                                  });
                                },
                                onPanUpdate: (details) {
                                  if (_draggingAssetId != asset.id) return;
                                  final scale = _transformController.value.getMaxScaleOnAxis();
                                  setState(() {
                                    _dragPosition = Offset(
                                      (_dragPosition?.dx ?? 0) + details.delta.dx / scale,
                                      (_dragPosition?.dy ?? 0) + details.delta.dy / scale,
                                    );
                                  });
                                },
                                onPanEnd: (_) {
                                  if (_dragPosition != null) {
                                    final newX = _dragPosition!.dx / widget.floorPlan.imageWidth;
                                    final newY = _dragPosition!.dy / widget.floorPlan.imageHeight;
                                    if (newX >= 0 && newX <= 1 && newY >= 0 && newY <= 1) {
                                      _updateAssetPosition(asset, newX, newY);
                                    }
                                  }
                                  setState(() {
                                    _draggingAssetId = null;
                                    _dragPosition = null;
                                  });
                                },
                                onTap: () => _onPinTap(asset),
                                child: MouseRegion(
                                  cursor: SystemMouseCursors.grab,
                                  child: AssetPin(
                                    asset: asset,
                                    assetType: type,
                                    isSelected: isSelected,
                                    pinScale: _pinScale,
                                    showLabel: _showLabels,
                                    label: asset.reference,
                                  ),
                                ),
                              ),
                            );
                          }

                          return Positioned(
                            left: left,
                            top: top,
                            child: GestureDetector(
                              onTap: () => _onPinTap(asset),
                              onLongPressStart: (_) {
                                setState(() {
                                  _draggingAssetId = asset.id;
                                  _dragPosition = Offset(
                                    asset.xPercent! * widget.floorPlan.imageWidth,
                                    asset.yPercent! * widget.floorPlan.imageHeight,
                                  );
                                });
                              },
                              onLongPressMoveUpdate: (details) {
                                if (_draggingAssetId != asset.id) return;
                                final scale = _transformController.value.getMaxScaleOnAxis();
                                final startX = asset.xPercent! * widget.floorPlan.imageWidth;
                                final startY = asset.yPercent! * widget.floorPlan.imageHeight;
                                setState(() {
                                  _dragPosition = Offset(
                                    startX + details.offsetFromOrigin.dx / scale,
                                    startY + details.offsetFromOrigin.dy / scale,
                                  );
                                });
                              },
                              onLongPressEnd: (_) {
                                if (_dragPosition != null) {
                                  final newX = _dragPosition!.dx / widget.floorPlan.imageWidth;
                                  final newY = _dragPosition!.dy / widget.floorPlan.imageHeight;
                                  if (newX >= 0 && newX <= 1 && newY >= 0 && newY <= 1) {
                                    _updateAssetPosition(asset, newX, newY);
                                  }
                                }
                                setState(() {
                                  _draggingAssetId = null;
                                  _dragPosition = null;
                                });
                              },
                              child: AssetPin(
                                asset: asset,
                                assetType: type,
                                isSelected: isSelected,
                                pinScale: _pinScale,
                                showLabel: _showLabels,
                                label: asset.reference,
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          // Placement mode overlay
          if (_isPlacementMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    color: Colors.orange.withValues(alpha: 0.9),
                    child: const Row(
                      children: [
                        Icon(AppIcons.addCircle, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Tap on the floor plan to place an asset',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    color: isDark
                        ? AppTheme.darkSurfaceElevated.withValues(alpha: 0.95)
                        : Colors.white.withValues(alpha: 0.95),
                    child: Row(
                      children: [
                        Icon(AppIcons.setting, size: 16,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
                        const SizedBox(width: 6),
                        Text('Pin Size', style: TextStyle(fontSize: 13,
                            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary)),
                        Expanded(
                          child: Slider(
                            value: _pinScale,
                            min: 0.5,
                            max: 2.5,
                            divisions: 20,
                            label: '${(_pinScale * 100).round()}%',
                            onChanged: (v) => setState(() => _pinScale = v),
                            onChangeEnd: (_) => _savePinScale(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Filter chips (bottom)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _PinFilterChip(
                    label: 'All',
                    selected: _filterType == null && _filterStatus == null,
                    onTap: () => setState(() {
                      _filterType = null;
                      _filterStatus = null;
                    }),
                  ),
                  const SizedBox(width: 6),
                  _PinFilterChip(
                    label: 'Pass',
                    selected: _filterStatus == Asset.statusPass,
                    color: const Color(0xFF4CAF50),
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == Asset.statusPass
                          ? null
                          : Asset.statusPass;
                    }),
                  ),
                  const SizedBox(width: 6),
                  _PinFilterChip(
                    label: 'Fail',
                    selected: _filterStatus == Asset.statusFail,
                    color: const Color(0xFFD32F2F),
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == Asset.statusFail
                          ? null
                          : Asset.statusFail;
                    }),
                  ),
                  const SizedBox(width: 6),
                  _PinFilterChip(
                    label: 'Untested',
                    selected: _filterStatus == Asset.statusUntested,
                    color: const Color(0xFF9E9E9E),
                    onTap: () => setState(() {
                      _filterStatus = _filterStatus == Asset.statusUntested
                          ? null
                          : Asset.statusUntested;
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PinFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? color;
  final VoidCallback onTap;

  const _PinFilterChip({
    required this.label,
    required this.selected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? AppTheme.primaryBlue).withValues(alpha: 0.9)
              : Colors.black54,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null && !selected) ...[
              CircleAvatar(radius: 5, backgroundColor: color),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
