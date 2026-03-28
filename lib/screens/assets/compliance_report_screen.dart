import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../../services/compliance_report_service.dart';
import '../../services/analytics_service.dart';
import '../../models/asset.dart';
import '../../services/asset_service.dart';
import '../../utils/theme.dart';
import '../../utils/icon_map.dart';
import '../../utils/adaptive_widgets.dart';
import '../../widgets/widgets.dart';
import '../common/pdf_preview_screen.dart';

class ComplianceReportScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String siteAddress;

  const ComplianceReportScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
    required this.siteAddress,
  });

  @override
  State<ComplianceReportScreen> createState() => _ComplianceReportScreenState();
}

class _ComplianceReportScreenState extends State<ComplianceReportScreen> {
  bool _generating = false;
  Uint8List? _pdfBytes;

  Future<void> _generateReport() async {
    setState(() => _generating = true);

    try {
      final bytes = await ComplianceReportService.instance.generateReport(
        basePath: widget.basePath,
        siteId: widget.siteId,
        siteName: widget.siteName,
        siteAddress: widget.siteAddress,
      );

      // Log analytics
      final assets = await AssetService.instance
          .getAssetsStream(widget.basePath, widget.siteId)
          .first;
      final active = assets
          .where((a) => a.complianceStatus != Asset.statusDecommissioned)
          .toList();
      final passCount =
          active.where((a) => a.complianceStatus == Asset.statusPass).length;
      final passRate = active.isEmpty ? 0.0 : passCount / active.length;

      AnalyticsService.instance.logComplianceReportGenerated(
        siteId: widget.siteId,
        assetCount: active.length,
        passRate: passRate,
      );

      if (mounted) {
        setState(() {
          _pdfBytes = bytes;
          _generating = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _generating = false);
        context.showErrorToast('Failed to generate report: $e');
      }
    }
  }

  Future<void> _shareReport() async {
    if (_pdfBytes == null) return;
    try {
      await ComplianceReportService.shareReport(_pdfBytes!, widget.siteName);
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to share report');
    }
  }

  Future<void> _printReport() async {
    if (_pdfBytes == null) return;
    try {
      await ComplianceReportService.printReport(_pdfBytes!);
    } catch (e) {
      if (mounted) context.showErrorToast('Failed to print report');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Compliance Report'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.screenPadding),
        child: _pdfBytes != null
            ? _buildReportReady(isDark)
            : _buildPreGenerate(isDark),
      ),
    );
  }

  Widget _buildPreGenerate(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Site info card
        Container(
          padding: const EdgeInsets.all(AppTheme.cardPadding),
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
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(AppIcons.building,
                        color: AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.siteName,
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color:
                                isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        if (widget.siteAddress.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            widget.siteAddress,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppTheme.darkTextSecondary
                                  : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Report contents info
        Container(
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report Contents',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _ReportSectionItem(
                icon: AppIcons.document,
                label: 'Cover Page',
                isDark: isDark,
              ),
              _ReportSectionItem(
                icon: AppIcons.clipboard,
                label: 'Compliance Summary',
                isDark: isDark,
              ),
              _ReportSectionItem(
                icon: AppIcons.map,
                label: 'Floor Plan Pages',
                isDark: isDark,
              ),
              _ReportSectionItem(
                icon: AppIcons.clipboardTick,
                label: 'Asset Register Table',
                isDark: isDark,
              ),
              _ReportSectionItem(
                icon: AppIcons.danger,
                label: 'Defect Summary',
                isDark: isDark,
              ),
              _ReportSectionItem(
                icon: AppIcons.timer,
                label: 'Lifecycle Alerts',
                isDark: isDark,
              ),
              _ReportSectionItem(
                icon: AppIcons.calendar,
                label: 'Service History',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const Spacer(),

        // Generate button
        if (_generating)
          const Center(
            child: Column(
              children: [
                AdaptiveLoadingIndicator(),
                SizedBox(height: 12),
                Text('Generating report...'),
              ],
            ),
          )
        else
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(AppIcons.document),
              label: const Text('Generate Report'),
            ),
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildReportReady(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Success card
        Container(
          padding: const EdgeInsets.all(AppTheme.cardPadding),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  AppIcons.tickCircle,
                  color: Color(0xFF4CAF50),
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Report Generated',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.siteName,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(_pdfBytes!.lengthInBytes / 1024).toStringAsFixed(0)} KB',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),

        // View report button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PdfPreviewScreen(
                  pdfBytes: _pdfBytes!,
                  title: 'Compliance Report',
                  fileName:
                      '${widget.siteName.replaceAll(' ', '_')}_compliance_report.pdf',
                ),
              ),
            ),
            icon: const Icon(AppIcons.document),
            label: const Text('View Report'),
          ),
        ),
        const SizedBox(height: 12),

        // Share button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _shareReport,
            icon: const Icon(AppIcons.send),
            label: const Text('Share Report'),
          ),
        ),
        const SizedBox(height: 12),

        // Print button
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: _printReport,
            icon: const Icon(AppIcons.printer),
            label: const Text('Print Report'),
          ),
        ),
        const SizedBox(height: 12),

        // Regenerate button
        TextButton(
          onPressed: () => setState(() => _pdfBytes = null),
          child: const Text('Generate Again'),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _ReportSectionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;

  const _ReportSectionItem({
    required this.icon,
    required this.label,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
