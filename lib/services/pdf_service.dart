import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'jobsheet_settings_service.dart';
import 'branding_service.dart';
import 'pdf_header_builder.dart';
import 'pdf_footer_builder.dart';
import 'company_pdf_config_service.dart';
import 'pdf_generation_data.dart';
import '../models/pdf_colour_scheme.dart';

/// Top-level function for compute() — builds the jobsheet PDF in a background isolate.
Future<Uint8List> _buildJobsheetPdf(JobsheetPdfData data) async {
  final jobsheet = Jobsheet.fromJson(data.jobsheetJson);
  final headerConfig = PdfHeaderConfig.fromJson(data.headerConfigJson);
  final footerConfig = PdfFooterConfig.fromJson(data.footerConfigJson);
  final colourScheme = PdfColourScheme(primaryColorValue: data.colourSchemeValue);
  final primaryColor = colourScheme.primaryColor;
  final primaryLight = colourScheme.primaryLight;
  final primaryMedium = colourScheme.primaryMedium;

  final regularFont = data.regularFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.regularFontBytes!))
      : pw.Font.helvetica();
  final boldFont = data.boldFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.boldFontBytes!))
      : pw.Font.helveticaBold();

  final pdf = pw.Document(
    theme: pw.ThemeData.withFont(
      base: regularFont,
      bold: boldFont,
    ),
  );

  final settings = _JobsheetSettings(
    companyName: data.settingsCompanyName,
    tagline: data.settingsTagline,
    address: data.settingsAddress,
    phone: data.settingsPhone,
  );

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(24),
      header: (context) => _buildHeader(jobsheet, context, settings, data.logoBytes, headerConfig, primaryColor),
      footer: (context) => PdfFooterBuilder.buildFooter(
        config: footerConfig,
        pageNumber: context.pageNumber,
        pagesCount: context.pagesCount,
        primaryColor: primaryColor,
      ),
      build: (context) => _buildDynamicSections(jobsheet, primaryColor, primaryLight, primaryMedium),
    ),
  );

  return await pdf.save();
}

/// Minimal settings holder used inside the isolate (replaces JobsheetHeaderFooter).
class _JobsheetSettings {
  final String companyName;
  final String tagline;
  final String address;
  final String phone;

  _JobsheetSettings({
    required this.companyName,
    required this.tagline,
    required this.address,
    required this.phone,
  });
}

// ── Constants shared by builder helpers ──

const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
const PdfColor _lightGray = PdfColor.fromInt(0xFFE0E0E0);
const PdfColor _white = PdfColors.white;

// ── Builder helpers (top-level so they work inside the isolate) ──

pw.Widget _buildHeader(Jobsheet jobsheet, pw.Context context, _JobsheetSettings settings, Uint8List? logoBytes, PdfHeaderConfig headerConfig, PdfColor primaryColor) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: primaryColor, width: 2),
      ),
    ),
    padding: const pw.EdgeInsets.only(bottom: 8),
    margin: const pw.EdgeInsets.only(bottom: 4),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Expanded(
          flex: 5,
          child: PdfHeaderBuilder.buildLeftAndCentre(
            config: headerConfig,
            logoBytes: logoBytes,
            primaryColor: primaryColor,
            fallbackValues: {
              'companyName': settings.companyName.isNotEmpty ? settings.companyName : jobsheet.engineerName,
              'tagline': settings.tagline,
              'address': settings.address,
              'phone': settings.phone,
            },
          ),
        ),
        pw.SizedBox(width: 12),
        // ── Solid-fill badge (matches invoice style) ──
        pw.Expanded(
          flex: 2,
          child: pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: pw.BoxDecoration(
              color: primaryColor,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  jobsheet.templateType.toUpperCase(),
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _white,
                    letterSpacing: 1,
                  ),
                  textAlign: pw.TextAlign.center,
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'REF: ${jobsheet.jobNumber}',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColor.fromInt(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

List<pw.Widget> _buildDynamicSections(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight, PdfColor primaryMedium) {
  final layout = jobsheet.sectionLayout ?? PdfSectionLayoutConfig.defaults();
  final visibleSections = layout.sections.where((s) => s.visible).toList();
  final widgets = <pw.Widget>[pw.SizedBox(height: 4)];

  for (int i = 0; i < visibleSections.length; i++) {
    final entry = visibleSections[i];

    if (entry.id == PdfSectionId.jobInfo &&
        layout.jobSiteLayout == SectionLayoutMode.sideBySide &&
        i + 1 < visibleSections.length &&
        visibleSections[i + 1].id == PdfSectionId.siteDetails) {
      widgets.add(_buildJobAndSiteRow(jobsheet, primaryColor, primaryLight));
      widgets.add(pw.SizedBox(height: 6));
      i++;
      continue;
    }
    if (entry.id == PdfSectionId.siteDetails &&
        layout.jobSiteLayout == SectionLayoutMode.sideBySide &&
        i + 1 < visibleSections.length &&
        visibleSections[i + 1].id == PdfSectionId.jobInfo) {
      widgets.add(_buildSiteAndJobRow(jobsheet, primaryColor, primaryLight));
      widgets.add(pw.SizedBox(height: 6));
      i++;
      continue;
    }

    final section = _buildSection(entry.id, jobsheet, primaryColor, primaryLight, primaryMedium);
    if (section != null) {
      widgets.add(section);
      widgets.add(pw.SizedBox(height: 6));
    }
  }

  return widgets;
}

pw.Widget? _buildSection(PdfSectionId id, Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight, PdfColor primaryMedium) {
  switch (id) {
    case PdfSectionId.jobInfo:
      return _buildJobInfoOnly(jobsheet, primaryColor, primaryLight);
    case PdfSectionId.siteDetails:
      return _buildSiteDetailsOnly(jobsheet, primaryColor, primaryLight);
    case PdfSectionId.workDetails:
      return _buildWorkDetailsSection(jobsheet, primaryColor, primaryLight);
    case PdfSectionId.notes:
      return jobsheet.notes.isNotEmpty ? _buildNotesSection(jobsheet, primaryColor, primaryLight) : null;
    case PdfSectionId.defects:
      return jobsheet.defects.isNotEmpty ? _buildDefectsSection(jobsheet) : null;
    case PdfSectionId.compliance:
      return _buildComplianceStatement(primaryColor);
    case PdfSectionId.signatures:
      return _buildSignaturesSection(jobsheet, primaryColor, primaryLight);
  }
}

pw.Widget _buildSectionHeader(String title, PdfColor primaryColor) {
  return pw.Container(
    width: double.infinity,
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: pw.BoxDecoration(
      color: primaryColor,
      borderRadius: const pw.BorderRadius.only(
        topLeft: pw.Radius.circular(4),
        topRight: pw.Radius.circular(4),
      ),
    ),
    child: pw.Text(
      title.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: _white,
        letterSpacing: 0.5,
      ),
    ),
  );
}

pw.Widget _buildJobInfoOnly(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final fields = [
    ('Date:', dateFormat.format(jobsheet.date)),
    ('Time:', timeFormat.format(jobsheet.date)),
    ('Job No:', jobsheet.jobNumber),
    ('Category:', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
    ('Engineer:', jobsheet.engineerName),
  ];

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lightGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      children: [
        _buildSectionHeader('Job Information', primaryColor),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            children: [
              for (int i = 0; i < fields.length; i++)
                _buildCompactField(fields[i].$1, fields[i].$2, primaryLight, isAlternate: i.isOdd),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSiteDetailsOnly(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  final fields = [
    ('Customer:', jobsheet.customerName),
    ('Address:', jobsheet.siteAddress),
  ];

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lightGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      children: [
        _buildSectionHeader('Site Details', primaryColor),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            children: [
              for (int i = 0; i < fields.length; i++)
                _buildCompactField(fields[i].$1, fields[i].$2, primaryLight, isAlternate: i.isOdd),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSiteAndJobRow(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final siteFields = [
    ('Customer:', jobsheet.customerName),
    ('Address:', jobsheet.siteAddress),
  ];

  final jobFields = [
    ('Date:', dateFormat.format(jobsheet.date)),
    ('Time:', timeFormat.format(jobsheet.date)),
    ('Job No:', jobsheet.jobNumber),
    ('Category:', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
    ('Engineer:', jobsheet.engineerName),
  ];

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildSectionHeader('Site Details', primaryColor),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    for (int i = 0; i < siteFields.length; i++)
                      _buildCompactField(siteFields[i].$1, siteFields[i].$2, primaryLight, isAlternate: i.isOdd),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildSectionHeader('Job Information', primaryColor),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    for (int i = 0; i < jobFields.length; i++)
                      _buildCompactField(jobFields[i].$1, jobFields[i].$2, primaryLight, isAlternate: i.isOdd),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildJobAndSiteRow(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final jobFields = [
    ('Date:', dateFormat.format(jobsheet.date)),
    ('Time:', timeFormat.format(jobsheet.date)),
    ('Job No:', jobsheet.jobNumber),
    ('Category:', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
    ('Engineer:', jobsheet.engineerName),
  ];

  final siteFields = [
    ('Customer:', jobsheet.customerName),
    ('Address:', jobsheet.siteAddress),
  ];

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildSectionHeader('Job Information', primaryColor),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    for (int i = 0; i < jobFields.length; i++)
                      _buildCompactField(jobFields[i].$1, jobFields[i].$2, primaryLight, isAlternate: i.isOdd),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _lightGray),
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Column(
            children: [
              _buildSectionHeader('Site Details', primaryColor),
              pw.Padding(
                padding: const pw.EdgeInsets.all(8),
                child: pw.Column(
                  children: [
                    for (int i = 0; i < siteFields.length; i++)
                      _buildCompactField(siteFields[i].$1, siteFields[i].$2, primaryLight, isAlternate: i.isOdd),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildCompactField(String label, String value, PdfColor primaryLight, {bool isAlternate = false}) {
  return pw.Container(
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(
      color: isAlternate ? primaryLight : null,
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
    ),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 75,
          child: pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _darkGray,
            ),
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

bool _isShortField(dynamic value) {
  if (value is bool) return true;
  final str = value?.toString() ?? '';
  return str.length <= 30 && !str.contains('\n');
}

pw.Widget _buildWorkDetailField(MapEntry<String, dynamic> entry, Map<String, String> fieldLabels, PdfColor primaryColor) {
  final isBoolean = entry.value is bool;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 110,
        child: pw.Text(
          '${fieldLabels[entry.key] ?? _formatFieldLabel(entry.key)}:',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _darkGray,
          ),
        ),
      ),
      pw.Expanded(
        child: isBoolean
            ? _buildCheckboxField(entry.value as bool, primaryColor)
            : pw.Text(
                _formatFieldValue(entry.value),
                style: const pw.TextStyle(fontSize: 10),
              ),
      ),
    ],
  );
}

pw.Widget _buildWorkDetailsSection(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  final entries = jobsheet.formData.entries.toList();
  final List<pw.Widget> rows = [];

  int rowIndex = 0;
  int i = 0;
  while (i < entries.length) {
    final entry = entries[i];
    final isShort = _isShortField(entry.value);
    final isAlternate = rowIndex.isOdd;

    if (isShort && i + 1 < entries.length && _isShortField(entries[i + 1].value)) {
      rows.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            color: isAlternate ? primaryLight : null,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildWorkDetailField(entry, jobsheet.fieldLabels, primaryColor),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildWorkDetailField(entries[i + 1], jobsheet.fieldLabels, primaryColor),
              ),
            ],
          ),
        ),
      );
      i += 2;
    } else {
      rows.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            color: isAlternate ? primaryLight : null,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
          ),
          child: _buildWorkDetailField(entry, jobsheet.fieldLabels, primaryColor),
        ),
      );
      i += 1;
    }
    rowIndex++;
  }

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lightGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      children: [
        _buildSectionHeader('Work Carried Out', primaryColor),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(children: rows),
        ),
      ],
    ),
  );
}

pw.Widget _buildCheckboxField(bool value, PdfColor primaryColor) {
  return pw.Row(
    children: [
      _buildCheckbox(value, 'Yes', primaryColor),
      pw.SizedBox(width: 16),
      _buildCheckbox(!value, 'No', primaryColor),
    ],
  );
}

pw.Widget _buildCheckbox(bool checked, String label, PdfColor primaryColor) {
  return pw.Row(
    mainAxisSize: pw.MainAxisSize.min,
    children: [
      pw.Container(
        width: 12,
        height: 12,
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _darkGray, width: 1),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(2)),
        ),
        child: checked
            ? pw.Center(
                child: pw.CustomPaint(
                  size: const PdfPoint(8, 8),
                  painter: (canvas, size) {
                    canvas
                      ..setStrokeColor(primaryColor)
                      ..setLineWidth(1.5)
                      ..setLineCap(PdfLineCap.round)
                      ..drawLine(1, 4, 3.5, 1.5)
                      ..drawLine(3.5, 1.5, 7, 6.5)
                      ..strokePath();
                  },
                ),
              )
            : null,
      ),
      pw.SizedBox(width: 4),
      pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
    ],
  );
}

pw.Widget _buildNotesSection(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lightGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Additional Notes / Observations', primaryColor),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(8),
          constraints: const pw.BoxConstraints(minHeight: 30),
          decoration: pw.BoxDecoration(
            color: primaryLight,
            borderRadius: const pw.BorderRadius.only(
              bottomLeft: pw.Radius.circular(4),
              bottomRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Text(
            jobsheet.notes,
            style: const pw.TextStyle(fontSize: 10),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildDefectsSection(Jobsheet jobsheet) {
  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.red200),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: const pw.BoxDecoration(
            color: PdfColors.red,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(4),
              topRight: pw.Radius.circular(4),
            ),
          ),
          child: pw.Text(
            'DEFECTS / ISSUES IDENTIFIED',
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: _white,
              letterSpacing: 0.5,
            ),
          ),
        ),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: jobsheet.defects.asMap().entries.map((entry) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 5),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 18,
                      height: 18,
                      margin: const pw.EdgeInsets.only(right: 8),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.red,
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(9),
                        ),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${entry.key + 1}',
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: _white,
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          entry.value,
                          style: const pw.TextStyle(fontSize: 10),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildComplianceStatement(PdfColor primaryColor) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(8),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF5F5F5),
      border: pw.Border(
        left: pw.BorderSide(color: primaryColor, width: 4),
        top: pw.BorderSide(color: _lightGray, width: 0.5),
        right: pw.BorderSide(color: _lightGray, width: 0.5),
        bottom: pw.BorderSide(color: _lightGray, width: 0.5),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CERTIFICATION STATEMENT',
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: _darkGray,
          ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          'I hereby certify that the work described above has been carried out in accordance with '
          'BS 5839-1 and the manufacturer\'s instructions. The system has been left in full '
          'working order unless otherwise stated in the defects section above.',
          style: const pw.TextStyle(fontSize: 8, color: _darkGray),
          textAlign: pw.TextAlign.justify,
        ),
      ],
    ),
  );
}

pw.Widget _buildSignaturesSection(Jobsheet jobsheet, PdfColor primaryColor, PdfColor primaryLight) {
  final dateFormat = DateFormat('dd/MM/yyyy');

  return pw.Container(
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: _lightGray),
      borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
    ),
    child: pw.Column(
      children: [
        _buildSectionHeader('Authorisation & Sign-Off', primaryColor),
        pw.Padding(
          padding: const pw.EdgeInsets.all(8),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Engineer',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGray,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 40,
                      decoration: pw.BoxDecoration(
                        color: primaryLight,
                        border: pw.Border.all(color: _lightGray),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(2),
                        ),
                      ),
                      child: _buildSignatureContent(
                        jobsheet.engineerSignature,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    _buildSignatureField(
                      'Name:',
                      jobsheet.engineerName,
                    ),
                    pw.SizedBox(height: 2),
                    _buildSignatureField(
                      'Date:',
                      dateFormat.format(jobsheet.date),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Customer / Site Representative',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: _darkGray,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      height: 40,
                      decoration: pw.BoxDecoration(
                        color: primaryLight,
                        border: pw.Border.all(color: _lightGray),
                        borderRadius: const pw.BorderRadius.all(
                          pw.Radius.circular(2),
                        ),
                      ),
                      child: _buildSignatureContent(
                        jobsheet.customerSignature,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    _buildSignatureField(
                      'Name:',
                      jobsheet.customerSignatureName ?? '',
                    ),
                    pw.SizedBox(height: 2),
                    _buildSignatureField(
                      'Date:',
                      dateFormat.format(jobsheet.date),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSignatureContent(String? signatureBase64) {
  if (signatureBase64 == null || signatureBase64.isEmpty) {
    return pw.Center(
      child: pw.Text(
        'Signature',
        style: const pw.TextStyle(fontSize: 8, color: _lightGray),
      ),
    );
  }

  try {
    final bytes = base64Decode(signatureBase64);
    return pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Image(pw.MemoryImage(bytes), fit: pw.BoxFit.contain),
    );
  } catch (e) {
    return pw.Center(
      child: pw.Text(
        'Signature unavailable',
        style: const pw.TextStyle(fontSize: 8, color: _lightGray),
      ),
    );
  }
}

pw.Widget _buildSignatureField(String label, String value) {
  return pw.Row(
    children: [
      pw.SizedBox(
        width: 40,
        child: pw.Text(
          label,
          style: const pw.TextStyle(fontSize: 8, color: _darkGray),
        ),
      ),
      pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 2),
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _lightGray)),
          ),
          child: pw.Text(
            value,
            style: const pw.TextStyle(fontSize: 9),
          ),
        ),
      ),
    ],
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
  if (value == null || value.toString().isEmpty) {
    return 'N/A';
  }
  final str = value.toString();
  if (str.contains('T') && str.length > 10) {
    try {
      final date = DateTime.parse(str);
      return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
    } catch (_) {}
  }
  return str;
}

/// Extracts raw TTF bytes from a Font loaded via PdfGoogleFonts.
Uint8List _extractFontBytes(pw.Font font) {
  final ttf = font as pw.TtfFont;
  return Uint8List.fromList(
    ttf.data.buffer.asUint8List(ttf.data.offsetInBytes, ttf.data.lengthInBytes),
  );
}

class PDFService {
  static Future<Uint8List> generateJobsheetPDF(Jobsheet jobsheet) async {
    // ── Gather phase (main thread) ──
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.robotoRegular();
      final boldFont = await PdfGoogleFonts.robotoBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {
      // Google Fonts unavailable — isolate will fall back to Helvetica
    }

    final settings = await JobsheetSettingsService.getSettings();
    final logoBytes = await BrandingService.getLogoBytes();
    final useCompanyBranding = jobsheet.dispatchedJobId != null;
    final companyPdf = CompanyPdfConfigService.instance;
    final headerConfig = await companyPdf.getEffectiveHeaderConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );
    final footerConfig = await companyPdf.getEffectiveFooterConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );
    final colourScheme = await companyPdf.getEffectiveColourScheme(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );

    final data = JobsheetPdfData(
      jobsheetJson: jobsheet.toJson(),
      logoBytes: logoBytes,
      headerConfigJson: headerConfig.toJson(),
      footerConfigJson: footerConfig.toJson(),
      colourSchemeValue: colourScheme.primaryColorValue,
      settingsCompanyName: settings.companyName,
      settingsTagline: settings.tagline,
      settingsAddress: settings.address,
      settingsPhone: settings.phone,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
    );

    // ── Build phase (background isolate) ──
    return compute(_buildJobsheetPdf, data);
  }

  static Future<void> sharePDF(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  static Future<void> printPDF(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}
