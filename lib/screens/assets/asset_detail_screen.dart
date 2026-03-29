import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../models/service_record.dart';
import '../../data/default_asset_types.dart';
import '../../models/defect.dart';
import '../../services/asset_service.dart';
import '../../services/asset_type_service.dart';
import '../../services/defect_service.dart';
import '../../services/service_history_service.dart';
import '../../services/analytics_service.dart';
import '../../services/user_profile_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';
import '../../services/floor_plan_service.dart';
import 'add_edit_asset_screen.dart';
import 'barcode_scanner_screen.dart';
import 'inspection_checklist_screen.dart';
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
      case 'radar_heat': return AppIcons.radar;
      case 'door': return AppIcons.securitySafe;
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
    if (kIsWeb) {
      context.go(
        '/sites/${widget.siteId}/assets/${widget.assetId}/edit',
        extra: _asset,
      );
    } else {
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

  Future<void> _showDecommissionDialog() async {
    if (_asset == null) return;
    String? reason;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Decommission Asset'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('This asset will be marked as decommissioned '
                      'and excluded from active compliance counts.'),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: reason,
                    decoration: const InputDecoration(
                      labelText: 'Reason',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'end_of_life', child: Text('End of Life')),
                      DropdownMenuItem(value: 'replaced', child: Text('Replaced')),
                      DropdownMenuItem(value: 'damaged', child: Text('Damaged')),
                      DropdownMenuItem(value: 'removed', child: Text('Removed')),
                      DropdownMenuItem(value: 'other', child: Text('Other')),
                    ],
                    onChanged: (val) => setDialogState(() => reason = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: reason == null
                      ? null
                      : () => Navigator.of(ctx).pop(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentOrange,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Decommission'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && reason != null && mounted) {
      try {
        await AssetService.instance.updateAsset(
          widget.basePath,
          widget.siteId,
          _asset!.copyWith(
            complianceStatus: Asset.statusDecommissioned,
            decommissionDate: DateTime.now(),
            decommissionReason: reason,
          ),
        );
        AnalyticsService.instance.logAssetDecommissioned(
          assetType: _asset!.assetTypeId,
          reason: reason!,
          siteId: widget.siteId,
        );
        if (mounted) {
          context.showSuccessToast('Asset decommissioned');
          _loadAsset();
        }
      } catch (e) {
        if (mounted) context.showErrorToast('Failed to decommission asset');
      }
    }
  }

  Future<void> _scanBarcode() async {
    if (_asset == null) return;
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => BarcodeScannerScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          mode: ScannerMode.capture,
        ),
      ),
    );
    if (result != null && mounted) {
      try {
        await AssetService.instance.updateAsset(
          widget.basePath,
          widget.siteId,
          _asset!.copyWith(barcode: result),
        );
        AnalyticsService.instance.logBarcodeScan(
          result: 'assigned',
          siteId: widget.siteId,
        );
        if (mounted) context.showSuccessToast('Barcode assigned');
        _loadAsset();
      } catch (e) {
        if (mounted) context.showErrorToast('Failed to assign barcode');
      }
    }
  }

  Future<void> _navigateToInspection() async {
    if (_asset == null || _assetType == null) return;
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InspectionChecklistScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          asset: _asset!,
          assetType: _assetType!,
        ),
      ),
    );
    if (result == true) _loadAsset();
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
          PopupMenuButton<String>(
              icon: const Icon(AppIcons.more),
              onSelected: (value) {
                if (value == 'delete') _confirmDelete();
                if (value == 'scan_barcode' && !kIsWeb) _scanBarcode();
                if (value == 'decommission') _showDecommissionDialog();
              },
              itemBuilder: (_) => [
                if (!kIsWeb)
                  const PopupMenuItem(
                    value: 'scan_barcode',
                    child: Text('Scan Barcode'),
                  ),
                if (asset.complianceStatus != Asset.statusDecommissioned)
                  const PopupMenuItem(
                    value: 'decommission',
                    child: Text('Decommission'),
                  ),
                if (_canDelete)
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

          // Test button
          if (asset.complianceStatus != Asset.statusDecommissioned) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToInspection,
                icon: Icon(AppIcons.clipboardTick),
                label: const Text('Test This Asset'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

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
                // Lifecycle progress bar
                if (asset.installDate != null &&
                    asset.expectedLifespanYears != null)
                  _LifecycleProgressBar(asset: asset, isDark: isDark),
                // Warranty badge
                if (asset.warrantyExpiry != null)
                  _WarrantyBadge(
                      warrantyExpiry: asset.warrantyExpiry!, isDark: isDark),
              ],
            ),
          ],
          // Decommission info
          if (asset.complianceStatus == Asset.statusDecommissioned) ...[
            const SizedBox(height: AppTheme.sectionGap),
            _SectionHeader('Decommissioned'),
            const SizedBox(height: 8),
            _DetailCard(
              isDark: isDark,
              children: [
                if (asset.decommissionDate != null)
                  _DetailRow('Date',
                      dateFormat.format(asset.decommissionDate!), isDark),
                if (asset.decommissionReason != null)
                  _DetailRow('Reason',
                      asset.decommissionReason!.replaceAll('_', ' '), isDark),
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

          // Active Defects
          StreamBuilder<List<Defect>>(
            stream: DefectService.instance.getDefectsForAsset(
                widget.basePath, widget.siteId, asset.id),
            builder: (context, snapshot) {
              final allDefects = snapshot.data ?? [];
              final openDefects = allDefects
                  .where((d) => d.status == Defect.statusOpen)
                  .toList();
              if (openDefects.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppTheme.sectionGap),
                  _SectionHeader('Active Defects'),
                  const SizedBox(height: 8),
                  ...openDefects.map((defect) => _ActiveDefectCard(
                        defect: defect,
                        isDark: isDark,
                        basePath: widget.basePath,
                        siteId: widget.siteId,
                      )),
                ],
              );
            },
          ),

          // Service History
          const SizedBox(height: AppTheme.sectionGap),
          _SectionHeader('Service History'),
          const SizedBox(height: 8),
          StreamBuilder<List<ServiceRecord>>(
            stream: ServiceHistoryService.instance.getRecordsForAsset(
                widget.basePath, widget.siteId, asset.id),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: Padding(
                  padding: EdgeInsets.all(20),
                  child: AdaptiveLoadingIndicator(),
                ));
              }
              final records = snapshot.data ?? [];
              if (records.isEmpty) {
                return Container(
                  padding: const EdgeInsets.all(AppTheme.cardPadding),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppTheme.darkSurfaceElevated
                        : Colors.white,
                    borderRadius:
                        BorderRadius.circular(AppTheme.cardRadius),
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
                );
              }
              return Column(
                children: records
                    .map((r) =>
                        _ServiceRecordCard(record: r, isDark: isDark))
                    .toList(),
              );
            },
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

class _LifecycleProgressBar extends StatelessWidget {
  final Asset asset;
  final bool isDark;

  const _LifecycleProgressBar({required this.asset, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ageYears =
        now.difference(asset.installDate!).inDays / 365.25;
    final lifespan = asset.expectedLifespanYears!.toDouble();
    final progress = (ageYears / lifespan).clamp(0.0, 1.0);
    final remaining = lifespan - ageYears;

    Color barColor;
    if (progress < 0.7) {
      barColor = const Color(0xFF4CAF50);
    } else if (progress < 0.9) {
      barColor = const Color(0xFFF59E0B);
    } else {
      barColor = const Color(0xFFD32F2F);
    }

    String statusText;
    if (remaining <= 0) {
      statusText = '${(-remaining).toStringAsFixed(1)} years past end of life';
    } else if (remaining < 1) {
      statusText = 'Approaching end of life (${(remaining * 12).round()} months remaining)';
    } else {
      statusText = '${ageYears.toStringAsFixed(1)} of ${lifespan.toInt()} years';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Age',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: barColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
          if (remaining <= 0) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(AppIcons.danger, size: 14, color: const Color(0xFFD32F2F)),
                const SizedBox(width: 4),
                Text(
                  'Past end of life',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFD32F2F),
                  ),
                ),
              ],
            ),
          ] else if (remaining < 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(AppIcons.danger, size: 14, color: const Color(0xFFF59E0B)),
                const SizedBox(width: 4),
                Text(
                  'Approaching end of life',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _WarrantyBadge extends StatelessWidget {
  final DateTime warrantyExpiry;
  final bool isDark;

  const _WarrantyBadge({required this.warrantyExpiry, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final active = DateTime.now().isBefore(warrantyExpiry);
    final color = active ? const Color(0xFF4CAF50) : Colors.grey;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? AppIcons.tickCircle : AppIcons.close,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 6),
            Text(
              active ? 'Under Warranty' : 'Warranty Expired',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
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

class _ServiceRecordCard extends StatefulWidget {
  final ServiceRecord record;
  final bool isDark;

  const _ServiceRecordCard({required this.record, required this.isDark});

  @override
  State<_ServiceRecordCard> createState() => _ServiceRecordCardState();
}

class _ServiceRecordCardState extends State<_ServiceRecordCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    final isDark = widget.isDark;
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');
    final isPass = r.overallResult == 'pass';
    final resultColor =
        isPass ? const Color(0xFF4CAF50) : const Color(0xFFD32F2F);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => setState(() => _expanded = !_expanded),
        child: AnimatedContainer(
          duration: AppTheme.fastAnimation,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary row
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPass ? AppIcons.tickCircle : AppIcons.close,
                      color: resultColor,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dateFormat.format(r.serviceDate),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          r.engineerName,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: resultColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isPass ? 'Pass' : 'Fail',
                      style: TextStyle(
                        color: resultColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _expanded ? AppIcons.arrowUp : AppIcons.arrowDown,
                    size: 16,
                    color: isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.textSecondary,
                  ),
                ],
              ),

              // Expanded details
              if (_expanded) ...[
                const SizedBox(height: 12),
                const Divider(height: 1),
                const SizedBox(height: 12),
                // Checklist results
                if (r.checklistResults.isNotEmpty) ...[
                  ...r.checklistResults.map((cr) {
                    final crPass = cr.result == 'pass' || cr.result == 'yes';
                    final crFail = cr.result == 'fail' || cr.result == 'no';
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            crPass
                                ? AppIcons.tickCircle
                                : crFail
                                    ? AppIcons.close
                                    : AppIcons.note,
                            size: 14,
                            color: crPass
                                ? const Color(0xFF4CAF50)
                                : crFail
                                    ? const Color(0xFFD32F2F)
                                    : isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              cr.label,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          Text(
                            cr.result,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: crPass
                                  ? const Color(0xFF4CAF50)
                                  : crFail
                                      ? const Color(0xFFD32F2F)
                                      : isDark
                                          ? Colors.white
                                          : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
                // Defect info
                if (r.defectSeverity != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(AppIcons.danger,
                          size: 14, color: const Color(0xFFD32F2F)),
                      const SizedBox(width: 6),
                      Text(
                        'Defect: ${r.defectSeverity}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                      if (r.defectAction != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${r.defectAction!.replaceAll('_', ' ')})',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
                if (r.defectNote != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    r.defectNote!,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
                // Defect photos
                if (r.defectPhotoUrls.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 60,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: r.defectPhotoUrls.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 6),
                      itemBuilder: (_, i) => ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          r.defectPhotoUrls[i],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ],
                // General notes
                if (r.notes != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    r.notes!,
                    style: TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: isDark
                          ? AppTheme.darkTextSecondary
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Active Defect Card ────────────────────────────────────────────

class _ActiveDefectCard extends StatelessWidget {
  final Defect defect;
  final bool isDark;
  final String basePath;
  final String siteId;

  const _ActiveDefectCard({
    required this.defect,
    required this.isDark,
    required this.basePath,
    required this.siteId,
  });

  Color get _severityColor {
    switch (defect.severity) {
      case Defect.severityCritical:
        return const Color(0xFFD32F2F);
      case Defect.severityMajor:
        return const Color(0xFFF59E0B);
      default:
        return Colors.grey;
    }
  }

  void _showRectifyDialog(BuildContext context) {
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark as Rectified'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              defect.description,
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: noteController,
              label: 'Rectification Note',
              hint: 'Optional',
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final nav = Navigator.of(ctx);
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              try {
                final user =
                    FirebaseAuth.instance.currentUser;
                if (user == null) return;

                await DefectService.instance.rectifyDefect(
                  basePath,
                  siteId,
                  defect.id,
                  rectifiedBy: user.uid,
                  rectifiedByName:
                      user.displayName ?? 'Unknown',
                  rectifiedNote:
                      noteController.text.trim().isNotEmpty
                          ? noteController.text.trim()
                          : null,
                );
                nav.pop();
              } catch (e) {
                nav.pop();
                scaffoldMessenger.showSnackBar(
                  const SnackBar(
                      content: Text('Failed to rectify defect')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4CAF50),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('dd MMM yyyy').format(defect.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: _severityColor.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _severityColor,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  defect.severity.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                dateStr,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const Spacer(),
              SizedBox(
                height: 30,
                child: OutlinedButton(
                  onPressed: () => _showRectifyDialog(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    side: const BorderSide(color: Color(0xFF4CAF50)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Mark Rectified',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4CAF50),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            defect.description,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            ),
          ),
          if (defect.createdByName.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Reported by ${defect.createdByName}',
              style: TextStyle(
                fontSize: 11,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
