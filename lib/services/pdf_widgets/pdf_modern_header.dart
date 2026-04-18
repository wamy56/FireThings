import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_header_config.dart';
import '../../models/pdf_colour_scheme.dart';
import 'pdf_style_helpers.dart';

/// Builds the document header based on configured style
pw.Widget buildModernHeader({
  required PdfHeaderConfig config,
  required PdfColourScheme colors,
  required Uint8List? logoBytes,
  required String documentType,
  required String documentRef,
  Map<String, String> fallbackValues = const {},
}) {
  switch (config.headerStyle) {
    case HeaderStyle.modern:
      return _buildModernStyleHeader(
          config, colors, logoBytes, documentType, documentRef, fallbackValues);
    case HeaderStyle.classic:
      return _buildClassicStyleHeader(
          config, colors, logoBytes, documentType, documentRef, fallbackValues);
    case HeaderStyle.minimal:
      return _buildMinimalStyleHeader(
          config, colors, logoBytes, documentType, documentRef, fallbackValues);
  }
}

/// Build a centred logo widget for use above the header content row
pw.Widget? _buildCentredLogo(PdfHeaderConfig config, Uint8List? logoBytes) {
  if (config.logoZone != LogoZone.centre || logoBytes == null) return null;
  return pw.Center(
    child: pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 8),
      child: pw.Image(
        pw.MemoryImage(logoBytes),
        height: config.logoSize.pixels,
      ),
    ),
  );
}

/// Modern style: Solid primary background with rounded bottom corners
pw.Widget _buildModernStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues,
) {
  final centredLogo = _buildCentredLogo(config, logoBytes);

  final contentRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      // Logo + Company info
      pw.Expanded(
        flex: 3,
        child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues,
            isModern: true),
      ),
      pw.SizedBox(width: 16),
      // Document badge
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0x26FFFFFF), // 15% white overlay
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              documentType.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
                color: pdfWhite,
                letterSpacing: 1.5,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'REF: $documentRef',
              style: pw.TextStyle(
                fontSize: 9,
                color: const PdfColor.fromInt(0xCCFFFFFF),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  return pw.Container(
    padding: pw.EdgeInsets.symmetric(
      horizontal: config.horizontalPadding,
      vertical: config.verticalPadding,
    ),
    decoration: pw.BoxDecoration(
      color: colors.primaryColor,
      borderRadius: pw.BorderRadius.only(
        bottomLeft: pw.Radius.circular(config.cornerRadius.pixels),
        bottomRight: pw.Radius.circular(config.cornerRadius.pixels),
      ),
    ),
    child: centredLogo != null
        ? pw.Column(children: [centredLogo, contentRow])
        : contentRow,
  );
}

/// Classic style: White background with bottom border (current look)
pw.Widget _buildClassicStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues,
) {
  final centredLogo = _buildCentredLogo(config, logoBytes);

  final contentRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 5,
        child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues,
            isModern: false),
      ),
      pw.SizedBox(width: 12),
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: pw.BoxDecoration(
          color: colors.primaryColor,
          borderRadius: pw.BorderRadius.circular(4),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              documentType.toUpperCase(),
              style: pw.TextStyle(
                fontSize: 14,
                fontWeight: pw.FontWeight.bold,
                color: pdfWhite,
                letterSpacing: 1,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'REF: $documentRef',
              style: pw.TextStyle(
                fontSize: 9,
                color: const PdfColor.fromInt(0xCCFFFFFF),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 8),
    margin: const pw.EdgeInsets.only(bottom: 4),
    decoration: pw.BoxDecoration(
      border: pw.Border(
        bottom: pw.BorderSide(color: colors.primaryColor, width: 2),
      ),
    ),
    child: centredLogo != null
        ? pw.Column(children: [centredLogo, contentRow])
        : contentRow,
  );
}

/// Minimal style: Clean with extra spacing, no borders
pw.Widget _buildMinimalStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues,
) {
  final centredLogo = _buildCentredLogo(config, logoBytes);

  final contentRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues,
            isModern: false),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Text(
            documentType.toUpperCase(),
            style: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
              color: colors.primaryColor,
              letterSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'REF: $documentRef',
            style: pw.TextStyle(
              fontSize: 10,
              color: colors.textSecondary,
            ),
          ),
        ],
      ),
    ],
  );

  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 16),
    margin: const pw.EdgeInsets.only(bottom: 8),
    child: centredLogo != null
        ? pw.Column(children: [centredLogo, contentRow])
        : contentRow,
  );
}

/// Build logo and company info section
pw.Widget _buildLogoAndInfo(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  Map<String, String> fallbackValues, {
  required bool isModern,
}) {
  final textColor = isModern ? pdfWhite : colors.textPrimary;
  final secondaryTextColor =
      isModern ? const PdfColor.fromInt(0xCCFFFFFF) : colors.textSecondary;

  final children = <pw.Widget>[];

  // Add logo if configured on left
  if (config.logoZone == LogoZone.left && logoBytes != null) {
    children.add(
      pw.Container(
        margin: const pw.EdgeInsets.only(right: 12),
        child: pw.Image(
          pw.MemoryImage(logoBytes),
          height: config.logoSize.pixels,
        ),
      ),
    );
  }

  // Add text lines
  final textWidgets = <pw.Widget>[];
  for (final line in config.leftLines) {
    final value =
        line.value.isNotEmpty ? line.value : fallbackValues[line.key] ?? '';
    if (value.isEmpty) continue;

    textWidgets.add(
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: line.fontSize,
          fontWeight: line.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: line.fontSize > 12 ? textColor : secondaryTextColor,
        ),
      ),
    );
    textWidgets.add(pw.SizedBox(height: 2));
  }

  if (textWidgets.isNotEmpty) {
    children.add(
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: textWidgets,
        ),
      ),
    );
  }

  return pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: children,
  );
}
