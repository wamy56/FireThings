import 'dart:typed_data';
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
  bool showCompanyName = true,
  bool showDocNumber = true,
}) {
  switch (config.headerStyle) {
    case HeaderStyle.classic:
      return _buildClassicStyleHeader(
          config, colors, logoBytes, documentType, documentRef, fallbackValues,
          showCompanyName: showCompanyName, showDocNumber: showDocNumber);
    case HeaderStyle.minimal:
      return _buildMinimalStyleHeader(
          config, colors, logoBytes, documentType, documentRef, fallbackValues,
          showCompanyName: showCompanyName, showDocNumber: showDocNumber);
  }
}

/// Classic style: White background with bottom border
pw.Widget _buildClassicStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues, {
  bool showCompanyName = true,
  bool showDocNumber = true,
}) {
  final badgeChildren = <pw.Widget>[
    pw.Text(
      documentType.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: pdfWhite,
        letterSpacing: 1,
      ),
    ),
  ];

  if (showDocNumber) {
    badgeChildren.add(pw.SizedBox(height: 6));
    badgeChildren.add(
      pw.Text(
        'REF: $documentRef',
        style: pw.TextStyle(fontSize: 9, color: pdfWhite),
      ),
    );
  }

  final contentRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 5,
        child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues, showCompanyName: showCompanyName),
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
          children: badgeChildren,
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
    child: contentRow,
  );
}

/// Minimal style: Clean with extra spacing, no borders
pw.Widget _buildMinimalStyleHeader(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  String documentType,
  String documentRef,
  Map<String, String> fallbackValues, {
  bool showCompanyName = true,
  bool showDocNumber = true,
}) {
  final rightChildren = <pw.Widget>[
    pw.Text(
      documentType.toUpperCase(),
      style: pw.TextStyle(
        fontSize: 24,
        fontWeight: pw.FontWeight.bold,
        color: colors.primaryColor,
        letterSpacing: 2,
      ),
    ),
  ];

  if (showDocNumber) {
    rightChildren.add(pw.SizedBox(height: 4));
    rightChildren.add(
      pw.Text(
        'REF: $documentRef',
        style: pw.TextStyle(fontSize: 10, color: colors.textSecondary),
      ),
    );
  }

  final contentRow = pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Expanded(
        flex: 3,
        child: _buildLogoAndInfo(config, colors, logoBytes, fallbackValues, showCompanyName: showCompanyName),
      ),
      pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: rightChildren,
      ),
    ],
  );

  return pw.Container(
    padding: const pw.EdgeInsets.only(bottom: 16),
    margin: const pw.EdgeInsets.only(bottom: 8),
    child: contentRow,
  );
}

/// Build logo and company info section
pw.Widget _buildLogoAndInfo(
  PdfHeaderConfig config,
  PdfColourScheme colors,
  Uint8List? logoBytes,
  Map<String, String> fallbackValues, {
  bool showCompanyName = true,
}) {
  final children = <pw.Widget>[];

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

  final textWidgets = <pw.Widget>[];
  for (final line in config.leftLines) {
    if (line.key == 'companyName' && !showCompanyName) continue;

    final value =
        line.value.isNotEmpty ? line.value : fallbackValues[line.key] ?? '';
    if (value.isEmpty) continue;

    textWidgets.add(
      pw.Text(
        value,
        style: pw.TextStyle(
          fontSize: line.fontSize,
          fontWeight: line.bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: line.fontSize > 12 ? colors.textPrimary : colors.textSecondary,
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
