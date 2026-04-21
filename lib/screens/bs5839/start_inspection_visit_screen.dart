import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/bs5839_system_config.dart';
import '../../models/bs5839_variation.dart';
import '../../models/inspection_visit.dart';
import '../../services/bs5839_compliance_service.dart';
import '../../services/bs5839_config_service.dart';
import '../../services/inspection_visit_service.dart';
import '../../services/variation_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import 'bs5839_system_config_screen.dart';
import 'inspection_visit_dashboard_screen.dart';

class StartInspectionVisitScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;

  const StartInspectionVisitScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
  });

  @override
  State<StartInspectionVisitScreen> createState() =>
      _StartInspectionVisitScreenState();
}

class _StartInspectionVisitScreenState
    extends State<StartInspectionVisitScreen> {
  final _configService = Bs5839ConfigService.instance;
  final _visitService = InspectionVisitService.instance;
  final _complianceService = Bs5839ComplianceService.instance;

  InspectionVisitType _visitType = InspectionVisitType.routineService;
  bool _isLoading = true;
  bool _isStarting = false;

  Bs5839SystemConfig? _config;
  InspectionVisit? _lastVisit;
  McpRotationStatus? _mcpStatus;
  int _activeVariations = 0;
  int _prohibitedVariations = 0;
  bool _competencyCurrent = true;

  @override
  void initState() {
    super.initState();
    _loadPreVisitData();
  }

  Future<void> _loadPreVisitData() async {
    try {
      _config = await _configService.getConfig(
          widget.basePath, widget.siteId);
      _lastVisit = await _visitService.getLastVisit(
          widget.basePath, widget.siteId);
      _mcpStatus = await _complianceService.getMcpRotationStatus(
        basePath: widget.basePath,
        siteId: widget.siteId,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _competencyCurrent = await _complianceService.isCompetencyCurrent(
          basePath: widget.basePath,
          engineerId: user.uid,
        );
      }

      await _loadVariationCounts();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading pre-visit data: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadVariationCounts() async {
    final variations = await VariationService.instance
        .getVariationsStream(widget.basePath, widget.siteId)
        .first;
    final active =
        variations.where((v) => v.status == VariationStatus.active).toList();
    _activeVariations = active.length;
    _prohibitedVariations = active.where((v) => v.isProhibited).length;
  }

  Future<void> _startVisit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isStarting = true);
    try {
      final now = DateTime.now();
      final id = _visitService.generateId(widget.basePath, widget.siteId);
      final visit = InspectionVisit(
        id: id,
        siteId: widget.siteId,
        engineerId: user.uid,
        engineerName: user.displayName ?? 'Unknown',
        visitType: _visitType,
        visitDate: now,
        createdAt: now,
        updatedAt: now,
      );

      await _visitService.saveVisit(
          widget.basePath, widget.siteId, visit);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => InspectionVisitDashboardScreen(
              basePath: widget.basePath,
              siteId: widget.siteId,
              siteName: widget.siteName,
              visitId: id,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error starting visit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isStarting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Start BS 5839 Visit')),
      body: _isLoading
          ? const Center(child: AdaptiveLoadingIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppTheme.screenPadding),
              children: [
                Text('Visit Type',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _buildVisitTypeSelector(isDark),
                const SizedBox(height: AppTheme.sectionGap),
                Text('Pre-Visit Checks',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                _buildCheckItem(
                  'System Configuration',
                  _config != null
                      ? '${_config!.category.displayLabel} — configured'
                      : 'Not configured',
                  _config != null,
                  onAction: _config == null ? _configureNow : null,
                  actionLabel: 'Configure Now',
                  isDark: isDark,
                ),
                _buildCheckItem(
                  'Last Visit',
                  _lastVisit != null
                      ? '${DateFormat('dd MMM yyyy').format(_lastVisit!.visitDate)} — ${_lastVisit!.declaration.displayLabel}'
                      : 'No previous visits',
                  _lastVisit != null,
                  isDark: isDark,
                ),
                _buildCheckItem(
                  'MCP Rotation',
                  _mcpStatus != null && _mcpStatus!.totalMcps > 0
                      ? '${_mcpStatus!.testedInLast12Months}/${_mcpStatus!.totalMcps} tested in last 12 months'
                      : 'No MCPs on site',
                  _mcpStatus?.allCoveredInLast12Months ?? true,
                  isDark: isDark,
                ),
                _buildCheckItem(
                  'Active Variations',
                  _activeVariations > 0
                      ? '$_activeVariations active ($_prohibitedVariations prohibited)'
                      : 'None',
                  _prohibitedVariations == 0,
                  isDark: isDark,
                ),
                _buildCheckItem(
                  'Engineer Competency',
                  _competencyCurrent
                      ? 'Current — qualifications and CPD up to date'
                      : 'Requires update — check CPD hours or expired qualifications',
                  _competencyCurrent,
                  isDark: isDark,
                ),
                const SizedBox(height: 32),
                AnimatedSaveButton(
                  onPressed: _startVisit,
                  enabled: !_isStarting && _config != null,
                  label: 'Start Visit',
                ),
                if (_config == null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'System configuration is required before starting a visit.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.orange),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildVisitTypeSelector(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: InspectionVisitType.values.map((type) {
        final selected = _visitType == type;
        return ChoiceChip(
          label: Text(type.displayLabel),
          selected: selected,
          onSelected: (v) {
            if (v) setState(() => _visitType = type);
          },
        );
      }).toList(),
    );
  }

  Widget _buildCheckItem(
    String title,
    String subtitle,
    bool ok, {
    VoidCallback? onAction,
    String? actionLabel,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: ok
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            ok ? AppIcons.tickCircle : AppIcons.warning,
            color: ok ? Colors.green : Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
          if (onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel ?? 'Fix'),
            ),
        ],
      ),
    );
  }

  void _configureNow() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Bs5839SystemConfigScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          siteName: widget.siteName,
        ),
      ),
    );
    setState(() => _isLoading = true);
    _loadPreVisitData();
  }
}
