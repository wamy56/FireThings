import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../models/service_record.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/defect_service.dart';
import '../../services/service_history_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/defect_bottom_sheet.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/premium_toast.dart';

class BatchTestScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final List<Asset> assets;
  final List<AssetType> assetTypes;
  final String? jobsheetId;

  const BatchTestScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.assets,
    required this.assetTypes,
    this.jobsheetId,
  });

  @override
  State<BatchTestScreen> createState() => _BatchTestScreenState();
}

class _BatchTestScreenState extends State<BatchTestScreen> {
  // Results: assetId -> 'pass' | 'fail'
  final Map<String, String> _results = {};
  int _defectsRecorded = 0;
  bool _completedExpanded = true;

  // Filters
  String? _filterTypeId;
  String? _filterZone;

  // Open defect counts per asset
  Map<String, int> _openDefectCounts = {};

  // Saving state per asset
  final Set<String> _savingAssetIds = {};

  @override
  void initState() {
    super.initState();
    _loadOpenDefectCounts();
  }

  Future<void> _loadOpenDefectCounts() async {
    final counts = <String, int>{};
    for (final asset in widget.assets) {
      final defects = await DefectService.instance.getOpenDefectsForAsset(
        widget.basePath,
        widget.siteId,
        asset.id,
      );
      if (defects.isNotEmpty) counts[asset.id] = defects.length;
    }
    if (mounted) setState(() => _openDefectCounts = counts);
  }

  AssetType? _getAssetType(String typeId) {
    try {
      return widget.assetTypes.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return DefaultAssetTypes.getById(typeId);
    }
  }

  List<Asset> get _untestedAssets {
    var assets = widget.assets
        .where((a) => !_results.containsKey(a.id))
        .toList();
    if (_filterTypeId != null) {
      assets = assets.where((a) => a.assetTypeId == _filterTypeId).toList();
    }
    if (_filterZone != null) {
      assets = assets.where((a) => a.zone == _filterZone).toList();
    }
    return assets;
  }

  List<Asset> get _testedAssets =>
      widget.assets.where((a) => _results.containsKey(a.id)).toList();

  Set<String> get _availableTypeIds =>
      widget.assets.map((a) => a.assetTypeId).toSet();

  Set<String> get _availableZones =>
      widget.assets.where((a) => a.zone != null).map((a) => a.zone!).toSet();

  Future<void> _passAsset(Asset asset) async {
    if (_savingAssetIds.contains(asset.id)) return;
    setState(() => _savingAssetIds.add(asset.id));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not signed in');

      final now = DateTime.now();
      final record = ServiceRecord(
        id: const Uuid().v4(),
        assetId: asset.id,
        siteId: widget.siteId,
        jobsheetId: widget.jobsheetId,
        engineerId: user.uid,
        engineerName: user.displayName ?? 'Unknown',
        serviceDate: now,
        overallResult: 'pass',
        createdAt: now,
      );

      await ServiceHistoryService.instance
          .createRecord(widget.basePath, widget.siteId, record);

      await AssetService.instance.updateAsset(
        widget.basePath,
        widget.siteId,
        asset.copyWith(
          complianceStatus: Asset.statusPass,
          lastServiceDate: now,
          lastServiceBy: user.uid,
          lastServiceByName: user.displayName ?? 'Unknown',
          nextServiceDue: DateTime(now.year + 1, now.month, now.day),
        ),
      );

      final rectifiedCount = await DefectService.instance.rectifyAllForAsset(
        widget.basePath,
        widget.siteId,
        asset.id,
        rectifiedBy: user.uid,
        rectifiedByName: user.displayName ?? 'Unknown',
      );
      if (rectifiedCount > 0) _openDefectCounts.remove(asset.id);

      AnalyticsService.instance.logAssetTested(
        assetType: asset.assetTypeId,
        result: 'pass',
        siteId: widget.siteId,
      );

      setState(() {
        _results[asset.id] = 'pass';
        _savingAssetIds.remove(asset.id);
      });
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Failed to save');
        setState(() => _savingAssetIds.remove(asset.id));
      }
    }
  }

  Future<void> _failAsset(Asset asset) async {
    final assetType = _getAssetType(asset.assetTypeId);
    final result = await showDefectBottomSheet(
      context: context,
      basePath: widget.basePath,
      siteId: widget.siteId,
      asset: asset,
      assetType: assetType,
      jobsheetId: widget.jobsheetId,
    );

    if (result == true) {
      setState(() {
        _results[asset.id] = 'fail';
        _defectsRecorded++;
        _openDefectCounts[asset.id] =
            (_openDefectCounts[asset.id] ?? 0) + 1;
      });
    }
  }

  void _finish() {
    final passCount = _results.values.where((r) => r == 'pass').length;
    final failCount = _results.values.where((r) => r == 'fail').length;

    AnalyticsService.instance.logBatchTestingCompleted(
      siteId: widget.siteId,
      passCount: passCount,
      failCount: failCount,
      skippedCount: widget.assets.length - _results.length,
    );

    Navigator.of(context).pop();
  }

  Future<bool> _confirmExit() async {
    if (_results.isEmpty) return true;
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Stop Batch Testing?',
      message: 'Tests already saved will be kept.',
      confirmLabel: 'Stop',
      cancelLabel: 'Continue Testing',
      isDestructive: true,
    );
    return confirmed == true;
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final untested = _untestedAssets;
    final tested = _testedAssets;
    final passCount = _results.values.where((r) => r == 'pass').length;
    final failCount = _results.values.where((r) => r == 'fail').length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        if (await _confirmExit() && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Batch Test (${_results.length}/${widget.assets.length})'),
          leading: IconButton(
            icon: const Icon(AppIcons.close),
            onPressed: () async {
              final nav = Navigator.of(context);
              if (await _confirmExit() && mounted) nav.pop();
            },
          ),
          actions: [
            if (_results.isNotEmpty)
              TextButton(
                onPressed: _finish,
                child: const Text('Done'),
              ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 750),
            child: Column(
          children: [
            // Summary bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey.shade50,
              child: Row(
                children: [
                  _MiniStat(
                      label: 'Pass', count: passCount, color: const Color(0xFF4CAF50)),
                  const SizedBox(width: 16),
                  _MiniStat(
                      label: 'Fail', count: failCount, color: const Color(0xFFD32F2F)),
                  const SizedBox(width: 16),
                  _MiniStat(
                    label: 'Remaining',
                    count: widget.assets.length - _results.length,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                  if (_defectsRecorded > 0) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD32F2F).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$_defectsRecorded defect${_defectsRecorded == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFFD32F2F),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Filter chips
            if (_availableTypeIds.length > 1 || _availableZones.isNotEmpty)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    // Type filters
                    FilterChip(
                      label: const Text('All Types'),
                      selected: _filterTypeId == null,
                      onSelected: (_) =>
                          setState(() => _filterTypeId = null),
                    ),
                    ..._availableTypeIds.map((typeId) {
                      final type = _getAssetType(typeId);
                      return Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: FilterChip(
                          label: Text(type?.name ?? typeId),
                          selected: _filterTypeId == typeId,
                          onSelected: (_) =>
                              setState(() => _filterTypeId =
                                  _filterTypeId == typeId ? null : typeId),
                        ),
                      );
                    }),
                    if (_availableZones.isNotEmpty) ...[
                      const SizedBox(width: 12),
                      Container(
                        width: 1,
                        height: 24,
                        color: isDark
                            ? Colors.grey.shade700
                            : Colors.grey.shade300,
                      ),
                      const SizedBox(width: 12),
                      FilterChip(
                        label: const Text('All Zones'),
                        selected: _filterZone == null,
                        onSelected: (_) =>
                            setState(() => _filterZone = null),
                      ),
                      ..._availableZones.map((zone) => Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: FilterChip(
                              label: Text('Zone $zone'),
                              selected: _filterZone == zone,
                              onSelected: (_) => setState(() =>
                                  _filterZone =
                                      _filterZone == zone ? null : zone),
                            ),
                          )),
                    ],
                  ],
                ),
              ),

            // Asset list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  // Untested assets
                  ...untested.map((asset) => _AssetTestCard(
                        key: ValueKey(asset.id),
                        asset: asset,
                        assetType: _getAssetType(asset.assetTypeId),
                        iconForType: _iconForType,
                        openDefectCount: _openDefectCounts[asset.id] ?? 0,
                        isSaving: _savingAssetIds.contains(asset.id),
                        isDark: isDark,
                        onPass: () => _passAsset(asset),
                        onFail: () => _failAsset(asset),
                      )),

                  // Completed section
                  if (tested.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => setState(
                          () => _completedExpanded = !_completedExpanded),
                      child: Row(
                        children: [
                          Icon(
                            _completedExpanded
                                ? AppIcons.arrowDown
                                : AppIcons.arrowRight,
                            size: 16,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Completed (${tested.length})',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_completedExpanded) ...[
                      const SizedBox(height: 8),
                      ...tested.map((asset) {
                        final result = _results[asset.id]!;
                        final type = _getAssetType(asset.assetTypeId);
                        final isPassed = result == 'pass';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurfaceElevated
                                    .withValues(alpha: 0.5)
                                : Colors.grey.shade50,
                            borderRadius:
                                BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isPassed
                                    ? AppIcons.tickCircle
                                    : AppIcons.close,
                                size: 16,
                                color: isPassed
                                    ? const Color(0xFF4CAF50)
                                    : const Color(0xFFD32F2F),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${asset.reference ?? type?.name ?? 'Asset'}${asset.zone != null ? ' · Zone ${asset.zone}' : ''}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark
                                        ? AppTheme.darkTextSecondary
                                        : AppTheme.textSecondary,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isPassed
                                      ? const Color(0xFF4CAF50)
                                      : const Color(0xFFD32F2F),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isPassed ? 'PASS' : 'FAIL',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}

// ─── Asset Test Card ───────────────────────────────────────────────

class _AssetTestCard extends StatelessWidget {
  final Asset asset;
  final AssetType? assetType;
  final IconData Function(AssetType?) iconForType;
  final int openDefectCount;
  final bool isSaving;
  final bool isDark;
  final VoidCallback onPass;
  final VoidCallback onFail;

  const _AssetTestCard({
    super.key,
    required this.asset,
    this.assetType,
    required this.iconForType,
    required this.openDefectCount,
    required this.isSaving,
    required this.isDark,
    required this.onPass,
    required this.onFail,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = assetType != null
        ? Color(
            int.parse(assetType!.defaultColor.replaceFirst('#', '0xFF')))
        : Colors.grey;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(iconForType(assetType),
                    color: typeColor, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.reference ?? assetType?.name ?? 'Asset',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      [
                        assetType?.name,
                        if (asset.variant != null) asset.variant,
                      ].whereType<String>().join(' · '),
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
              if (openDefectCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD32F2F),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(AppIcons.danger,
                          color: Colors.white, size: 10),
                      const SizedBox(width: 3),
                      Text(
                        '$openDefectCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (asset.locationDescription != null || asset.zone != null) ...[
            const SizedBox(height: 6),
            Text(
              [
                if (asset.zone != null) 'Zone ${asset.zone}',
                if (asset.locationDescription != null)
                  asset.locationDescription,
              ].join(' · '),
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: onPass,
                      icon: const Icon(AppIcons.tickCircle, size: 16),
                      label: const Text('Pass'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4CAF50),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      onPressed: onFail,
                      icon: Icon(AppIcons.close, size: 16),
                      label: const Text('Fail'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        textStyle: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

// ─── Mini Stat ─────────────────────────────────────────────────────

class _MiniStat extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _MiniStat({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: color,
          ),
        ),
      ],
    );
  }
}
