import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/inspection_visit.dart';
import '../../services/bs5839_report_service.dart';
import '../../services/inspection_visit_service.dart';
import '../../utils/adaptive_widgets.dart';
import '../../utils/icon_map.dart';
import '../../utils/theme.dart';
import '../../widgets/widgets.dart';
import '../common/pdf_preview_screen.dart';

class Bs5839ReportScreen extends StatefulWidget {
  final String basePath;
  final String siteId;
  final String siteName;
  final String siteAddress;
  final String visitId;

  const Bs5839ReportScreen({
    super.key,
    required this.basePath,
    required this.siteId,
    required this.siteName,
    required this.siteAddress,
    required this.visitId,
  });

  @override
  State<Bs5839ReportScreen> createState() => _Bs5839ReportScreenState();
}

class _Bs5839ReportScreenState extends State<Bs5839ReportScreen> {
  bool _generating = false;
  bool _uploading = false;
  String _progressPhase = '';
  Uint8List? _pdfBytes;
  InspectionVisit? _visit;

  @override
  void initState() {
    super.initState();
    _loadVisit();
  }

  Future<void> _loadVisit() async {
    _visit = await InspectionVisitService.instance
        .getVisit(widget.basePath, widget.siteId, widget.visitId);
    if (mounted) setState(() {});
  }

  Future<void> _generateReport() async {
    setState(() {
      _generating = true;
      _progressPhase = '';
    });

    try {
      final bytes = await Bs5839ReportService.instance.generateReport(
        basePath: widget.basePath,
        siteId: widget.siteId,
        siteName: widget.siteName,
        siteAddress: widget.siteAddress,
        visitId: widget.visitId,
        onProgress: (phase) {
          if (mounted) setState(() => _progressPhase = phase);
        },
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate report: $e')),
        );
      }
    }
  }

  Future<void> _uploadReport() async {
    if (_pdfBytes == null) return;
    setState(() => _uploading = true);

    try {
      await Bs5839ReportService.instance.uploadReport(
        basePath: widget.basePath,
        siteId: widget.siteId,
        visitId: widget.visitId,
        pdfBytes: _pdfBytes!,
      );

      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report uploaded successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload report: $e')),
        );
      }
    }
  }

  Future<void> _shareReport() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.sharePdf(
        bytes: _pdfBytes!,
        filename: 'BS5839_${widget.siteName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share report')),
        );
      }
    }
  }

  Future<void> _printReport() async {
    if (_pdfBytes == null) return;
    try {
      await Printing.layoutPdf(onLayout: (_) => _pdfBytes!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to print report')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('BS 5839 Report')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 750),
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.screenPadding),
            child: _pdfBytes != null
                ? _buildReportReady(isDark)
                : _buildPreGenerate(isDark),
          ),
        ),
      ),
    );
  }

  Widget _buildPreGenerate(bool isDark) {
    final declaration = _visit?.declaration ?? InspectionDeclaration.notDeclared;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                    child: Icon(AppIcons.building,
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
                            color: isDark ? Colors.white : AppTheme.textPrimary,
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
              if (_visit != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _declarationColor(declaration).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    declaration.displayLabel,
                    style: TextStyle(
                      color: _declarationColor(declaration),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
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
                'BS 5839-1:2025 Report Contents',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              _item(AppIcons.document, 'Cover & Declaration', isDark),
              _item(AppIcons.setting, 'System Configuration', isDark),
              _item(AppIcons.medal, 'Engineer Competency', isDark),
              _item(AppIcons.clipboardTick, 'Inspection Scope', isDark),
              _item(AppIcons.clipboard, 'Asset Test Results', isDark),
              _item(AppIcons.flash, 'Cause & Effect Tests', isDark),
              _item(AppIcons.batteryCharging, 'Battery & Sounder Readings', isDark),
              _item(AppIcons.warning, 'Variations Register', isDark),
              _item(AppIcons.danger, 'Defects & Remedial Actions', isDark),
              _item(AppIcons.book, 'Logbook Summary', isDark),
              _item(AppIcons.map, 'Floor Plans', isDark),
              _item(AppIcons.edit, 'Signatures', isDark),
            ],
          ),
        ),
        const Spacer(),
        if (_generating)
          Column(
            children: [
              const AdaptiveLoadingIndicator(),
              const SizedBox(height: 8),
              Text(
                _progressPhase,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          )
        else
          AnimatedSaveButton(
            label: 'Generate BS 5839 Report',
            onPressed: _generateReport,
            backgroundColor: AppTheme.primaryBlue,
          ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _item(IconData icon, String label, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Icon(icon,
              size: 16,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportReady(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AppTheme.cardRadius),
            border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              const Icon(AppIcons.tickCircle, color: Colors.green, size: 32),
              const SizedBox(height: 8),
              const Text(
                'Report Generated',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'BS 5839-1:2025 Inspection Report for ${widget.siteName}',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _actionButton(
                'Preview',
                AppIcons.eye,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => PdfPreviewScreen(
                        title: 'BS 5839 Report',
                        pdfBytes: _pdfBytes!,
                        fileName: 'BS5839_${widget.siteName.replaceAll(' ', '_')}.pdf',
                      ),
                    ),
                  );
                },
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionButton(
                'Share',
                AppIcons.send,
                _shareReport,
                isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _actionButton(
                'Print',
                AppIcons.printer,
                _printReport,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        AnimatedSaveButton(
          label: _uploading ? 'Uploading...' : 'Upload to Cloud',
          enabled: !_uploading,
          onPressed: _uploadReport,
          backgroundColor: AppTheme.primaryBlue,
        ),
        const SizedBox(height: 12),
        AnimatedSaveButton(
          label: 'Regenerate',
          onPressed: _generateReport,
          outlined: true,
        ),
      ],
    );
  }

  Widget _actionButton(
      String label, IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isDark ? Colors.white12 : Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Icon(icon, size: 22, color: AppTheme.primaryBlue),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : AppTheme.textSecondary,
              ),
            ),
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
}
