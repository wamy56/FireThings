import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/pdf_branding.dart';

const PdfColor _white = PdfColors.white;
const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
const PdfColor _borderGray = PdfColor.fromInt(0xFFE8E5DE);

PdfColor hexToPdfColor(String hex) {
  final clean = hex.replaceFirst('#', '');
  return PdfColor.fromInt(0xFF000000 | int.parse(clean, radix: 16));
}

pw.Page buildBrandedCoverPage({
  required CoverStyle style,
  required PdfColor primaryColor,
  required PdfColor accentColor,
  required String eyebrow,
  required String title,
  required String subtitle,
  required Uint8List? logoBytes,
  required double logoMaxHeight,
  required String companyName,
  required List<({String label, String value})> metaItems,
  List<pw.Widget> additionalContent = const [],
}) {
  return switch (style) {
    CoverStyle.bold => _buildBoldCover(
        primaryColor: primaryColor,
        accentColor: accentColor,
        eyebrow: eyebrow,
        title: title,
        subtitle: subtitle,
        logoBytes: logoBytes,
        logoMaxHeight: logoMaxHeight,
        companyName: companyName,
        metaItems: metaItems,
        additionalContent: additionalContent,
      ),
    CoverStyle.minimal => _buildMinimalCover(
        primaryColor: primaryColor,
        accentColor: accentColor,
        eyebrow: eyebrow,
        title: title,
        subtitle: subtitle,
        logoBytes: logoBytes,
        logoMaxHeight: logoMaxHeight,
        companyName: companyName,
        metaItems: metaItems,
        additionalContent: additionalContent,
      ),
    CoverStyle.bordered => _buildBorderedCover(
        primaryColor: primaryColor,
        accentColor: accentColor,
        eyebrow: eyebrow,
        title: title,
        subtitle: subtitle,
        logoBytes: logoBytes,
        logoMaxHeight: logoMaxHeight,
        companyName: companyName,
        metaItems: metaItems,
        additionalContent: additionalContent,
      ),
  };
}

// ── Bold ──

pw.Page _buildBoldCover({
  required PdfColor primaryColor,
  required PdfColor accentColor,
  required String eyebrow,
  required String title,
  required String subtitle,
  required Uint8List? logoBytes,
  required double logoMaxHeight,
  required String companyName,
  required List<({String label, String value})> metaItems,
  required List<pw.Widget> additionalContent,
}) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (context) => pw.Container(
      width: double.infinity,
      height: double.infinity,
      color: primaryColor,
      padding: const pw.EdgeInsets.fromLTRB(48, 56, 48, 40),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildLogoRow(
            logoBytes: logoBytes,
            logoMaxHeight: logoMaxHeight,
            companyName: companyName,
            nameColor: _white,
            logoBgColor: accentColor,
          ),
          pw.SizedBox(height: 48),
          pw.Text(
            eyebrow,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColor.fromInt(
                  (accentColor.toInt() & 0x00FFFFFF) | 0xDD000000),
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: _white,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            subtitle,
            style: pw.TextStyle(
              fontSize: 13,
              color: PdfColor.fromInt(0xBFFFFFFF),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                    color: PdfColor.fromInt(0x26FFFFFF), width: 0.5),
              ),
            ),
            child: pw.Wrap(
              spacing: 32,
              runSpacing: 14,
              children: metaItems
                  .map((m) =>
                      _buildCoverMeta(m.label, m.value, onDark: true))
                  .toList(),
            ),
          ),
          if (additionalContent.isNotEmpty) ...[
            pw.Spacer(),
            ...additionalContent,
          ],
        ],
      ),
    ),
  );
}

// ── Minimal ──

pw.Page _buildMinimalCover({
  required PdfColor primaryColor,
  required PdfColor accentColor,
  required String eyebrow,
  required String title,
  required String subtitle,
  required Uint8List? logoBytes,
  required double logoMaxHeight,
  required String companyName,
  required List<({String label, String value})> metaItems,
  required List<pw.Widget> additionalContent,
}) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.all(48),
    build: (context) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        _buildLogoRow(
          logoBytes: logoBytes,
          logoMaxHeight: logoMaxHeight,
          companyName: companyName,
          nameColor: primaryColor,
          logoBgColor: accentColor,
        ),
        pw.SizedBox(height: 56),
        pw.Text(
          eyebrow,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: accentColor,
            letterSpacing: 1.4,
          ),
        ),
        pw.SizedBox(height: 16),
        pw.Container(width: 56, height: 4, color: accentColor),
        pw.SizedBox(height: 20),
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 28,
            fontWeight: pw.FontWeight.bold,
            color: primaryColor,
            lineSpacing: 2,
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          subtitle,
          style: const pw.TextStyle(
            fontSize: 13,
            color: PdfColor.fromInt(0xFF666666),
          ),
        ),
        pw.SizedBox(height: 40),
        pw.Container(
          padding: const pw.EdgeInsets.only(top: 20),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: _borderGray, width: 0.5),
            ),
          ),
          child: pw.Wrap(
            spacing: 32,
            runSpacing: 14,
            children: metaItems
                .map((m) =>
                    _buildCoverMeta(m.label, m.value, onDark: false))
                .toList(),
          ),
        ),
        if (additionalContent.isNotEmpty) ...[
          pw.Spacer(),
          ...additionalContent,
        ],
      ],
    ),
  );
}

// ── Bordered ──

pw.Page _buildBorderedCover({
  required PdfColor primaryColor,
  required PdfColor accentColor,
  required String eyebrow,
  required String title,
  required String subtitle,
  required Uint8List? logoBytes,
  required double logoMaxHeight,
  required String companyName,
  required List<({String label, String value})> metaItems,
  required List<pw.Widget> additionalContent,
}) {
  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (context) => pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: const pw.EdgeInsets.fromLTRB(48, 56, 48, 40),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: primaryColor, width: 8),
          bottom: pw.BorderSide(color: primaryColor, width: 8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          _buildLogoRow(
            logoBytes: logoBytes,
            logoMaxHeight: logoMaxHeight,
            companyName: companyName,
            nameColor: primaryColor,
            logoBgColor: accentColor,
          ),
          pw.SizedBox(height: 56),
          pw.Text(
            eyebrow,
            style: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: accentColor,
              letterSpacing: 1.4,
            ),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 28,
              fontWeight: pw.FontWeight.bold,
              color: primaryColor,
              lineSpacing: 2,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            subtitle,
            style: const pw.TextStyle(
              fontSize: 13,
              color: PdfColor.fromInt(0xFF666666),
            ),
          ),
          pw.SizedBox(height: 40),
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 20),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: _borderGray, width: 0.5),
              ),
            ),
            child: pw.Wrap(
              spacing: 32,
              runSpacing: 14,
              children: metaItems
                  .map((m) =>
                      _buildCoverMeta(m.label, m.value, onDark: false))
                  .toList(),
            ),
          ),
          if (additionalContent.isNotEmpty) ...[
            pw.Spacer(),
            ...additionalContent,
          ],
        ],
      ),
    ),
  );
}

// ── Shared helpers ──

pw.Widget _buildLogoRow({
  required Uint8List? logoBytes,
  required double logoMaxHeight,
  required String companyName,
  required PdfColor nameColor,
  required PdfColor logoBgColor,
}) {
  return pw.Row(
    children: [
      if (logoBytes != null) ...[
        pw.Image(
          pw.MemoryImage(logoBytes),
          height: logoMaxHeight,
          fit: pw.BoxFit.contain,
        ),
        pw.SizedBox(width: 12),
      ],
      pw.Text(
        companyName,
        style: pw.TextStyle(
          fontSize: 16,
          fontWeight: pw.FontWeight.bold,
          color: nameColor,
        ),
      ),
    ],
  );
}

pw.Widget _buildCoverMeta(String label, String value,
    {required bool onDark}) {
  return pw.SizedBox(
    width: 220,
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            fontWeight: pw.FontWeight.bold,
            color: onDark
                ? const PdfColor.fromInt(0x80FFFFFF)
                : _darkGray,
            letterSpacing: 0.4,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 12,
            fontWeight: pw.FontWeight.bold,
            color: onDark ? _white : const PdfColor.fromInt(0xFF1A1A2E),
          ),
        ),
      ],
    ),
  );
}
