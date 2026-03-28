import 'package:flutter/material.dart';
import '../../models/asset.dart';
import '../../models/asset_type.dart';
import '../../data/default_asset_types.dart';
import '../../services/asset_service.dart';
import '../../services/analytics_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../widgets/premium_dialog.dart';
import '../../widgets/premium_toast.dart';
import 'inspection_checklist_screen.dart';

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
  int _currentIndex = 0;
  final List<String> _outcomes = []; // "pass", "fail", "skipped"
  bool _isComplete = false;

  @override
  void initState() {
    super.initState();
    _outcomes.addAll(List.filled(widget.assets.length, ''));
  }

  AssetType? _getAssetType(String typeId) {
    try {
      return widget.assetTypes.firstWhere((t) => t.id == typeId);
    } catch (_) {
      return DefaultAssetTypes.getById(typeId);
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

  Future<void> _testCurrentAsset() async {
    final asset = widget.assets[_currentIndex];
    final assetType = _getAssetType(asset.assetTypeId);
    if (assetType == null) {
      if (mounted) context.showErrorToast('Unknown asset type — skipping');
      _skip();
      return;
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InspectionChecklistScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          asset: asset,
          assetType: assetType,
          jobsheetId: widget.jobsheetId,
        ),
      ),
    );

    if (result == true) {
      // Re-fetch asset to get updated status
      final updated = await AssetService.instance
          .getAsset(widget.basePath, widget.siteId, asset.id);
      setState(() {
        _outcomes[_currentIndex] = updated?.complianceStatus ?? 'pass';
      });
      _advance();
    }
  }

  void _skip() {
    setState(() => _outcomes[_currentIndex] = 'skipped');
    _advance();
  }

  void _advance() {
    if (_currentIndex + 1 >= widget.assets.length) {
      _complete();
    } else {
      setState(() => _currentIndex++);
    }
  }

  void _complete() {
    final passCount = _outcomes.where((o) => o == 'pass').length;
    final failCount = _outcomes.where((o) => o == 'fail').length;
    final skippedCount = _outcomes.where((o) => o == 'skipped').length;

    AnalyticsService.instance.logBatchTestingCompleted(
      siteId: widget.siteId,
      passCount: passCount,
      failCount: failCount,
      skippedCount: skippedCount,
    );

    setState(() => _isComplete = true);
  }

  Future<bool> _confirmExit() async {
    final confirmed = await showAdaptiveAlertDialog<bool>(
      context: context,
      title: 'Stop Batch Testing?',
      message:
          'Tests already saved will be kept. Are you sure you want to stop?',
      confirmLabel: 'Stop',
      cancelLabel: 'Continue Testing',
      isDestructive: true,
    );
    return confirmed == true;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isComplete) return _buildSummary(isDark);

    final asset = widget.assets[_currentIndex];
    final assetType = _getAssetType(asset.assetTypeId);
    final typeColor = assetType != null
        ? Color(
            int.parse(assetType.defaultColor.replaceFirst('#', '0xFF')))
        : Colors.grey;
    final progress = (_currentIndex + 1) / widget.assets.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final nav = Navigator.of(context);
        final shouldPop = await _confirmExit();
        if (shouldPop && mounted) nav.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
              'Testing ${_currentIndex + 1} of ${widget.assets.length}'),
          leading: IconButton(
            icon: const Icon(AppIcons.close),
            onPressed: () async {
              final nav = Navigator.of(context);
              final shouldPop = await _confirmExit();
              if (shouldPop && mounted) nav.pop();
            },
          ),
        ),
        body: Column(
          children: [
            // Progress bar
            LinearProgressIndicator(
              value: progress,
              backgroundColor: isDark
                  ? Colors.grey.shade800
                  : Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(
                  AppTheme.accentOrange),
              minHeight: 4,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.screenPadding),
                child: Column(
                  children: [
                    const Spacer(),
                    // Asset card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppTheme.darkSurfaceElevated
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppTheme.cardRadius),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color:
                                  typeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(_iconForType(assetType),
                                color: typeColor, size: 36),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            asset.reference ??
                                assetType?.name ??
                                'Asset',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (asset.variant != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              '${assetType?.name ?? ''} — ${asset.variant}',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          if (asset.locationDescription != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              asset.locationDescription!,
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark
                                    ? AppTheme.darkTextSecondary
                                    : AppTheme.textSecondary,
                              ),
                            ),
                          ],
                          if (asset.zone != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Zone: ${asset.zone}',
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
                    ),
                    const Spacer(),
                    // Action buttons
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _testCurrentAsset,
                        icon: Icon(AppIcons.clipboardTick),
                        label: const Text('Start Test'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: Colors.white,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _skip,
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text('Skip'),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    final passCount = _outcomes.where((o) => o == 'pass').length;
    final failCount = _outcomes.where((o) => o == 'fail').length;
    final skippedCount = _outcomes.where((o) => o == 'skipped').length;

    return Scaffold(
      appBar: AppBar(title: const Text('Batch Test Complete')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: Column(
          children: [
            const Spacer(),
            Icon(AppIcons.tickCircle,
                size: 64, color: const Color(0xFF4CAF50)),
            const SizedBox(height: 16),
            const Text(
              'Testing Complete',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.assets.length} assets processed',
              style: TextStyle(
                fontSize: 15,
                color: isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            // Stat cards
            Row(
              children: [
                _StatCard(
                  label: 'Pass',
                  count: passCount,
                  color: const Color(0xFF4CAF50),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Fail',
                  count: failCount,
                  color: const Color(0xFFD32F2F),
                  isDark: isDark,
                ),
                const SizedBox(width: 12),
                _StatCard(
                  label: 'Skipped',
                  count: skippedCount,
                  color: Colors.grey,
                  isDark: isDark,
                ),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Done',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.label,
    required this.count,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color:
                    isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
