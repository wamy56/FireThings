import 'dart:convert';
import '../../widgets/premium_dialog.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../models/pdf_form_template.dart';
import '../../services/template_pdf_service.dart';
import '../../utils/icon_map.dart';
import '../../utils/pdf_form_templates.dart';
import '../../widgets/premium_toast.dart';
import '../../widgets/adaptive_app_bar.dart';
import '../../utils/adaptive_widgets.dart';

/// Screen for calibrating Minor Works PDF field positions.
///
/// Generates a PDF with field boundaries drawn on the actual template
/// so you can see exactly where fields are positioned.
class MinorWorksCalibrationScreen extends StatefulWidget {
  const MinorWorksCalibrationScreen({super.key});

  @override
  State<MinorWorksCalibrationScreen> createState() =>
      _MinorWorksCalibrationScreenState();
}

class _MinorWorksCalibrationScreenState
    extends State<MinorWorksCalibrationScreen> {
  bool _isGenerating = false;
  Uint8List? _pdfBytes;
  late PdfFormTemplate _template;

  @override
  void initState() {
    super.initState();
    _template = PdfFormTemplates.iqMinorWorksCertificate;
    _generateDebugPdf();
  }

  Future<void> _generateDebugPdf() async {
    setState(() => _isGenerating = true);

    try {
      // Generate empty field values map
      final Map<String, dynamic> emptyValues = {};
      for (final field in _template.fields) {
        emptyValues[field.id] = null;
      }

      // Generate PDF with debug mode ON
      final pdfBytes = await TemplatePdfService.generateOverlayPdf(
        template: _template,
        fieldValues: emptyValues,
        debugMode: true,
      );

      setState(() {
        _pdfBytes = pdfBytes;
      });
    } catch (e) {
      if (mounted) {
        context.showErrorToast('Error generating PDF: $e');
      }
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  void _showFieldsList() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Field Definitions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _exportCoordinates();
                        },
                        icon: Icon(AppIcons.copy),
                        tooltip: 'Export as JSON',
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(AppIcons.close),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _template.fields.length,
                itemBuilder: (context, index) {
                  final field = _template.fields[index];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(field.id),
                    subtitle: Text(
                      'x: ${field.x.toStringAsFixed(1)}%, y: ${field.y.toStringAsFixed(1)}%\n'
                      'w: ${field.width.toStringAsFixed(1)}%, h: ${field.height.toStringAsFixed(1)}%',
                      style: const TextStyle(
                          fontFamily: 'monospace', fontSize: 12),
                    ),
                    isThreeLine: true,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _exportCoordinates() {
    final coords = _template.fields
        .map((f) => {
              'id': f.id,
              'label': f.label,
              'x': f.x,
              'y': f.y,
              'width': f.width,
              'height': f.height,
            })
        .toList();

    final jsonStr = const JsonEncoder.withIndent('  ').convert(coords);

    showPremiumDialog(
      context: context,
      child: Builder(
        builder: (context) => AlertDialog(
        title: const Text('Field Coordinates'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdaptiveNavigationBar(
        title: 'Minor Works Field Positions',
        actions: [
          IconButton(
            icon: Icon(AppIcons.refresh),
            onPressed: _generateDebugPdf,
            tooltip: 'Regenerate',
          ),
          IconButton(
            icon: Icon(AppIcons.element),
            onPressed: _showFieldsList,
            tooltip: 'View field list',
          ),
          IconButton(
            icon: Icon(AppIcons.share),
            onPressed: _pdfBytes != null
                ? () => TemplatePdfService.sharePdf(
                    _pdfBytes!, 'debug_minor_works_field_positions.pdf')
                : null,
            tooltip: 'Share PDF',
          ),
        ],
      ),
      body: _isGenerating
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AdaptiveLoadingIndicator(),
                  SizedBox(height: 16),
                  Text('Generating PDF with field boundaries...'),
                ],
              ),
            )
          : _pdfBytes == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(AppIcons.danger,
                          size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      const Text('Failed to generate PDF'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _generateDebugPdf,
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    // Instructions
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      color: Colors.blue.shade50,
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '📍 Red rectangles show current field positions',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Field IDs are labeled inside each rectangle. '
                            'Adjust x/y values in pdf_form_templates.dart to move fields.',
                            style: TextStyle(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    // PDF Preview
                    Expanded(
                      child: PdfPreview(
                        build: (_) => _pdfBytes!,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        allowPrinting: true,
                        allowSharing: true,
                        pdfFileName: 'debug_minor_works_field_positions.pdf',
                      ),
                    ),
                  ],
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showFieldsList,
        icon: Icon(AppIcons.edit),
        label: const Text('View Fields'),
      ),
    );
  }
}
