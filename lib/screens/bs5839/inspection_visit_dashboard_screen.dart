import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/bs5839_system_config.dart';
import '../../models/inspection_visit.dart';
import '../../services/bs5839_config_service.dart';
import '../../services/inspection_visit_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../assets/site_asset_register_screen.dart';
import 'complete_visit_screen.dart';
import 'logbook_screen.dart';
import 'variations_register_screen.dart';

class InspectionVisitDashboardScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String visitId;

  const InspectionVisitDashboardScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
    required this.visitId,
  });

  @override
  State<InspectionVisitDashboardScreen> createState() =>
      _InspectionVisitDashboardScreenState();
}

class _InspectionVisitDashboardScreenState
    extends State<InspectionVisitDashboardScreen> {
  final _visitService = InspectionVisitService.instance;
  final _configService = Bs5839ConfigService.instance;

  Bs5839SystemConfig? _config;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    _config = await _configService.getConfig(
        widget.basePath, widget.siteId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.siteName),
        actions: [
          IconButton(
            icon: const Icon(AppIcons.clipboardTick),
            tooltip: 'Visit History',
            onPressed: () {},
          ),
        ],
      ),
      body: StreamBuilder<InspectionVisit?>(
        stream: _visitService.getVisitStream(
            widget.basePath, widget.siteId, widget.visitId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: AdaptiveLoadingIndicator());
          }

          final visit = snapshot.data;
          if (visit == null) {
            return const Center(child: Text('Visit not found'));
          }

          if (visit.completedAt != null) {
            return _buildCompletedView(visit, isDark);
          }

          return _buildActiveVisitView(visit, isDark);
        },
      ),
    );
  }

  Widget _buildActiveVisitView(InspectionVisit visit, bool isDark) {
    final hasArc = _config?.arcConnected ?? false;
    final hasCyber = _config?.cyberSecurityRequired ?? false;

    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildVisitSummaryCard(visit, isDark),
        const SizedBox(height: 20),
        ProhibitedVariationsAlert(
          basePath: widget.basePath,
          siteId: widget.siteId,
          onTap: () => _openVariations(),
        ),
        const SizedBox(height: 8),
        Text('Quick Actions',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildQuickActionsRow(isDark),
        const SizedBox(height: AppTheme.sectionGap),
        Text('Progress Checklist',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _buildChecklistItem(
          'System Tests',
          '${visit.serviceRecordIds.length} asset${visit.serviceRecordIds.length == 1 ? '' : 's'} tested',
          visit.serviceRecordIds.isNotEmpty,
          isDark,
        ),
        _buildChecklistItem(
          'Logbook Reviewed',
          visit.logbookReviewed ? 'Reviewed' : 'Not reviewed',
          visit.logbookReviewed,
          isDark,
          onTap: () => _toggleLogbookReviewed(visit),
        ),
        _buildChecklistItem(
          'Zone Plan Verified',
          visit.zonePlanVerified ? 'Verified' : 'Not verified',
          visit.zonePlanVerified,
          isDark,
          onTap: () => _toggleZonePlanVerified(visit),
        ),
        _buildChecklistItem(
          'Battery Load Tests',
          '${visit.batteryTestReadings.length} PSU${visit.batteryTestReadings.length == 1 ? '' : 's'} tested',
          visit.batteryTestReadings.isNotEmpty,
          isDark,
        ),
        if (hasCyber)
          _buildChecklistItem(
            'Cyber Security Checks',
            visit.cyberSecurityChecksCompleted ? 'Completed' : 'Required',
            visit.cyberSecurityChecksCompleted,
            isDark,
            onTap: () => _toggleCyberSecurityChecks(visit),
          ),
        if (hasArc)
          _buildChecklistItem(
            'ARC Signalling Tested',
            visit.arcSignallingTested
                ? 'Tested${visit.arcTransmissionTimeMeasuredSeconds != null ? ' (${visit.arcTransmissionTimeMeasuredSeconds}s)' : ''}'
                : 'Not tested',
            visit.arcSignallingTested,
            isDark,
            onTap: () => _toggleArcSignalling(visit),
          ),
        _buildChecklistItem(
          'Earth Fault Test',
          visit.earthFaultTestPassed
              ? 'Passed${visit.earthFaultReadingKOhms != null ? ' (${visit.earthFaultReadingKOhms} kΩ)' : ''}'
              : 'Not tested',
          visit.earthFaultTestPassed,
          isDark,
          onTap: () => _toggleEarthFaultTest(visit),
        ),
        const SizedBox(height: 32),
        AnimatedSaveButton(
          onPressed: () => _completeVisit(visit),
          label: 'Complete & Sign',
          backgroundColor: AppTheme.primaryBlue,
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCompletedView(InspectionVisit visit, bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.screenPadding),
      children: [
        _buildVisitSummaryCard(visit, isDark),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _declarationColor(visit.declaration).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _declarationColor(visit.declaration).withValues(alpha: 0.3),
            ),
          ),
          child: Column(
            children: [
              Text(
                visit.declaration.displayLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _declarationColor(visit.declaration),
                ),
              ),
              if (visit.declarationNotes != null &&
                  visit.declarationNotes!.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  visit.declarationNotes!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Completed ${DateFormat('dd MMM yyyy HH:mm').format(visit.completedAt!)}',
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildVisitSummaryCard(InspectionVisit visit, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  visit.visitType.displayLabel,
                  style: TextStyle(
                    color: AppTheme.primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
              const Spacer(),
              if (visit.completedAt == null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'In Progress',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Started ${DateFormat('dd MMM yyyy HH:mm').format(visit.visitDate)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            'Engineer: ${visit.engineerName}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Colors.grey),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildStatChip(
                '${visit.serviceRecordIds.length}',
                'Tests',
                AppIcons.clipboardTick,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                '${visit.batteryTestReadings.length}',
                'Batteries',
                AppIcons.batteryCharging,
                isDark,
              ),
              const SizedBox(width: 12),
              _buildStatChip(
                '${visit.mcpIdsTestedThisVisit.length}',
                'MCPs',
                AppIcons.danger,
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      String value, String label, IconData icon, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildQuickActionsRow(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildQuickAction('Test Assets', AppIcons.clipboardTick, Colors.blue,
              _openAssetRegister, isDark),
          const SizedBox(width: 8),
          _buildQuickAction(
              'Add Variation', AppIcons.warning, Colors.orange,
              _openVariations, isDark),
          const SizedBox(width: 8),
          _buildQuickAction(
              'Review Logbook', AppIcons.book, Colors.purple,
              _openLogbook, isDark),
        ],
      ),
    );
  }

  Widget _buildQuickAction(
      String label, IconData icon, Color color, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistItem(
    String title,
    String subtitle,
    bool complete,
    bool isDark, {
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: complete
                ? Colors.green.withValues(alpha: 0.3)
                : (isDark ? Colors.white12 : Colors.grey.shade200),
          ),
        ),
        child: Row(
          children: [
            Icon(
              complete ? AppIcons.tickCircle : Icons.radio_button_unchecked,
              size: 20,
              color: complete ? Colors.green : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        decoration: complete
                            ? TextDecoration.lineThrough
                            : null,
                        color: complete ? Colors.grey : null,
                      )),
                  Text(
                    subtitle,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(AppIcons.arrowRight,
                  size: 14,
                  color: isDark ? Colors.white24 : Colors.black26),
          ],
        ),
      ),
    );
  }

  Color _declarationColor(InspectionDeclaration declaration) {
    switch (declaration) {
      case InspectionDeclaration.satisfactory:
        return Colors.green;
      case InspectionDeclaration.satisfactoryWithVariations:
        return Colors.orange;
      case InspectionDeclaration.unsatisfactory:
        return Colors.red;
      case InspectionDeclaration.notDeclared:
        return Colors.grey;
    }
  }

  void _toggleLogbookReviewed(InspectionVisit visit) {
    _visitService.updateVisit(
      widget.basePath,
      widget.siteId,
      widget.visitId,
      {'logbookReviewed': !visit.logbookReviewed},
    );
  }

  void _toggleZonePlanVerified(InspectionVisit visit) {
    _visitService.updateVisit(
      widget.basePath,
      widget.siteId,
      widget.visitId,
      {'zonePlanVerified': !visit.zonePlanVerified},
    );
  }

  void _toggleCyberSecurityChecks(InspectionVisit visit) {
    _visitService.updateVisit(
      widget.basePath,
      widget.siteId,
      widget.visitId,
      {'cyberSecurityChecksCompleted': !visit.cyberSecurityChecksCompleted},
    );
  }

  void _toggleArcSignalling(InspectionVisit visit) {
    _visitService.updateVisit(
      widget.basePath,
      widget.siteId,
      widget.visitId,
      {'arcSignallingTested': !visit.arcSignallingTested},
    );
  }

  void _toggleEarthFaultTest(InspectionVisit visit) {
    _visitService.updateVisit(
      widget.basePath,
      widget.siteId,
      widget.visitId,
      {'earthFaultTestPassed': !visit.earthFaultTestPassed},
    );
  }

  void _openAssetRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SiteAssetRegisterScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          siteName: widget.siteName,
          siteAddress: '',
        ),
      ),
    );
  }

  void _openLogbook() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogbookScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          siteName: widget.siteName,
          visitId: widget.visitId,
        ),
      ),
    );
  }

  void _openVariations() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VariationsRegisterScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          siteName: widget.siteName,
        ),
      ),
    );
  }

  Future<void> _completeVisit(InspectionVisit visit) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CompleteVisitScreen(
          basePath: widget.basePath,
          siteId: widget.siteId,
          siteName: widget.siteName,
          visitId: widget.visitId,
        ),
      ),
    );
  }
}
