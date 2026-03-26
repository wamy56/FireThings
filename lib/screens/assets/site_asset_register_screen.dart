import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';
import 'add_edit_asset_screen.dart';
import 'asset_detail_screen.dart';
import '../floor_plans/floor_plan_list_screen.dart';

class SiteAssetRegisterScreen extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String basePath;

  const SiteAssetRegisterScreen({
    super.key,
    required this.siteId,
    required this.siteName,
    required this.basePath,
  });

  @override
  State<SiteAssetRegisterScreen> createState() =>
      _SiteAssetRegisterScreenState();
}

class _SiteAssetRegisterScreenState extends State<SiteAssetRegisterScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String? _filterType;
  String? _filterStatus;
  List<AssetType> _assetTypes = [];

  @override
  void initState() {
    super.initState();
    _loadAssetTypes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAssetTypes() async {
    final types =
        await AssetTypeService.instance.getAssetTypes(widget.basePath);
    if (mounted) setState(() => _assetTypes = types);
  }

  AssetType? _getAssetType(String typeId) {
    try {
      return _assetTypes.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return DefaultAssetTypes.getById(typeId);
    }
  }

  IconData _iconForType(AssetType? type) {
    if (type == null) return AppIcons.setting;
    switch (type.iconName) {
      case 'cpu':
        return AppIcons.cpu;
      case 'radar':
        return AppIcons.radar;
      case 'danger':
        return AppIcons.danger;
      case 'volumeHigh':
        return AppIcons.volumeHigh;
      case 'securitySafe':
        return AppIcons.securitySafe;
      case 'lampCharge':
        return AppIcons.lampCharge;
      case 'wind':
        return AppIcons.wind;
      case 'drop':
        return AppIcons.drop;
      case 'box':
        return AppIcons.box;
      default:
        return AppIcons.setting;
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

  List<Asset> _filterAssets(List<Asset> assets) {
    var filtered = assets;

    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((a) {
        return (a.reference?.toLowerCase().contains(q) ?? false) ||
            (a.make?.toLowerCase().contains(q) ?? false) ||
            (a.model?.toLowerCase().contains(q) ?? false) ||
            (a.barcode?.toLowerCase().contains(q) ?? false) ||
            (a.zone?.toLowerCase().contains(q) ?? false);
      }).toList();
    }

    if (_filterType != null) {
      filtered = filtered.where((a) => a.assetTypeId == _filterType).toList();
    }

    if (_filterStatus != null) {
      filtered =
          filtered.where((a) => a.complianceStatus == _filterStatus).toList();
    }

    return filtered;
  }

  void _navigateToAddAsset() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEditAssetScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
        ),
      ),
    );
  }

  void _navigateToAssetDetail(Asset asset) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AssetDetailScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          assetId: asset.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.siteName),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.map),
            tooltip: 'Floor Plans',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FloorPlanListScreen(
                    siteId: widget.siteId,
                    siteName: widget.siteName,
                    basePath: widget.basePath,
                  ),
                ),
              );
            },
          ),
        ],
      ),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToAddAsset,
              icon: const Icon(AppIcons.add),
              label: const Text('Add Asset'),
            ),
      body: KeyboardDismissWrapper(
        child: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomTextField(
                controller: _searchController,
                label: 'Search assets...',
                prefixIcon: const Icon(AppIcons.search),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Status filter
                  _FilterChip(
                    label: _filterStatus != null
                        ? _statusLabel(_filterStatus!)
                        : 'Status',
                    selected: _filterStatus != null,
                    onTap: () => _showStatusFilter(context),
                    onClear:
                        _filterStatus != null
                            ? () => setState(() => _filterStatus = null)
                            : null,
                  ),
                  const SizedBox(width: 8),
                  // Type filter
                  _FilterChip(
                    label: _filterType != null
                        ? (_getAssetType(_filterType!)?.name ?? 'Type')
                        : 'Type',
                    selected: _filterType != null,
                    onTap: () => _showTypeFilter(context),
                    onClear:
                        _filterType != null
                            ? () => setState(() => _filterType = null)
                            : null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Asset list
            Expanded(
              child: StreamBuilder<List<Asset>>(
                stream: AssetService.instance
                    .getAssetsStream(widget.basePath, widget.siteId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: AdaptiveLoadingIndicator());
                  }

                  final allAssets = snapshot.data ?? [];

                  // Log analytics on first load
                  if (snapshot.connectionState == ConnectionState.active &&
                      allAssets.isNotEmpty) {
                    AnalyticsService.instance.logAssetRegisterViewed(
                      siteId: widget.siteId,
                      assetCount: allAssets.length,
                    );
                  }

                  final assets = _filterAssets(allAssets);

                  if (allAssets.isEmpty) {
                    return EmptyState(
                      icon: AppIcons.clipboardTick,
                      title: 'No Assets Registered',
                      message:
                          'Start building your asset register by adding fire safety devices for this site',
                      buttonText: 'Add Asset',
                      onButtonPressed: _navigateToAddAsset,
                    );
                  }

                  if (assets.isEmpty) {
                    return EmptyState(
                      icon: AppIcons.searchOff,
                      title: 'No Results',
                      message: 'Try a different search or filter',
                    );
                  }

                  return Column(
                    children: [
                      // Compliance summary bar
                      _buildComplianceSummary(allAssets, isDark),
                      const SizedBox(height: 8),
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: assets.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            return _buildAssetCard(
                                assets[index], isDark);
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceSummary(List<Asset> assets, bool isDark) {
    final pass =
        assets.where((a) => a.complianceStatus == Asset.statusPass).length;
    final fail =
        assets.where((a) => a.complianceStatus == Asset.statusFail).length;
    final untested =
        assets.where((a) => a.complianceStatus == Asset.statusUntested).length;
    final decom = assets
        .where((a) => a.complianceStatus == Asset.statusDecommissioned)
        .length;
    final active = assets.length - decom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Text(
            '$active assets',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          const Spacer(),
          _SummaryDot(color: const Color(0xFF4CAF50), count: pass, label: 'Pass'),
          const SizedBox(width: 12),
          _SummaryDot(color: const Color(0xFFD32F2F), count: fail, label: 'Fail'),
          const SizedBox(width: 12),
          _SummaryDot(
              color: const Color(0xFF9E9E9E), count: untested, label: 'Untested'),
        ],
      ),
    );
  }

  Widget _buildAssetCard(Asset asset, bool isDark) {
    final type = _getAssetType(asset.assetTypeId);
    final typeColor = type != null
        ? Color(int.parse(type.defaultColor.replaceFirst('#', '0xFF')))
        : Colors.grey;
    final statusColor = _colorForStatus(asset.complianceStatus);

    return GestureDetector(
      onTap: () => _navigateToAssetDetail(asset),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          children: [
            // Type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: typeColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(type), color: typeColor, size: 22),
            ),
            const SizedBox(width: 12),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    asset.reference ?? type?.name ?? 'Asset',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      type?.name,
                      if (asset.variant != null) asset.variant,
                      if (asset.zone != null) asset.zone,
                    ].whereType<String>().join(' · '),
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _statusLabel(asset.complianceStatus),
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showStatusFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All'),
              onTap: () {
                setState(() => _filterStatus = null);
                Navigator.pop(context);
              },
            ),
            for (final status in [
              Asset.statusPass,
              Asset.statusFail,
              Asset.statusUntested,
              Asset.statusDecommissioned,
            ])
              ListTile(
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: _colorForStatus(status),
                ),
                title: Text(_statusLabel(status)),
                selected: _filterStatus == status,
                onTap: () {
                  setState(() => _filterStatus = status);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _showTypeFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All Types'),
              onTap: () {
                setState(() => _filterType = null);
                Navigator.pop(context);
              },
            ),
            ..._assetTypes.map((type) => ListTile(
                  leading: Icon(_iconForType(type)),
                  title: Text(type.name),
                  selected: _filterType == type.id,
                  onTap: () {
                    setState(() => _filterType = type.id);
                    Navigator.pop(context);
                  },
                )),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryBlue.withValues(alpha: 0.12)
              : (isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: AppTheme.primaryBlue, width: 1)
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                color: selected
                    ? AppTheme.primaryBlue
                    : (isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary),
              ),
            ),
            if (onClear != null) ...[
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  AppIcons.close,
                  size: 16,
                  color: AppTheme.primaryBlue,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryDot extends StatelessWidget {
  final Color color;
  final int count;
  final String label;

  const _SummaryDot({
    required this.color,
    required this.count,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircleAvatar(radius: 5, backgroundColor: color),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white
                : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
