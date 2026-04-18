import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'jobsheet_settings_service.dart';
import 'pdf_footer_builder.dart';
import 'company_pdf_config_service.dart';
import 'pdf_generation_data.dart';
import 'auth_service.dart';
import 'service_history_service.dart';
import 'asset_service.dart';
import 'asset_type_service.dart';
import '../data/default_asset_types.dart';
import 'pdf_widgets/pdf_modern_header.dart';
import 'pdf_widgets/pdf_section_card.dart';
import 'pdf_widgets/pdf_field_row.dart';
import 'pdf_widgets/pdf_modern_table.dart';
import 'pdf_widgets/pdf_signature_box.dart';
import 'pdf_widgets/pdf_style_helpers.dart';

/// Top-level function for compute() — builds the jobsheet PDF in a background isolate.
Future<Uint8List> _buildJobsheetPdf(JobsheetPdfData data) async {
  final jobsheet = Jobsheet.fromJson(data.jobsheetJson);
  final headerConfig = PdfHeaderConfig.fromJson(data.headerConfigJson);
  final footerConfig = PdfFooterConfig.fromJson(data.footerConfigJson);

  // Reconstruct colour scheme with optional secondary
  final colourScheme = PdfColourScheme(
    primaryColorValue: data.colourSchemeValue,
    secondaryColorValue: data.secondaryColourValue,
  );

  // Reconstruct section style and typography configs
  final sectionStyle = data.sectionStyleJson != null
      ? PdfSectionStyleConfig.fromJson(data.sectionStyleJson!)
      : PdfSectionStyleConfig.defaults();
  final typography = data.typographyJson != null
      ? PdfTypographyConfig.fromJson(data.typographyJson!)
      : PdfTypographyConfig.defaults();

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
      header: (context) => _buildHeader(
        jobsheet, context, settings, data.logoBytes, headerConfig, colourScheme),
      footer: (context) => PdfFooterBuilder.buildFooter(
        config: footerConfig,
        pageNumber: context.pageNumber,
        pagesCount: context.pagesCount,
        primaryColor: colourScheme.primaryColor,
      ),
      build: (context) => _buildDynamicSections(
        jobsheet, colourScheme, sectionStyle, typography, data),
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

// ── Builder helpers (top-level so they work inside the isolate) ──

pw.Widget _buildHeader(Jobsheet jobsheet, pw.Context context, _JobsheetSettings settings, Uint8List? logoBytes, PdfHeaderConfig headerConfig, PdfColourScheme colors) {
  return buildModernHeader(
    config: headerConfig,
    colors: colors,
    logoBytes: logoBytes,
    documentType: jobsheet.templateType,
    documentRef: jobsheet.jobNumber,
    fallbackValues: {
      'companyName': settings.companyName.isNotEmpty ? settings.companyName : jobsheet.engineerName,
      'tagline': settings.tagline,
      'address': settings.address,
      'phone': settings.phone,
    },
  );
}

List<pw.Widget> _buildDynamicSections(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
  JobsheetPdfData data,
) {
  final layout = jobsheet.sectionLayout ?? PdfSectionLayoutConfig.defaults();
  final visibleSections = layout.sections.where((s) => s.visible).toList();
  final widgets = <pw.Widget>[pw.SizedBox(height: 4)];

  for (int i = 0; i < visibleSections.length; i++) {
    final entry = visibleSections[i];

    if (entry.id == PdfSectionId.jobInfo &&
        layout.jobSiteLayout == SectionLayoutMode.sideBySide &&
        i + 1 < visibleSections.length &&
        visibleSections[i + 1].id == PdfSectionId.siteDetails) {
      widgets.add(_buildJobAndSiteRow(jobsheet, colors, sectionStyle, typography));
      widgets.add(pw.SizedBox(height: sectionStyle.sectionSpacing));
      i++;
      continue;
    }
    if (entry.id == PdfSectionId.siteDetails &&
        layout.jobSiteLayout == SectionLayoutMode.sideBySide &&
        i + 1 < visibleSections.length &&
        visibleSections[i + 1].id == PdfSectionId.jobInfo) {
      widgets.add(_buildSiteAndJobRow(jobsheet, colors, sectionStyle, typography));
      widgets.add(pw.SizedBox(height: sectionStyle.sectionSpacing));
      i++;
      continue;
    }

    final section = _buildSection(entry.id, jobsheet, colors, sectionStyle, typography, data);
    if (section != null) {
      widgets.add(section);
      widgets.add(pw.SizedBox(height: sectionStyle.sectionSpacing));
    }
  }

  return widgets;
}

pw.Widget? _buildSection(
  PdfSectionId id,
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
  JobsheetPdfData data,
) {
  switch (id) {
    case PdfSectionId.jobInfo:
      return _buildJobInfoOnly(jobsheet, colors, sectionStyle, typography);
    case PdfSectionId.siteDetails:
      return _buildSiteDetailsOnly(jobsheet, colors, sectionStyle, typography);
    case PdfSectionId.workDetails:
      return _buildWorkDetailsSection(jobsheet, colors, sectionStyle, typography);
    case PdfSectionId.notes:
      return jobsheet.notes.isNotEmpty
          ? _buildNotesSection(jobsheet, colors, sectionStyle, typography)
          : null;
    case PdfSectionId.defects:
      return jobsheet.defects.isNotEmpty
          ? _buildDefectsSection(jobsheet, colors, sectionStyle, typography)
          : null;
    case PdfSectionId.compliance:
      return _buildComplianceStatement(colors, sectionStyle, typography);
    case PdfSectionId.signatures:
      return _buildSignaturesSection(jobsheet, colors, sectionStyle, typography);
    case PdfSectionId.assetSummary:
      return _buildAssetSummarySection(data, colors, sectionStyle, typography);
  }
}

pw.Widget _buildJobInfoOnly(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final fields = [
    ('Date', dateFormat.format(jobsheet.date)),
    ('Time', timeFormat.format(jobsheet.date)),
    ('Job No', jobsheet.jobNumber),
    ('Category', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
    ('Engineer', jobsheet.engineerName),
  ];

  return buildSectionCard(
    title: 'Job Information',
    colors: colors,
    style: sectionStyle,
    children: fields.asMap().entries.map((entry) {
      return buildCompactFieldRow(
        label: entry.value.$1,
        value: entry.value.$2,
        colors: colors,
        typography: typography,
        isAlternate: entry.key.isOdd,
      );
    }).toList(),
  );
}

pw.Widget _buildSiteDetailsOnly(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final fields = [
    ('Customer', jobsheet.customerName),
    ('Address', jobsheet.siteAddress),
  ];

  return buildSectionCard(
    title: 'Site Details',
    colors: colors,
    style: sectionStyle,
    children: fields.asMap().entries.map((entry) {
      return buildCompactFieldRow(
        label: entry.value.$1,
        value: entry.value.$2,
        colors: colors,
        typography: typography,
        isAlternate: entry.key.isOdd,
      );
    }).toList(),
  );
}

pw.Widget _buildSiteAndJobRow(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final siteFields = [
    ('Customer', jobsheet.customerName),
    ('Address', jobsheet.siteAddress),
  ];

  final jobFields = [
    ('Date', dateFormat.format(jobsheet.date)),
    ('Time', timeFormat.format(jobsheet.date)),
    ('Job No', jobsheet.jobNumber),
    ('Category', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
    ('Engineer', jobsheet.engineerName),
  ];

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: buildSectionCard(
          title: 'Site Details',
          colors: colors,
          style: sectionStyle,
          children: siteFields.asMap().entries.map((entry) {
            return buildCompactFieldRow(
              label: entry.value.$1,
              value: entry.value.$2,
              colors: colors,
              typography: typography,
              isAlternate: entry.key.isOdd,
            );
          }).toList(),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: buildSectionCard(
          title: 'Job Information',
          colors: colors,
          style: sectionStyle,
          children: jobFields.asMap().entries.map((entry) {
            return buildCompactFieldRow(
              label: entry.value.$1,
              value: entry.value.$2,
              colors: colors,
              typography: typography,
              isAlternate: entry.key.isOdd,
            );
          }).toList(),
        ),
      ),
    ],
  );
}

pw.Widget _buildJobAndSiteRow(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final dateFormat = DateFormat('dd/MM/yyyy');
  final timeFormat = DateFormat('HH:mm');

  final jobFields = [
    ('Date', dateFormat.format(jobsheet.date)),
    ('Time', timeFormat.format(jobsheet.date)),
    ('Job No', jobsheet.jobNumber),
    ('Category', jobsheet.systemCategory.isEmpty ? 'N/A' : jobsheet.systemCategory),
    ('Engineer', jobsheet.engineerName),
  ];

  final siteFields = [
    ('Customer', jobsheet.customerName),
    ('Address', jobsheet.siteAddress),
  ];

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        child: buildSectionCard(
          title: 'Job Information',
          colors: colors,
          style: sectionStyle,
          children: jobFields.asMap().entries.map((entry) {
            return buildCompactFieldRow(
              label: entry.value.$1,
              value: entry.value.$2,
              colors: colors,
              typography: typography,
              isAlternate: entry.key.isOdd,
            );
          }).toList(),
        ),
      ),
      pw.SizedBox(width: 12),
      pw.Expanded(
        child: buildSectionCard(
          title: 'Site Details',
          colors: colors,
          style: sectionStyle,
          children: siteFields.asMap().entries.map((entry) {
            return buildCompactFieldRow(
              label: entry.value.$1,
              value: entry.value.$2,
              colors: colors,
              typography: typography,
              isAlternate: entry.key.isOdd,
            );
          }).toList(),
        ),
      ),
    ],
  );
}

bool _isShortField(dynamic value) {
  if (value is bool) return true;
  if (value is List) return false;
  final str = value?.toString() ?? '';
  return str.length <= 30 && !str.contains('\n');
}

pw.Widget _buildWorkDetailField(
  MapEntry<String, dynamic> entry,
  Map<String, String> fieldLabels,
  PdfColourScheme colors,
  PdfTypographyConfig typography,
) {
  final isBoolean = entry.value is bool;
  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.SizedBox(
        width: 110,
        child: pw.Text(
          '${fieldLabels[entry.key] ?? _formatFieldLabel(entry.key)}:',
          style: pw.TextStyle(
            fontSize: typography.fieldLabelSize + 1,
            fontWeight: pw.FontWeight.bold,
            color: colors.textSecondary,
          ),
        ),
      ),
      pw.Expanded(
        child: isBoolean
            ? _buildCheckboxField(entry.value as bool, colors.primaryColor)
            : pw.Text(
                _formatFieldValue(entry.value),
                style: pw.TextStyle(
                  fontSize: typography.fieldValueSize,
                  color: colors.textPrimary,
                ),
              ),
      ),
    ],
  );
}

pw.Widget _buildRepeatGroupSection(
  String groupKey,
  List entries,
  Map<String, String> fieldLabels,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  if (entries.isEmpty) return pw.SizedBox.shrink();

  final groupLabel = fieldLabels[groupKey] ?? _formatFieldLabel(groupKey);

  // Collect all child keys (excluding _entryId) from the first entry to build headers
  final firstEntry = entries.first as Map<String, dynamic>;
  final childKeys = firstEntry.keys.where((k) => k != '_entryId').toList();

  if (childKeys.isEmpty) return pw.SizedBox.shrink();

  return pw.Padding(
    padding: const pw.EdgeInsets.fromLTRB(8, 4, 8, 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 6),
          child: pw.Text(
            groupLabel,
            style: pw.TextStyle(
              fontSize: typography.fieldValueSize,
              fontWeight: pw.FontWeight.bold,
              color: colors.primaryColor,
            ),
          ),
        ),
        // Table
        pw.Table(
          border: pw.TableBorder.all(color: colors.primaryMedium, width: 0.5),
          columnWidths: {
            for (var j = 0; j < childKeys.length; j++)
              j: const pw.FlexColumnWidth(),
          },
          children: [
            // Header row
            pw.TableRow(
              decoration: pw.BoxDecoration(color: colors.primaryColor),
              children: childKeys.map((key) {
                final label = fieldLabels['$groupKey.$key'] ??
                    _formatFieldLabel(key);
                return pw.Padding(
                  padding: const pw.EdgeInsets.all(6),
                  child: pw.Text(
                    label.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: typography.tableHeaderSize - 2,
                      fontWeight: pw.FontWeight.bold,
                      color: pdfWhite,
                    ),
                  ),
                );
              }).toList(),
            ),
            // Data rows
            ...entries.asMap().entries.map((mapEntry) {
              final rowIndex = mapEntry.key;
              final entry = mapEntry.value as Map<String, dynamic>;
              final isAlternate = rowIndex.isOdd;

              return pw.TableRow(
                decoration: isAlternate
                    ? pw.BoxDecoration(color: colors.primarySoft)
                    : null,
                children: childKeys.map((key) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.all(6),
                    child: pw.Text(
                      _formatFieldValue(entry[key]),
                      style: pw.TextStyle(
                        fontSize: typography.tableBodySize - 1,
                        color: colors.textPrimary,
                      ),
                    ),
                  );
                }).toList(),
              );
            }),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildWorkDetailsSection(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final entries = jobsheet.formData.entries.toList();
  final List<pw.Widget> rows = [];
  final List<pw.Widget> repeatGroupSections = [];

  int rowIndex = 0;
  int i = 0;
  while (i < entries.length) {
    final entry = entries[i];

    // Handle repeat group entries separately
    if (entry.value is List) {
      repeatGroupSections.add(
        _buildRepeatGroupSection(
          entry.key,
          entry.value as List,
          jobsheet.fieldLabels,
          colors,
          sectionStyle,
          typography,
        ),
      );
      i += 1;
      continue;
    }

    final isShort = _isShortField(entry.value);
    final isAlternate = rowIndex.isOdd;

    if (isShort && i + 1 < entries.length && _isShortField(entries[i + 1].value)) {
      rows.add(
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: pw.BoxDecoration(
            color: isAlternate ? colors.primarySoft : null,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: _buildWorkDetailField(entry, jobsheet.fieldLabels, colors, typography),
              ),
              pw.SizedBox(width: 12),
              pw.Expanded(
                child: _buildWorkDetailField(entries[i + 1], jobsheet.fieldLabels, colors, typography),
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
            color: isAlternate ? colors.primarySoft : null,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          ),
          child: _buildWorkDetailField(entry, jobsheet.fieldLabels, colors, typography),
        ),
      );
      i += 1;
    }
    rowIndex++;
  }

  return buildSectionCard(
    title: 'Work Carried Out',
    colors: colors,
    style: sectionStyle,
    children: [
      ...rows,
      ...repeatGroupSections,
    ],
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

pw.Widget _buildNotesSection(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  return buildSectionCard(
    title: 'Additional Notes / Observations',
    colors: colors,
    style: sectionStyle,
    children: [
      pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.all(8),
        constraints: const pw.BoxConstraints(minHeight: 30),
        decoration: pw.BoxDecoration(
          color: colors.primarySoft,
          borderRadius: pw.BorderRadius.circular(sectionStyle.cornerRadius.pixels),
        ),
        child: pw.Text(
          jobsheet.notes,
          style: pw.TextStyle(
            fontSize: typography.fieldValueSize,
            color: colors.textPrimary,
          ),
        ),
      ),
    ],
  );
}

pw.Widget _buildDefectsSection(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  // Defects section uses red styling to stand out
  return pw.Container(
    margin: pw.EdgeInsets.only(bottom: sectionStyle.sectionSpacing),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.red200, width: 0.5),
      borderRadius: pw.BorderRadius.circular(sectionStyle.cornerRadius.pixels),
      boxShadow: sectionStyle.cardStyle == SectionCardStyle.shadowed ||
              sectionStyle.cardStyle == SectionCardStyle.elevated
          ? [
              pw.BoxShadow(
                color: const PdfColor.fromInt(0x1A000000),
                blurRadius: 4,
                offset: const PdfPoint(0, 2),
              ),
            ]
          : null,
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: pw.BoxDecoration(
            color: PdfColors.red,
            borderRadius: pw.BorderRadius.only(
              topLeft: pw.Radius.circular(sectionStyle.cornerRadius.pixels),
              topRight: pw.Radius.circular(sectionStyle.cornerRadius.pixels),
            ),
          ),
          child: pw.Text(
            'DEFECTS / ISSUES IDENTIFIED',
            style: pw.TextStyle(
              fontSize: sectionStyle.headerFontSize,
              fontWeight: pw.FontWeight.bold,
              color: pdfWhite,
              letterSpacing: 0.5,
            ),
          ),
        ),
        pw.Padding(
          padding: pw.EdgeInsets.all(sectionStyle.innerPadding),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: jobsheet.defects.asMap().entries.map((entry) {
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Container(
                      width: 20,
                      height: 20,
                      margin: const pw.EdgeInsets.only(right: 10),
                      decoration: const pw.BoxDecoration(
                        color: PdfColors.red,
                        borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                      ),
                      child: pw.Center(
                        child: pw.Text(
                          '${entry.key + 1}',
                          style: pw.TextStyle(
                            fontSize: typography.fieldValueSize - 1,
                            fontWeight: pw.FontWeight.bold,
                            color: pdfWhite,
                          ),
                        ),
                      ),
                    ),
                    pw.Expanded(
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Text(
                          entry.value,
                          style: pw.TextStyle(
                            fontSize: typography.fieldValueSize,
                            color: colors.textPrimary,
                          ),
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

pw.Widget _buildComplianceStatement(
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  return pw.Container(
    margin: pw.EdgeInsets.only(bottom: sectionStyle.sectionSpacing),
    padding: pw.EdgeInsets.all(sectionStyle.innerPadding),
    decoration: pw.BoxDecoration(
      color: colors.primarySoft,
      border: pw.Border(
        left: pw.BorderSide(color: colors.primaryColor, width: 4),
        top: pw.BorderSide(color: colors.primaryMedium, width: 0.5),
        right: pw.BorderSide(color: colors.primaryMedium, width: 0.5),
        bottom: pw.BorderSide(color: colors.primaryMedium, width: 0.5),
      ),
      borderRadius: pw.BorderRadius.only(
        topRight: pw.Radius.circular(sectionStyle.cornerRadius.pixels),
        bottomRight: pw.Radius.circular(sectionStyle.cornerRadius.pixels),
      ),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'CERTIFICATION STATEMENT',
          style: pw.TextStyle(
            fontSize: typography.sectionHeaderSize - 2,
            fontWeight: pw.FontWeight.bold,
            color: colors.primaryColor,
            letterSpacing: 0.5,
          ),
        ),
        pw.SizedBox(height: 6),
        pw.Text(
          'I hereby certify that the work described above has been carried out in accordance with '
          'BS 5839-1 and the manufacturer\'s instructions. The system has been left in full '
          'working order unless otherwise stated in the defects section above.',
          style: pw.TextStyle(
            fontSize: typography.fieldLabelSize,
            color: colors.textSecondary,
          ),
          textAlign: pw.TextAlign.justify,
        ),
      ],
    ),
  );
}

pw.Widget _buildSignaturesSection(
  Jobsheet jobsheet,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final dateFormat = DateFormat('dd/MM/yyyy');

  return buildSectionCard(
    title: 'Authorisation & Sign-Off',
    colors: colors,
    style: sectionStyle,
    children: [
      buildSignatureSection(
        engineerSignatureBase64: jobsheet.engineerSignature,
        customerSignatureBase64: jobsheet.customerSignature,
        engineerName: jobsheet.engineerName,
        customerName: jobsheet.customerSignatureName,
        date: dateFormat.format(jobsheet.date),
        colors: colors,
        typography: typography,
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

/// Builds the "Asset Inspection Summary" table from pre-fetched service records.
pw.Widget? _buildAssetSummarySection(
  JobsheetPdfData data,
  PdfColourScheme colors,
  PdfSectionStyleConfig sectionStyle,
  PdfTypographyConfig typography,
) {
  final records = data.assetServiceRecords;
  if (records == null || records.isEmpty) return null;

  final passCount = records.where((r) => r['result'] == 'pass').length;
  final failCount = records.where((r) => r['result'] == 'fail').length;
  final defectCount = records
      .where((r) => r['defectNote'] != null && (r['defectNote'] as String).isNotEmpty)
      .length;

  return buildSectionCard(
    title: 'Asset Inspection Summary',
    colors: colors,
    style: sectionStyle,
    children: [
      buildModernTable(
        headers: ['Ref', 'Type', 'Location', 'Zone', 'Result', 'Defects'],
        rows: records.map((r) {
          final hasDefect = r['defectNote'] != null && (r['defectNote'] as String).isNotEmpty;
          return <String>[
            (r['reference'] as String?) ?? '-',
            (r['typeName'] as String?) ?? '-',
            (r['location'] as String?) ?? '-',
            (r['zone'] as String?) ?? '-',
            (r['result'] as String? ?? '-').toUpperCase(),
            hasDefect ? 'Yes' : '-',
          ];
        }).toList(),
        colors: colors,
        typography: typography,
        columnFlex: [2, 3, 3, 2, 2, 2],
      ),
      pw.SizedBox(height: 8),
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: colors.primarySoft,
          borderRadius: pw.BorderRadius.circular(sectionStyle.cornerRadius.pixels),
        ),
        child: pw.Text(
          '${records.length} assets tested: $passCount pass, $failCount fail. $defectCount defect${defectCount == 1 ? '' : 's'} logged.',
          style: pw.TextStyle(
            fontSize: typography.fieldLabelSize + 1,
            fontWeight: pw.FontWeight.bold,
            color: colors.textPrimary,
          ),
        ),
      ),
    ],
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
    final useCompanyBranding = jobsheet.useCompanyBranding;
    final logoBytes = await CompanyPdfConfigService.instance.getEffectiveLogoBytes(
      useCompanyBranding: useCompanyBranding,
      type: PdfDocumentType.jobsheet,
    );
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
    final sectionStyle = await companyPdf.getEffectiveSectionStyleConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );
    final typography = await companyPdf.getEffectiveTypographyConfig(
      PdfDocumentType.jobsheet,
      useCompanyBranding: useCompanyBranding,
    );

    // ── Fetch asset inspection records if jobsheet has a linked site ──
    List<Map<String, dynamic>>? assetServiceRecords;
    if (jobsheet.siteId != null) {
      try {
        final user = AuthService().currentUser;
        if (user != null) {
          final basePath = 'users/${user.uid}';
          final siteId = jobsheet.siteId!;
          final records = await ServiceHistoryService.instance
              .getRecordsForJobsheet(basePath, siteId, jobsheet.id);

          if (records.isNotEmpty) {
            // Fetch assets and types to enrich the records
            final assets = await AssetService.instance
                .getAssetsStream(basePath, siteId).first;
            final assetTypes = await AssetTypeService.instance
                .getAssetTypes(basePath);

            assetServiceRecords = records.map((record) {
              final asset = assets.where((a) => a.id == record.assetId).firstOrNull;
              final assetType = asset != null
                  ? (assetTypes.where((t) => t.id == asset.assetTypeId).firstOrNull
                      ?? DefaultAssetTypes.getById(asset.assetTypeId))
                  : null;

              return {
                'reference': asset?.reference ?? '-',
                'typeName': assetType?.name ?? '-',
                'location': asset?.locationDescription ?? '-',
                'zone': asset?.zone ?? '-',
                'result': record.overallResult,
                'defectNote': record.defectNote ?? '',
              };
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('Error fetching asset records for PDF: $e');
      }
    }

    final data = JobsheetPdfData(
      jobsheetJson: jobsheet.toJson(),
      logoBytes: logoBytes,
      headerConfigJson: headerConfig.toJson(),
      footerConfigJson: footerConfig.toJson(),
      colourSchemeValue: colourScheme.primaryColorValue,
      secondaryColourValue: colourScheme.secondaryColorValue,
      sectionStyleJson: sectionStyle.toJson(),
      typographyJson: typography.toJson(),
      settingsCompanyName: settings.companyName,
      settingsTagline: settings.tagline,
      settingsAddress: settings.address,
      settingsPhone: settings.phone,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      assetServiceRecords: assetServiceRecords,
    );

    // ── Build phase ──
    // Isolates are not available on web, so run directly on the main thread.
    if (kIsWeb) {
      return _buildJobsheetPdf(data);
    }
    return compute(_buildJobsheetPdf, data);
  }

  static Future<void> sharePDF(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  static Future<void> printPDF(Uint8List pdfBytes) async {
    await Printing.layoutPdf(onLayout: (format) async => pdfBytes);
  }
}
