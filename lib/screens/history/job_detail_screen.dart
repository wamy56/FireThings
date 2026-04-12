import 'package:flutter/material.dart';
import '../../utils/adaptive_widgets.dart';
import 'package:intl/intl.dart';
import '../../utils/icon_map.dart';
import 'dart:convert';
import '../../models/models.dart';
import '../../services/pdf_service.dart';
import '../../services/template_pdf_service.dart';
import '../../utils/pdf_form_templates.dart';
import '../../widgets/widgets.dart';
import '../../utils/theme.dart';
import '../common/pdf_preview_screen.dart';
import '../pdf_forms/pdf_form_fill_screen.dart';
import '../pdf_forms/minor_works_form_fill_screen.dart';
import '../../services/analytics_service.dart';
import 'edit_jobsheet_screen.dart';

class JobDetailScreen extends StatefulWidget {
  final Jobsheet jobsheet;
  final bool showSuccessBanner;

  const JobDetailScreen({
    super.key,
    required this.jobsheet,
    this.showSuccessBanner = false,
  });

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  late Jobsheet _jobsheet;

  @override
  void initState() {
    super.initState();
    _jobsheet = widget.jobsheet;

    // Show success banner if coming from completion
    if (widget.showSuccessBanner) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.showSuccessToast('Jobsheet completed successfully!');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, HH:mm');
    final isComplete = _jobsheet.engineerSignature != null &&
        _jobsheet.customerSignature != null;

    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Jobsheet Details',
        actions: [
          IconButton(
            icon: Icon(AppIcons.edit),
            tooltip: 'Edit Jobsheet',
            onPressed: _editJobsheet,
          ),
          IconButton(
            icon: Icon(AppIcons.document),
            tooltip: 'Generate PDF',
            onPressed: () => _generatePDF(context),
          ),
          IconButton(
            icon: Icon(AppIcons.share),
            tooltip: 'Share',
            onPressed: () => _sharePDF(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status Badge
          _buildStatusBadge(isComplete),
          const SizedBox(height: 16),

          // Job Information Card
          _buildJobInfoCard(dateFormat),
          const SizedBox(height: 16),

          // Work Details Card
          _buildWorkDetailsCard(),
          const SizedBox(height: 16),

          // Notes Card
          if (_jobsheet.notes.isNotEmpty) ...[
            _buildNotesCard(),
            const SizedBox(height: 16),
          ],

          // Signatures Card
          if (_jobsheet.engineerSignature != null ||
              _jobsheet.customerSignature != null) ...[
            _buildSignaturesCard(),
            const SizedBox(height: 16),
          ],

          // Actions
          _buildActionButtons(context, isComplete),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isComplete) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: isComplete ? AppTheme.successGreen : AppTheme.warningOrange,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isComplete ? AppIcons.tickCircle : AppIcons.clock,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            isComplete ? 'COMPLETED' : 'PENDING SIGNATURES',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJobInfoCard(DateFormat dateFormat) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.infoCircle, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Job Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.edit, size: 20),
                  onPressed: _editJobsheet,
                  tooltip: 'Edit',
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Template', _jobsheet.templateType, AppIcons.folder),
            _buildInfoRow('Customer', _jobsheet.customerName, AppIcons.building),
            _buildInfoRow('Site', _jobsheet.siteAddress, AppIcons.location),
            _buildInfoRow('Job Number', _jobsheet.jobNumber, AppIcons.tag),
            _buildInfoRow('Engineer', _jobsheet.engineerName, AppIcons.user),
            if (_jobsheet.systemCategory.isNotEmpty)
              _buildInfoRow(
                'System Category',
                _jobsheet.systemCategory,
                AppIcons.category,
              ),
            _buildInfoRow(
              'Date',
              dateFormat.format(_jobsheet.date),
              AppIcons.calendar,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkDetailsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.designtools, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Work Details',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.edit, size: 20),
                  onPressed: _editJobsheet,
                  tooltip: 'Edit',
                ),
              ],
            ),
            const Divider(height: 24),
            // Regular fields (excluding signatures and repeat groups)
            ..._jobsheet.formData.entries
                .where((entry) =>
                    entry.value is! List &&
                    !(entry.key.contains('signature') &&
                        entry.value is String &&
                        (entry.value as String).startsWith('data:image/png;base64,')))
                .map((entry) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        _jobsheet.fieldLabels[entry.key] ?? _formatFieldLabel(entry.key),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        _formatFieldValue(entry.value),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            // Repeat group fields
            ..._jobsheet.formData.entries
                .where((entry) => entry.value is List)
                .map((entry) => _buildRepeatGroupDisplay(
                      entry.key,
                      _jobsheet.fieldLabels[entry.key] ?? _formatFieldLabel(entry.key),
                      entry.value as List,
                    )),
            ..._jobsheet.formData.entries
                .where((entry) =>
                    entry.key.contains('signature') &&
                    entry.value is String &&
                    (entry.value as String).startsWith('data:image/png;base64,'))
                .map((entry) {
              final base64Data = (entry.value as String)
                  .replaceFirst('data:image/png;base64,', '');
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _jobsheet.fieldLabels[entry.key] ?? _formatFieldLabel(entry.key),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 100,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Image.memory(
                        base64Decode(base64Data),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.note, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Additional Notes',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: Icon(AppIcons.edit, size: 20),
                  onPressed: _editJobsheet,
                  tooltip: 'Edit',
                ),
              ],
            ),
            const Divider(height: 24),
            Text(_jobsheet.notes, style: const TextStyle(fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildSignaturesCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(AppIcons.edit, color: AppTheme.primaryBlue),
                const SizedBox(width: 8),
                const Text(
                  'Signatures',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Engineer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _jobsheet.engineerSignature != null
                            ? Image.memory(
                                base64Decode(_jobsheet.engineerSignature!),
                                fit: BoxFit.contain,
                              )
                            : const Center(child: Text('No signature')),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _jobsheet.engineerName,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Customer',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 100,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _jobsheet.customerSignature != null
                            ? Image.memory(
                                base64Decode(_jobsheet.customerSignature!),
                                fit: BoxFit.contain,
                              )
                            : const Center(child: Text('No signature')),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _jobsheet.customerSignatureName ?? 'N/A',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isComplete) {
    return Column(
      children: [
        // Edit button prominently displayed
        CustomOutlinedButton(
          text: 'Edit Jobsheet',
          icon: AppIcons.edit,
          onPressed: _editJobsheet,
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        CustomButton(
          text: 'Generate PDF',
          icon: AppIcons.document,
          onPressed: () => _generatePDF(context),
          isFullWidth: true,
        ),
        const SizedBox(height: 12),
        CustomOutlinedButton(
          text: 'Share PDF',
          icon: AppIcons.share,
          onPressed: () => _sharePDF(context),
          isFullWidth: true,
        ),
      ],
    );
  }

  Future<void> _editJobsheet() async {
    if (PdfFormTemplates.isPdfCertificateTemplate(_jobsheet.templateType)) {
      final pdfTemplate = PdfFormTemplates.getByName(_jobsheet.templateType);
      if (pdfTemplate != null) {
        if (_jobsheet.templateType == 'IQ Minor Works & Call Out Certificate') {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => MinorWorksFormFillScreen(
                template: pdfTemplate,
                existingJobsheet: _jobsheet,
              ),
            ),
          );
        } else {
          await Navigator.push(
            context,
            adaptivePageRoute(
              builder: (_) => PdfFormFillScreen(
                template: pdfTemplate,
                existingJobsheet: _jobsheet,
              ),
            ),
          );
        }
      }
      // Pop back since the form handles its own saving
      if (mounted) Navigator.pop(context);
    } else {
      final result = await Navigator.push<Jobsheet>(
        context,
        adaptivePageRoute(
          builder: (_) => EditJobsheetScreen(jobsheet: _jobsheet),
        ),
      );

      // Update the displayed jobsheet if changes were made
      if (result != null) {
        setState(() {
          _jobsheet = result;
        });
      }
    }
  }

  Future<void> _generatePDF(BuildContext context) async {
    AnalyticsService.instance.logJobsheetPdfGenerated();
    try {
      context.showInfoToast('Generating PDF...');

      if (PdfFormTemplates.isPdfCertificateTemplate(_jobsheet.templateType)) {
        final pdfTemplate = PdfFormTemplates.getByName(_jobsheet.templateType);
        if (pdfTemplate != null) {
          final pdfBytes = await TemplatePdfService.generateOverlayPdf(
            template: pdfTemplate,
            fieldValues: _jobsheet.formData,
          );
          if (!context.mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PdfPreviewScreen(
                pdfBytes: pdfBytes,
                title: _jobsheet.templateType,
                fileName: '${_jobsheet.templateType.replaceAll(' ', '_')}_${_jobsheet.jobNumber}.pdf',
              ),
            ),
          );
        }
      } else {
        final pdfBytes = await PDFService.generateJobsheetPDF(_jobsheet);
        if (!context.mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PdfPreviewScreen(
              pdfBytes: pdfBytes,
              title: 'Jobsheet',
              fileName: 'jobsheet_${_jobsheet.jobNumber}.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorToast('Error generating PDF: $e');
    }
  }

  Future<void> _sharePDF(BuildContext context) async {
    AnalyticsService.instance.logJobsheetPdfShared();
    try {
      context.showInfoToast('Generating PDF...');

      if (PdfFormTemplates.isPdfCertificateTemplate(_jobsheet.templateType)) {
        final pdfTemplate = PdfFormTemplates.getByName(_jobsheet.templateType);
        if (pdfTemplate != null) {
          final pdfBytes = await TemplatePdfService.generateOverlayPdf(
            template: pdfTemplate,
            fieldValues: _jobsheet.formData,
          );
          await TemplatePdfService.sharePdf(
            pdfBytes,
            '${_jobsheet.templateType.replaceAll(' ', '_')}_${_jobsheet.jobNumber}.pdf',
          );
        }
      } else {
        final pdfBytes = await PDFService.generateJobsheetPDF(_jobsheet);
        await PDFService.sharePDF(pdfBytes, 'jobsheet_${_jobsheet.jobNumber}.pdf');
      }
    } catch (e) {
      if (!context.mounted) return;
      context.showErrorToast('Error sharing PDF: $e');
    }
  }

  Widget _buildRepeatGroupDisplay(String groupKey, String label, List entries) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (entries.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.element, color: AppTheme.primaryBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${entries.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...entries.asMap().entries.map((mapEntry) {
            final index = mapEntry.key;
            final entry = mapEntry.value as Map<String, dynamic>;

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.grey.withValues(alpha: 0.15),
                ),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: index == 0,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  title: Text(
                    '#${index + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  children: entry.entries
                      .where((e) => e.key != '_entryId')
                      .map((childEntry) {
                    final childLabel =
                        _jobsheet.fieldLabels['$groupKey.${childEntry.key}'] ??
                            _formatFieldLabel(childEntry.key);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              childLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              _formatFieldValue(childEntry.value),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _formatFieldLabel(String key) {
    if (key.isEmpty) return '';
    return key
        .split('_')
        .where((word) => word.isNotEmpty)
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  String _formatFieldValue(dynamic value) {
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    if (value is String && value.contains('T')) {
      // Might be a date
      try {
        final date = DateTime.parse(value);
        return DateFormat('dd/MM/yyyy').format(date);
      } catch (e) {
        return value.toString();
      }
    }
    return value.toString();
  }
}
