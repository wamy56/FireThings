import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sf;
import '../models/pdf_form_template.dart';
import '../utils/pdf_coordinate_calculator.dart';
import 'pdf_generation_data.dart';

// ── Top-level isolate functions ──

/// Builds a filled PDF from template data in a background isolate.
Future<Uint8List> _buildFilledPdf(TemplatePdfData data) async {
  final template = PdfFormTemplate.fromJson(data.templateJson);
  final fieldValues = data.fieldValues;
  final resolvedFileBytes = data.resolvedFileBytes;

  final regularFont = data.regularFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.regularFontBytes!))
      : pw.Font.helvetica();
  final boldFont = data.boldFontBytes != null
      ? pw.Font.ttf(ByteData.sublistView(data.boldFontBytes!))
      : pw.Font.helveticaBold();

  final pdf = pw.Document();

  // Group fields by page
  final fieldsByPage = <int, List<FormFieldDefinition>>{};
  for (final field in template.fields) {
    fieldsByPage.putIfAbsent(field.page, () => []);
    fieldsByPage[field.page]!.add(field);
  }

  // Generate pages
  for (int pageNum = 0; pageNum < template.pageCount; pageNum++) {
    final pageFields = fieldsByPage[pageNum] ?? [];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (context) {
          return pw.Stack(
            children: [
              pw.Positioned(
                left: 0,
                top: 0,
                right: 0,
                child: _buildHeader(
                  template: template,
                  engineerName: data.engineerName,
                  jobReference: data.jobReference,
                  boldFont: boldFont,
                  regularFont: regularFont,
                ),
              ),
              ...pageFields.map((field) {
                final value = fieldValues[field.id];
                final pos = PdfCoordinateCalculator.percentToPoints(
                  xPercent: field.x,
                  yPercent: field.y,
                  pageWidth: PdfPageFormat.a4.width,
                  pageHeight: PdfPageFormat.a4.height,
                );
                return pw.Positioned(
                  left: pos.dx,
                  top: pos.dy,
                  child: pw.Container(
                    decoration: data.debugMode
                        ? pw.BoxDecoration(
                            border: pw.Border.all(
                              color: PdfColors.red,
                              width: 0.5,
                            ),
                          )
                        : null,
                    child: _buildFieldValue(
                      field: field,
                      value: value,
                      regularFont: regularFont,
                      boldFont: boldFont,
                      debugMode: data.debugMode,
                      resolvedFileBytes: resolvedFileBytes,
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  return await pdf.save();
}

/// Builds an overlay PDF (Syncfusion) in a background isolate.
Future<Uint8List> _buildOverlayPdf(TemplateOverlayPdfData data) async {
  final template = PdfFormTemplate.fromJson(data.templateJson);
  final fieldValues = data.fieldValues;
  final resolvedFileBytes = data.resolvedFileBytes;

  final sf.PdfDocument document = sf.PdfDocument(inputBytes: data.basePdfBytes);

  for (final field in template.fields) {
    final value = fieldValues[field.id];

    if (field.page >= document.pages.count) continue;
    final sf.PdfPage page = document.pages[field.page];
    final pageSize = page.getClientSize();

    final pos = PdfCoordinateCalculator.percentToPoints(
      xPercent: field.x,
      yPercent: field.y,
      pageWidth: pageSize.width,
      pageHeight: pageSize.height,
    );
    final dims = PdfCoordinateCalculator.percentDimensionsToPoints(
      widthPercent: field.width,
      heightPercent: field.height,
      pageWidth: pageSize.width,
      pageHeight: pageSize.height,
    );
    final double x = pos.dx;
    final double y = pos.dy;
    final double width = dims.dx;
    final double height = dims.dy;

    if (data.debugMode) {
      _drawDebugRect(
        page: page,
        x: x,
        y: y,
        width: width,
        height: height,
        label: field.id,
      );
    }

    if (value == null) continue;

    final fontSize = field.fontSize ?? 10.0;

    switch (field.type) {
      case FormFieldDefinitionType.text:
      case FormFieldDefinitionType.multilineText:
      case FormFieldDefinitionType.dropdown:
        _drawTextOverlay(
          page: page,
          text: value.toString(),
          x: x,
          y: y,
          width: width,
          height: height,
          fontSize: fontSize,
        );
        break;

      case FormFieldDefinitionType.datePicker:
        String dateText = value.toString();
        if (value is String && value.contains('T')) {
          try {
            final date = DateTime.parse(value);
            dateText =
                '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
          } catch (e) {
            // Use original value
          }
        }
        _drawTextOverlay(
          page: page,
          text: dateText,
          x: x,
          y: y,
          width: width,
          height: height,
          fontSize: fontSize,
        );
        break;

      case FormFieldDefinitionType.checkbox:
        final isChecked = value == true || value == 'true';
        if (isChecked) {
          _addCheckboxFormField(
            document: document,
            page: page,
            fieldId: field.id,
            x: x,
            y: y,
            size: width > 0 ? width : 12,
          );
        } else {
          _addNAFormField(
            document: document,
            page: page,
            fieldId: field.id,
            x: x,
            y: y,
            size: width > 0 ? width : 12,
          );
        }
        break;

      case FormFieldDefinitionType.radioGroup:
        _drawTextOverlay(
          page: page,
          text: value.toString(),
          x: x,
          y: y,
          width: width,
          height: height,
          fontSize: fontSize,
        );
        break;

      case FormFieldDefinitionType.signature:
        _drawImageBytesOverlay(
          page: page,
          fieldId: field.id,
          signatureData: value.toString(),
          resolvedFileBytes: resolvedFileBytes,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        break;

      case FormFieldDefinitionType.image:
        _drawImageBytesOverlay(
          page: page,
          fieldId: field.id,
          signatureData: value.toString(),
          resolvedFileBytes: resolvedFileBytes,
          x: x,
          y: y,
          width: width,
          height: height,
        );
        break;
    }
  }

  final List<int> savedBytes = await document.save();
  document.dispose();

  return Uint8List.fromList(savedBytes);
}

// ── Shared builder helpers (top-level for isolate compatibility) ──

pw.Widget _buildHeader({
  required PdfFormTemplate template,
  required String engineerName,
  required String jobReference,
  required pw.Font boldFont,
  required pw.Font regularFont,
}) {
  return pw.Container(
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey400),
      borderRadius: pw.BorderRadius.circular(4),
    ),
    child: pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              template.name,
              style: pw.TextStyle(font: boldFont, fontSize: 14),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Engineer: $engineerName',
              style: pw.TextStyle(font: regularFont, fontSize: 10),
            ),
          ],
        ),
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Text(
              'Ref: $jobReference',
              style: pw.TextStyle(font: boldFont, fontSize: 10),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Date: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
              style: pw.TextStyle(font: regularFont, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
}

pw.Widget _buildFieldValue({
  required FormFieldDefinition field,
  required dynamic value,
  required pw.Font regularFont,
  required pw.Font boldFont,
  required Map<String, Uint8List> resolvedFileBytes,
  bool debugMode = false,
}) {
  final fontSize = field.fontSize ?? 10.0;

  switch (field.type) {
    case FormFieldDefinitionType.text:
    case FormFieldDefinitionType.multilineText:
    case FormFieldDefinitionType.dropdown:
    case FormFieldDefinitionType.datePicker:
      final fieldWidth = (field.width / 100) * PdfPageFormat.a4.width;
      return pw.Container(
        width: fieldWidth,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              field.label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 2,
              ),
              decoration: pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey400),
                ),
              ),
              child: pw.Text(
                value?.toString() ?? '',
                style: pw.TextStyle(font: regularFont, fontSize: fontSize),
              ),
            ),
          ],
        ),
      );

    case FormFieldDefinitionType.checkbox:
      final isChecked = value == true || value == 'true';
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          if (isChecked)
            pw.Container(
              width: 12,
              height: 12,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey600),
                borderRadius: pw.BorderRadius.circular(2),
              ),
              child: pw.Center(
                child: pw.CustomPaint(
                  size: const PdfPoint(8, 8),
                  painter: (canvas, size) {
                    canvas
                      ..setStrokeColor(PdfColors.black)
                      ..setLineWidth(1.5)
                      ..setLineCap(PdfLineCap.round)
                      ..drawLine(1, 4, 3.5, 1.5)
                      ..drawLine(3.5, 1.5, 7, 6.5)
                      ..strokePath();
                  },
                ),
              ),
            )
          else
            pw.Text('N/A', style: pw.TextStyle(font: boldFont, fontSize: 6)),
          pw.SizedBox(width: 4),
          pw.Text(
            field.label,
            style: pw.TextStyle(font: regularFont, fontSize: fontSize),
          ),
        ],
      );

    case FormFieldDefinitionType.radioGroup:
      final selectedValue = value?.toString() ?? '';
      return pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            field.label,
            style: pw.TextStyle(
              font: boldFont,
              fontSize: 8,
              color: PdfColors.grey600,
            ),
          ),
          pw.SizedBox(height: 2),
          ...?field.options?.map((option) {
            final isSelected = option == selectedValue;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 2),
              child: pw.Row(
                mainAxisSize: pw.MainAxisSize.min,
                children: [
                  pw.Container(
                    width: 10,
                    height: 10,
                    decoration: pw.BoxDecoration(
                      shape: pw.BoxShape.circle,
                      border: pw.Border.all(color: PdfColors.grey600),
                    ),
                    child: isSelected
                        ? pw.Center(
                            child: pw.Container(
                              width: 6,
                              height: 6,
                              decoration: const pw.BoxDecoration(
                                shape: pw.BoxShape.circle,
                                color: PdfColors.grey800,
                              ),
                            ),
                          )
                        : pw.SizedBox(),
                  ),
                  pw.SizedBox(width: 4),
                  pw.Text(
                    option,
                    style: pw.TextStyle(
                      font: regularFont,
                      fontSize: fontSize - 1,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      );

    case FormFieldDefinitionType.signature:
      final sigWidth = (field.width / 100) * PdfPageFormat.a4.width;
      final sigHeight = (field.height / 100) * PdfPageFormat.a4.height;
      return pw.Container(
        width: sigWidth,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              field.label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Container(
              height: sigHeight,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: value != null && value is String && value.isNotEmpty
                  ? _buildSignatureImageFromBytes(value, field.id, resolvedFileBytes)
                  : pw.Center(
                      child: pw.Text(
                        'No signature',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8,
                          color: PdfColors.grey400,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );

    case FormFieldDefinitionType.image:
      final imgWidth = (field.width / 100) * PdfPageFormat.a4.width;
      final imgHeight = (field.height / 100) * PdfPageFormat.a4.height;
      return pw.Container(
        width: imgWidth,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              field.label,
              style: pw.TextStyle(
                font: boldFont,
                fontSize: 8,
                color: PdfColors.grey600,
              ),
            ),
            pw.SizedBox(height: 2),
            pw.Container(
              height: imgHeight,
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey400),
              ),
              child: value != null && value is String && value.isNotEmpty
                  ? _buildImageFromBytes(field.id, resolvedFileBytes)
                  : pw.Center(
                      child: pw.Text(
                        'No image',
                        style: pw.TextStyle(
                          font: regularFont,
                          fontSize: 8,
                          color: PdfColors.grey400,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      );
  }
}

/// Build signature image from pre-loaded bytes or base64 data.
pw.Widget _buildSignatureImageFromBytes(String signatureData, String fieldId, Map<String, Uint8List> resolvedFileBytes) {
  try {
    if (signatureData.startsWith('data:image')) {
      final base64String = signatureData.split(',').last;
      final bytes = Uint8List.fromList(
        base64String.codeUnits.map((c) => c & 0xFF).toList(),
      );
      final image = pw.MemoryImage(bytes);
      return pw.Image(image, fit: pw.BoxFit.contain);
    } else {
      // Use pre-loaded file bytes
      final bytes = resolvedFileBytes[fieldId];
      if (bytes != null) {
        final image = pw.MemoryImage(bytes);
        return pw.Image(image, fit: pw.BoxFit.contain);
      }
    }
  } catch (e) {
    // Fall through
  }
  return pw.SizedBox();
}

/// Build image from pre-loaded file bytes.
pw.Widget _buildImageFromBytes(String fieldId, Map<String, Uint8List> resolvedFileBytes) {
  try {
    final bytes = resolvedFileBytes[fieldId];
    if (bytes != null) {
      final image = pw.MemoryImage(bytes);
      return pw.Image(image, fit: pw.BoxFit.contain);
    }
  } catch (e) {
    // Fall through
  }
  return pw.SizedBox();
}

// ── Syncfusion overlay helpers (top-level for isolate compatibility) ──

void _drawDebugRect({
  required sf.PdfPage page,
  required double x,
  required double y,
  required double width,
  required double height,
  required String label,
}) {
  final sf.PdfGraphics graphics = page.graphics;
  final sf.PdfPen pen = sf.PdfPen(sf.PdfColor(255, 0, 0), width: 0.5);
  final sf.PdfBrush labelBrush = sf.PdfSolidBrush(sf.PdfColor(255, 0, 0));
  final sf.PdfFont labelFont = sf.PdfStandardFont(
    sf.PdfFontFamily.helvetica,
    6,
  );

  graphics.drawRectangle(
    pen: pen,
    bounds: Rect.fromLTWH(x, y, width, height),
  );

  graphics.drawString(
    label,
    labelFont,
    brush: labelBrush,
    bounds: Rect.fromLTWH(x + 1, y + 1, width - 2, 8),
  );
}

void _drawTextOverlay({
  required sf.PdfPage page,
  required String text,
  required double x,
  required double y,
  required double width,
  required double height,
  required double fontSize,
}) {
  const double minSize = 6.0;
  double currentSize = fontSize;
  sf.PdfFont font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, currentSize);

  // Auto-shrink: reduce font size until text fits within bounds
  while (currentSize > minSize) {
    final measured = font.measureString(text, layoutArea: Size(width, height));
    if (measured.width <= width && measured.height <= height) break;
    currentSize -= 0.5;
    font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, currentSize);
  }

  final sf.PdfGraphics graphics = page.graphics;
  final sf.PdfBrush brush = sf.PdfSolidBrush(sf.PdfColor(0, 0, 0));

  final sf.PdfStringFormat format = sf.PdfStringFormat(
    alignment: sf.PdfTextAlignment.left,
    lineAlignment: sf.PdfVerticalAlignment.top,
  );

  graphics.drawString(
    text,
    font,
    brush: brush,
    bounds: Rect.fromLTWH(x, y, width, height),
    format: format,
  );
}

void _addCheckboxFormField({
  required sf.PdfDocument document,
  required sf.PdfPage page,
  required String fieldId,
  required double x,
  required double y,
  double size = 12,
}) {
  final sf.PdfCheckBoxField checkbox = sf.PdfCheckBoxField(
    page,
    'checkbox_$fieldId',
    Rect.fromLTWH(x, y, size, size),
  );

  checkbox.isChecked = true;
  checkbox.borderColor = sf.PdfColor(0, 0, 0);
  checkbox.backColor = sf.PdfColor(255, 255, 255);
  checkbox.foreColor = sf.PdfColor(0, 0, 0);
  checkbox.borderWidth = 0;
  checkbox.highlightMode = sf.PdfHighlightMode.noHighlighting;

  document.form.fields.add(checkbox);
}

void _addNAFormField({
  required sf.PdfDocument document,
  required sf.PdfPage page,
  required String fieldId,
  required double x,
  required double y,
  double size = 12,
}) {
  final sf.PdfTextBoxField textBox = sf.PdfTextBoxField(
    page,
    'na_$fieldId',
    Rect.fromLTWH(x, y, size, size),
  );

  textBox.text = 'N/A';
  textBox.font = sf.PdfStandardFont(sf.PdfFontFamily.helvetica, 6,
      style: sf.PdfFontStyle.bold);
  textBox.textAlignment = sf.PdfTextAlignment.center;
  textBox.borderColor = sf.PdfColor(255, 255, 255);
  textBox.backColor = sf.PdfColor(255, 255, 255, 0);
  textBox.foreColor = sf.PdfColor(0, 0, 0);
  textBox.borderWidth = 0;

  document.form.fields.add(textBox);
}

/// Draws a pre-loaded image (signature or photo) on a Syncfusion PDF page.
/// Uses pre-resolved bytes from [resolvedFileBytes], falling back to base64 decoding.
void _drawImageBytesOverlay({
  required sf.PdfPage page,
  required String fieldId,
  required String signatureData,
  required Map<String, Uint8List> resolvedFileBytes,
  required double x,
  required double y,
  required double width,
  required double height,
}) {
  try {
    Uint8List? imageBytes;

    if (signatureData.startsWith('data:image')) {
      final base64String = signatureData.split(',').last;
      imageBytes = base64Decode(base64String);
    } else {
      // Use pre-loaded file bytes
      imageBytes = resolvedFileBytes[fieldId];
    }

    if (imageBytes != null) {
      final sf.PdfBitmap image = sf.PdfBitmap(imageBytes);
      page.graphics.drawImage(image, Rect.fromLTWH(x, y, width, height));
    }
  } catch (e) {
    // Silently fail if image can't be loaded
  }
}

/// Extracts raw TTF bytes from a Font loaded via PdfGoogleFonts.
Uint8List _extractFontBytes(pw.Font font) {
  final ttf = font as pw.TtfFont;
  return Uint8List.fromList(
    ttf.data.buffer.asUint8List(ttf.data.offsetInBytes, ttf.data.lengthInBytes),
  );
}

/// Service for generating PDFs from filled templates
class TemplatePdfService {
  /// Generate a filled PDF from a template and field values
  ///
  /// Set [debugMode] to true to draw field boundaries for debugging positioning.
  static Future<Uint8List> generateFilledPdf({
    required PdfFormTemplate template,
    required Map<String, dynamic> fieldValues,
    required String engineerName,
    required String jobReference,
    bool debugMode = false,
  }) async {
    // ── Gather phase (main thread) ──
    Uint8List? regularFontBytes;
    Uint8List? boldFontBytes;
    try {
      final regularFont = await PdfGoogleFonts.nunitoSansRegular();
      final boldFont = await PdfGoogleFonts.nunitoSansBold();
      regularFontBytes = _extractFontBytes(regularFont);
      boldFontBytes = _extractFontBytes(boldFont);
    } catch (_) {
      // Google Fonts unavailable — isolate will fall back to Helvetica
    }

    // Pre-load file bytes for signature/image fields
    final resolvedFileBytes = await _resolveFileBytes(template.fields, fieldValues);

    final data = TemplatePdfData(
      templateJson: template.toJson(),
      fieldValues: fieldValues,
      engineerName: engineerName,
      jobReference: jobReference,
      debugMode: debugMode,
      regularFontBytes: regularFontBytes,
      boldFontBytes: boldFontBytes,
      resolvedFileBytes: resolvedFileBytes,
    );

    // ── Build phase (background isolate) ──
    if (kIsWeb) return _buildFilledPdf(data);
    return compute(_buildFilledPdf, data);
  }

  /// Preview the generated PDF
  static Future<void> previewPdf(Uint8List pdfBytes, String title) async {
    await Printing.layoutPdf(onLayout: (_) => pdfBytes, name: title);
  }

  /// Share the generated PDF
  static Future<void> sharePdf(Uint8List pdfBytes, String filename) async {
    await Printing.sharePdf(bytes: pdfBytes, filename: filename);
  }

  /// Generate a PDF with field values overlaid on the original PDF template
  /// Uses Syncfusion PDF library to modify the existing PDF
  ///
  /// Set [debugMode] to true to draw red rectangles showing field boundaries.
  static Future<Uint8List> generateOverlayPdf({
    required PdfFormTemplate template,
    required Map<String, dynamic> fieldValues,
    bool debugMode = false,
  }) async {
    // ── Gather phase (main thread) ──

    // Load the base PDF from assets or file (uses platform channels)
    Uint8List basePdfBytes;
    if (template.isBundled) {
      final ByteData byteData = await rootBundle.load(template.pdfPath);
      basePdfBytes = byteData.buffer.asUint8List();
    } else {
      final file = File(template.pdfPath);
      basePdfBytes = await file.readAsBytes();
    }

    // Pre-load file bytes for signature/image fields
    final resolvedFileBytes = await _resolveFileBytes(template.fields, fieldValues);

    final data = TemplateOverlayPdfData(
      templateJson: template.toJson(),
      fieldValues: fieldValues,
      debugMode: debugMode,
      basePdfBytes: basePdfBytes,
      resolvedFileBytes: resolvedFileBytes,
    );

    // ── Build phase (background isolate) ──
    if (kIsWeb) return _buildOverlayPdf(data);
    return compute(_buildOverlayPdf, data);
  }

  /// Pre-loads file bytes for signature and image fields on the main thread.
  /// Returns a map of fieldId -> file bytes.
  static Future<Map<String, Uint8List>> _resolveFileBytes(
    List<FormFieldDefinition> fields,
    Map<String, dynamic> fieldValues,
  ) async {
    final resolved = <String, Uint8List>{};

    for (final field in fields) {
      if (field.type != FormFieldDefinitionType.signature &&
          field.type != FormFieldDefinitionType.image) {
        continue;
      }

      final value = fieldValues[field.id];
      if (value == null || value is! String || value.isEmpty) continue;

      // Skip base64 data — it will be decoded in the isolate
      if (value.startsWith('data:image')) continue;

      // It's a file path — read the bytes on the main thread
      try {
        final file = File(value);
        if (await file.exists()) {
          resolved[field.id] = await file.readAsBytes();
        }
      } catch (_) {
        // Skip if file can't be read
      }
    }

    return resolved;
  }
}
