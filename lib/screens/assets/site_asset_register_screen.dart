import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
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
import '../../services/inspection_visit_service.dart';
import '../../services/remote_config_service.dart';
import 'add_edit_asset_screen.dart';
import 'asset_detail_screen.dart';
import 'barcode_scanner_screen.dart';
import 'batch_test_screen.dart';
import 'asset_type_config_screen.dart';
import 'compliance_report_screen.dart';
import '../bs5839/bs5839_report_screen.dart';
import '../bs5839/bs5839_system_config_screen.dart';
import '../bs5839/start_inspection_visit_screen.dart';
import '../floor_plans/floor_plan_list_screen.dart';

class SiteAssetRegisterScreen extends StatefulWidget {
  final String siteId;
  final String siteName;
  final String siteAddress;
  final String basePath;

  const SiteAssetRegisterScreen({
    super.key,
    required this.siteId,
    required this.siteName,
    this.siteAddress = '',
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
  AssetComplianceStatus? _filterStatus;
  String? _filterLifecycle; // 'approaching' or 'past'
  bool _filterDrift = false;
  List<AssetType> _assetTypes = [];
  List<Asset> _latestAssets = [];

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
      case 'radar_heat':
        return AppIcons.radar;
      case 'door':
        return AppIcons.securitySafe;
      case 'flash':
        return AppIcons.flash;
      case 'batteryCharging':
        return AppIcons.batteryCharging;
      case 'slider':
        return AppIcons.slider;
      case 'microphone':
        return AppIcons.microphone;
      case 'call':
        return AppIcons.call;
      case 'notification':
        return AppIcons.notification;
      default:
        return AppIcons.setting;
    }
  }

  Color _colorForStatus(AssetComplianceStatus status) {
    switch (status) {
      case AssetComplianceStatus.pass:
        return const Color(0xFF4CAF50);
      case AssetComplianceStatus.fail:
        return const Color(0xFFD32F2F);
      case AssetComplianceStatus.decommissioned:
        return Colors.grey;
      case AssetComplianceStatus.untested:
        return const Color(0xFF9E9E9E);
    }
  }

  String _statusLabel(AssetComplianceStatus status) {
    return status.displayLabel;
  }

  bool _hasChecklistDrift(Asset asset) {
    if (asset.complianceStatus != AssetComplianceStatus.pass &&
        asset.complianceStatus != AssetComplianceStatus.fail) {
      return false;
    }
    final type = _getAssetType(asset.assetTypeId);
    if (type == null) return false;
    final tested = asset.lastChecklistVersionTested;
    if (tested == null) return false;
    return tested < type.checklistVersion;
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

    if (_filterDrift) {
      filtered = filtered.where((a) => _hasChecklistDrift(a)).toList();
    }

    if (_filterLifecycle != null) {
      filtered = filtered.where((a) {
        if (a.installDate == null || a.expectedLifespanYears == null) {
          return false;
        }
        final remaining = a.expectedLifespanYears! -
            DateTime.now().difference(a.installDate!).inDays / 365.25;
        if (_filterLifecycle == 'approaching') {
          return remaining > 0 && remaining < 1;
        }
        return remaining <= 0; // 'past'
      }).toList();
    }

    return filtered;
  }

  void _navigateToAddAsset() {
    if (kIsWeb) {
      context.go('/sites/${widget.siteId}/assets/add');
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => AddEditAssetScreen(
            basePath: widget.basePath,
            siteId: widget.siteId,
          ),
        ),
      );
    }
  }

  void _navigateToBatchTest() {
    final testableAssets = _latestAssets
        .where((a) => a.complianceStatus != AssetComplianceStatus.decommissioned)
        .toList();

    if (testableAssets.isEmpty) {
      context.showErrorToast('No testable assets');
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BatchTestScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          assets: testableAssets,
          assetTypes: _assetTypes,
        ),
      ),
    );
  }

  void _navigateToAssetDetail(Asset asset) {
    if (kIsWeb) {
      context.go('/sites/${widget.siteId}/assets/${asset.id}');
    } else {
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
  }

  void _showReportTypeSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Choose Report Type',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              ListTile(
                leading: Icon(AppIcons.clipboard,
                    color: Colors.orange),
                title: const Text('Site Compliance Summary'),
                subtitle: const Text('General asset compliance overview'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  Navigator.pop(context);
                  if (kIsWeb) {
                    context.go('/sites/${widget.siteId}/assets/report');
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ComplianceReportScreen(
                          basePath: widget.basePath,
                          siteId: widget.siteId,
                          siteName: widget.siteName,
                          siteAddress: widget.siteAddress,
                        ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(AppIcons.document,
                    color: AppTheme.primaryBlue),
                title: const Text('BS 5839-1:2025 Inspection Report'),
                subtitle: const Text(
                    'Full BS 5839 report for a completed visit'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                onTap: () {
                  Navigator.pop(context);
                  _selectVisitForBs5839Report();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectVisitForBs5839Report() async {
    final visits = await InspectionVisitService.instance
        .getVisitsStream(widget.basePath, widget.siteId)
        .first;
    final completed = visits.where((v) => v.completedAt != null).toList();

    if (!mounted) return;

    if (completed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('No completed visits. Complete an inspection first.')),
      );
      return;
    }

    if (completed.length == 1) {
      _openBs5839Report(completed.first.id);
      return;
    }

    final selected = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Visit',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              ...completed.take(10).map(
                    (v) => ListTile(
                      title: Text(v.visitType.displayLabel),
                      subtitle: Text(
                        '${v.declaration.displayLabel} · ${v.engineerName}',
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      onTap: () => Navigator.pop(context, v.id),
                    ),
                  ),
            ],
          ),
        ),
      ),
    );

    if (selected != null && mounted) {
      _openBs5839Report(selected);
    }
  }

  void _openBs5839Report(String visitId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Bs5839ReportScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          siteName: widget.siteName,
          siteAddress: widget.siteAddress,
          visitId: visitId,
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
        leading: kIsWeb
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/sites'),
              )
            : null,
      ),
      floatingActionButton: MediaQuery.of(context).viewInsets.bottom > 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _navigateToAddAsset,
              icon: const Icon(AppIcons.add),
              label: const Text('Add Asset'),
            ),
      body: KeyboardDismissWrapper(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
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

            // Action cards
            _buildActionCards(isDark),
            const SizedBox(height: 8),

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
                  const SizedBox(width: 8),
                  // Drift filter
                  _FilterChip(
                    label: 'Needs re-test',
                    selected: _filterDrift,
                    onTap: () =>
                        setState(() => _filterDrift = !_filterDrift),
                    onClear: _filterDrift
                        ? () => setState(() => _filterDrift = false)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  // Lifecycle filter
                  _FilterChip(
                    label: _filterLifecycle == 'approaching'
                        ? 'Approaching EOL'
                        : _filterLifecycle == 'past'
                            ? 'Past EOL'
                            : 'Lifecycle',
                    selected: _filterLifecycle != null,
                    onTap: () => _showLifecycleFilter(context),
                    onClear: _filterLifecycle != null
                        ? () => setState(() => _filterLifecycle = null)
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
                  _latestAssets = allAssets;

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
        ),
      ),
    );
  }

  Widget _buildActionCards(bool isDark) {
    final rc = RemoteConfigService.instance;

    final cards = <Widget>[
      _buildActionCard(
        'Floor Plans', AppIcons.map, Colors.blue,
        () {
          if (kIsWeb) {
            context.go('/sites/${widget.siteId}/floor-plans');
          } else {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => FloorPlanListScreen(
                  siteId: widget.siteId,
                  siteName: widget.siteName,
                  basePath: widget.basePath,
                ),
              ),
            );
          }
        },
        isDark,
      ),
      if (!kIsWeb)
        _buildActionCard(
          'Batch Test', AppIcons.clipboardTick, Colors.green,
          _navigateToBatchTest,
          isDark,
        ),
      if (!kIsWeb && rc.barcodeScanningEnabled)
        _buildActionCard(
          'Scan Barcode', AppIcons.scanner, Colors.purple,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BarcodeScannerScreen(
                  basePath: widget.basePath,
                  siteId: widget.siteId,
                ),
              ),
            );
          },
          isDark,
        ),
      if (rc.complianceReportEnabled)
        _buildActionCard(
          'Report', AppIcons.document, Colors.orange,
          () {
            if (rc.bs5839ModeEnabled) {
              _showReportTypeSheet();
            } else if (kIsWeb) {
              context.go('/sites/${widget.siteId}/assets/report');
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ComplianceReportScreen(
                    basePath: widget.basePath,
                    siteId: widget.siteId,
                    siteName: widget.siteName,
                    siteAddress: widget.siteAddress,
                  ),
                ),
              );
            }
          },
          isDark,
        ),
      if (rc.bs5839ModeEnabled)
        _buildActionCard(
          'BS 5839', AppIcons.shield, Colors.deepPurple,
          () {
            if (kIsWeb) {
              context.go('/sites/${widget.siteId}/assets/bs5839-config');
            } else {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Bs5839SystemConfigScreen(
                    basePath: widget.basePath,
                    siteId: widget.siteId,
                    siteName: widget.siteName,
                  ),
                ),
              );
            }
          },
          isDark,
        ),
      if (rc.bs5839ModeEnabled && !kIsWeb)
        _buildActionCard(
          'Start Visit', AppIcons.clipboardTick, Colors.teal,
          () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StartInspectionVisitScreen(
                  basePath: widget.basePath,
                  siteId: widget.siteId,
                  siteName: widget.siteName,
                ),
              ),
            );
          },
          isDark,
        ),
      _buildActionCard(
        'Manage Types', AppIcons.setting, Colors.grey,
        () {
          if (kIsWeb) {
            context.go('/sites/${widget.siteId}/assets/types');
          } else {
            Navigator.of(context)
                .push(
              MaterialPageRoute(
                builder: (_) => AssetTypeConfigScreen(
                  basePath: widget.basePath,
                ),
              ),
            )
                .then((_) => _loadAssetTypes());
          }
        },
        isDark,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            cards[i],
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard(
    String label, IconData icon, Color color, VoidCallback onTap, bool isDark,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? color.withValues(alpha: 0.12)
                : color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildComplianceSummary(List<Asset> assets, bool isDark) {
    final pass =
        assets.where((a) => a.complianceStatus == AssetComplianceStatus.pass).length;
    final fail =
        assets.where((a) => a.complianceStatus == AssetComplianceStatus.fail).length;
    final untested =
        assets.where((a) => a.complianceStatus == AssetComplianceStatus.untested).length;
    final decom = assets
        .where((a) => a.complianceStatus == AssetComplianceStatus.decommissioned)
        .length;
    final active = assets.length - decom;
    final drift = assets.where((a) => _hasChecklistDrift(a)).length;

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
          if (drift > 0) ...[
            const SizedBox(width: 12),
            _SummaryDot(
                color: const Color(0xFFF59E0B), count: drift, label: 'Re-test'),
          ],
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
    final drift = _hasChecklistDrift(asset);

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
            // Checklist drift badge
            if (drift)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Re-test',
                    style: TextStyle(
                      color: Color(0xFFF59E0B),
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            // Lifecycle warning
            if (asset.installDate != null &&
                asset.expectedLifespanYears != null)
              Builder(builder: (_) {
                final remaining = asset.expectedLifespanYears! -
                    DateTime.now()
                            .difference(asset.installDate!)
                            .inDays /
                        365.25;
                if (remaining >= 1) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    AppIcons.danger,
                    size: 16,
                    color: remaining <= 0
                        ? const Color(0xFFD32F2F)
                        : const Color(0xFFF59E0B),
                  ),
                );
              }),
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
              AssetComplianceStatus.pass,
              AssetComplianceStatus.fail,
              AssetComplianceStatus.untested,
              AssetComplianceStatus.decommissioned,
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

  void _showLifecycleFilter(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: const Text('All'),
              onTap: () {
                setState(() => _filterLifecycle = null);
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.danger, color: const Color(0xFFF59E0B)),
              title: const Text('Approaching End of Life'),
              subtitle: const Text('Less than 1 year remaining'),
              selected: _filterLifecycle == 'approaching',
              onTap: () {
                setState(() => _filterLifecycle = 'approaching');
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: Icon(AppIcons.danger, color: const Color(0xFFD32F2F)),
              title: const Text('Past End of Life'),
              subtitle: const Text('Exceeded expected lifespan'),
              selected: _filterLifecycle == 'past',
              onTap: () {
                setState(() => _filterLifecycle = 'past');
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
