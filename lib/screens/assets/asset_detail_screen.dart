import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/analytics_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';
import '../../services/floor_plan_service.dart';
import 'add_edit_asset_screen.dart';
import '../floor_plans/interactive_floor_plan_screen.dart';

class AssetDetailScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String assetId;

  const AssetDetailScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.assetId,
  });

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  Asset? _asset;
  AssetType? _assetType;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  Future<void> _loadAsset() async {
    setState(() => _isLoading = true);
    try {
      final asset = await AssetService.instance
          .getAsset(widget.basePath, widget.siteId, widget.assetId);
      if (asset != null) {
        final type = await AssetTypeService.instance
            .getAssetType(widget.basePath, asset.assetTypeId);
        if (mounted) {
          setState(() {
            _asset = asset;
            _assetType = type ?? DefaultAssetTypes.getById(asset.assetTypeId);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _iconForType(AssetType? type) {
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

  Color _colorForStatus(String status) {
    switch (status) {
      case Asset.statusPass: return const Color(0xFF4CAF50);
      case Asset.statusFail: return const Color(0xFFD32F2F);
      case Asset.statusDecommissioned: return Colors.grey;
      default: return const Color(0xFF9E9E9E);
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case Asset.statusPass: return 'Pass';
      case Asset.statusFail: return 'Fail';
      case Asset.statusDecommissioned: return 'Decommissioned';
      default: return 'Untested';
    }
  }

  Future<void> _navigateToEdit() async {
    if (_asset == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => AddEditAssetScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          asset: _asset,
        ),
      ),
    );
    if (result == true) _loadAsset();
  }

  Future<void> _confirmDelete() async {
    if (_asset == null) return;

    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Delete Asset',
      message: 'Are you sure you want to delete this asset? This cannot be undone.',
      confirmLabel: 'Delete',
      cancelLabel: 'Cancel',
      isDestructive: true,
    );

    if (confirmed == true && mounted) {
      try {
        await AssetService.instance
            .deleteAsset(widget.basePath, widget.siteId, _asset!.id);
        AnalyticsService.instance
            .logAssetDeleted(assetType: _asset!.assetTypeId);
        if (mounted) {
          context.showSuccessToast('Asset deleted');
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) context.showErrorToast('Failed to delete asset');
      }
    }
  }

  Future<void> _viewOnFloorPlan(Asset asset) async {
    if (asset.floorPlanId == null) return;
    final plan = await FloorPlanService.instance
        .getFloorPlan(widget.basePath, widget.siteId, asset.floorPlanId!);
    if (plan != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InteractiveFloorPlanScreen(
            basePath: widget.basePath,
            siteId: widget.siteId,
            floorPlan: plan,
          ),
        ),
      );
    }
  }

  bool get _canDelete {
    final profile = UserProfileService.instance;
    // Solo users can always delete their own. Company: dispatchers/admins only.
    return !profile.hasCompany || profile.isDispatcherOrAdmin;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Asset')),
        body: const Center(child: AdaptiveLoadingIndicator()),
      );
    }

    if (_asset == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Asset')),
        body: const Center(child: Text('Asset not found')),
      );
    }

    final asset = _asset!;
    final type = _assetType;
    final typeColor = type != null
        ? Color(int.parse(type.defaultColor.replaceFirst('#', '0xFF')))
        : Colors.grey;
    final statusColor = _colorForStatus(asset.complianceStatus);
    final dateFormat = DateFormat('dd MMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(asset.reference ?? type?.name ?? 'Asset'),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.edit),
            onPressed: _navigateToEdit,
          ),
          if (_canDelete)
            PopupMenuButton<String>(
              icon: const Icon(AppIcons.more),
              onSelected: (value) {
                if (value == 'delete') _confirmDelete();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                // Icon + type
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(_iconForType(type), color: typeColor, size: 32),
                ),
                const SizedBox(height: 12),
                Text(
                  type?.name ?? 'Unknown Type',
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700),
                ),
                if (asset.variant != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    asset.variant!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                // Status badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusLabel(asset.complianceStatus),
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppTheme.sectionGap),

          // Identity section
          _SectionHeader('Identity'),
          const SizedBox(height: 8),
          _DetailCard(
            isDark: isDark,
            children: [
              if (asset.reference != null)
                _DetailRow('Reference', asset.reference!, isDark),
              if (asset.make != null)
                _DetailRow('Make', asset.make!, isDark),
              if (asset.model != null)
                _DetailRow('Model', asset.model!, isDark),
              if (asset.serialNumber != null)
                _DetailRow('Serial Number', asset.serialNumber!, isDark),
              if (asset.barcode != null)
                _DetailRow('Barcode', asset.barcode!, isDark),
            ],
          ),

          // Location section
          if (asset.zone != null ||
              asset.locationDescription != null ||
              asset.floorPlanId != null) ...[
            const SizedBox(height: AppTheme.sectionGap),
            _SectionHeader('Location'),
            const SizedBox(height: 8),
            _DetailCard(
              isDark: isDark,
              children: [
                if (asset.zone != null)
                  _DetailRow('Zone', asset.zone!, isDark),
                if (asset.locationDescription != null)
                  _DetailRow(
                      'Description', asset.locationDescription!, isDark),
                if (asset.floorPlanId != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _viewOnFloorPlan(asset),
                      icon: const Icon(AppIcons.map, size: 18),
                      label: const Text('View on Floor Plan'),
                    ),
                  ),
              ],
            ),
          ],

          // Compliance section
          const SizedBox(height: AppTheme.sectionGap),
          _SectionHeader('Compliance'),
          const SizedBox(height: 8),
          _DetailCard(
            isDark: isDark,
            children: [
              _DetailRow('Status', _statusLabel(asset.complianceStatus), isDark),
              if (asset.lastServiceDate != null)
                _DetailRow('Last Service',
                    dateFormat.format(asset.lastServiceDate!), isDark),
              if (asset.lastServiceByName != null)
                _DetailRow('Serviced By', asset.lastServiceByName!, isDark),
              if (asset.nextServiceDue != null)
                _DetailRow('Next Due',
                    dateFormat.format(asset.nextServiceDue!), isDark),
            ],
          ),

          // Dates & Lifecycle
          if (asset.installDate != null ||
              asset.warrantyExpiry != null ||
              asset.expectedLifespanYears != null) ...[
            const SizedBox(height: AppTheme.sectionGap),
            _SectionHeader('Lifecycle'),
            const SizedBox(height: 8),
            _DetailCard(
              isDark: isDark,
              children: [
                if (asset.installDate != null)
                  _DetailRow('Install Date',
                      dateFormat.format(asset.installDate!), isDark),
                if (asset.warrantyExpiry != null)
                  _DetailRow('Warranty Expiry',
                      dateFormat.format(asset.warrantyExpiry!), isDark),
                if (asset.expectedLifespanYears != null)
                  _DetailRow('Expected Lifespan',
                      '${asset.expectedLifespanYears} years', isDark),
              ],
            ),
          ],

          // Notes
          if (asset.notes != null) ...[
            const SizedBox(height: AppTheme.sectionGap),
            _SectionHeader('Notes'),
            const SizedBox(height: 8),
            _DetailCard(
              isDark: isDark,
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    asset.notes!,
                    style: TextStyle(
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Service History placeholder
          const SizedBox(height: AppTheme.sectionGap),
          _SectionHeader('Service History'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(AppTheme.cardPadding),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              borderRadius: BorderRadius.circular(AppTheme.cardRadius),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Center(
              child: Column(
                children: [
                  Icon(AppIcons.clipboardTick,
                      size: 32,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary),
                  const SizedBox(height: 8),
                  Text(
                    'No service history yet',
                    style: TextStyle(
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white
            : AppTheme.textPrimary,
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final bool isDark;
  final List<Widget> children;

  const _DetailCard({required this.isDark, required this.children});

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(children: children),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _DetailRow(this.label, this.value, this.isDark);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
