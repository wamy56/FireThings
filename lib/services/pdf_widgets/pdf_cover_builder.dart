import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../models/pdf_branding.dart';
import 'pdf_brand_tokens.dart';
import 'pdf_font_registry.dart';

// ═══════════════════════════════════════════════════════════════════════
// New API — Session 1.2+
// ═══════════════════════════════════════════════════════════════════════

class PdfCoverBuilder {
  PdfCoverBuilder._();

  static pw.Widget build({
    required PdfBranding branding,
    required BrandingDocType docType,
    required String defaultEyebrow,
    required String defaultTitle,
    required String defaultSubtitle,
    required List<({String label, String value})> metaFields,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    final coverText = branding.coverTextFor(docType);
    final eyebrow = coverText?.eyebrow ?? defaultEyebrow;
    final title = coverText?.title ?? defaultTitle;
    final subtitle = coverText?.subtitle ?? defaultSubtitle;

    return switch (branding.coverStyle) {
      CoverStyle.bold => _buildBold(
          branding: branding,
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          metaFields: metaFields,
          logoBytes: logoBytes,
          companyName: companyName,
        ),
      CoverStyle.minimal => _buildMinimal(
          branding: branding,
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          metaFields: metaFields,
          logoBytes: logoBytes,
          companyName: companyName,
        ),
      CoverStyle.bordered => _buildBordered(
          branding: branding,
          eyebrow: eyebrow,
          title: title,
          subtitle: subtitle,
          metaFields: metaFields,
          logoBytes: logoBytes,
          companyName: companyName,
        ),
    };
  }

  // ── Bold ──

  static pw.Widget _buildBold({
    required PdfBranding branding,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<({String label, String value})> metaFields,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    final primary = PdfBrandTokens.primary(branding);
    final accent = PdfBrandTokens.accent(branding);
    final accentGlow = PdfColor.fromInt(
        (accent.toInt() & 0x00FFFFFF) | 0x2E000000);

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      color: primary,
      child: pw.Stack(
        children: [
          // Radial glow in top-right corner
          pw.Positioned(
            top: -80,
            right: -80,
            child: pw.Container(
              width: 320,
              height: 320,
              decoration: pw.BoxDecoration(
                shape: pw.BoxShape.circle,
                gradient: pw.RadialGradient(
                  colors: [accentGlow, PdfColor(0, 0, 0, 0)],
                  stops: [0, 0.7],
                ),
              ),
            ),
          ),
          // Content
          pw.Padding(
            padding: pw.EdgeInsets.fromLTRB(48, 56, 48, 40),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  eyebrow.toUpperCase(),
                  style: PdfBrandTokens.coverEyebrow(branding),
                ),
                pw.SizedBox(height: 16),
                _buildLogoRow(
                  branding: branding,
                  logoBytes: logoBytes,
                  companyName: companyName,
                ),
                pw.SizedBox(height: 56),
                pw.Text(title, style: PdfBrandTokens.coverTitle(branding)),
                pw.SizedBox(height: 12),
                pw.Text(subtitle, style: PdfBrandTokens.coverSubtitle(branding)),
                pw.SizedBox(height: 56),
                _buildMetaGrid(branding: branding, metaFields: metaFields),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Minimal ──

  static pw.Widget _buildMinimal({
    required PdfBranding branding,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<({String label, String value})> metaFields,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    final accent = PdfBrandTokens.accent(branding);

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: pw.EdgeInsets.fromLTRB(56, 80, 56, 56),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            eyebrow.toUpperCase(),
            style: PdfBrandTokens.coverEyebrow(branding),
          ),
          pw.SizedBox(height: 16),
          _buildLogoRow(
            branding: branding,
            logoBytes: logoBytes,
            companyName: companyName,
          ),
          pw.SizedBox(height: 56),
          pw.Container(width: 56, height: 4, color: accent),
          pw.SizedBox(height: 24),
          pw.Text(title, style: PdfBrandTokens.coverTitle(branding)),
          pw.SizedBox(height: 12),
          pw.Text(subtitle, style: PdfBrandTokens.coverSubtitle(branding)),
          pw.SizedBox(height: 56),
          _buildMetaGrid(branding: branding, metaFields: metaFields),
        ],
      ),
    );
  }

  // ── Bordered ──

  static pw.Widget _buildBordered({
    required PdfBranding branding,
    required String eyebrow,
    required String title,
    required String subtitle,
    required List<({String label, String value})> metaFields,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    final primary = PdfBrandTokens.primary(branding);

    return pw.Container(
      width: double.infinity,
      height: double.infinity,
      padding: pw.EdgeInsets.fromLTRB(56, 56, 56, 56),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: primary, width: 8),
          bottom: pw.BorderSide(color: primary, width: 8),
        ),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            eyebrow.toUpperCase(),
            style: PdfBrandTokens.coverEyebrow(branding),
          ),
          pw.SizedBox(height: 16),
          _buildLogoRow(
            branding: branding,
            logoBytes: logoBytes,
            companyName: companyName,
          ),
          pw.SizedBox(height: 56),
          pw.Text(title, style: PdfBrandTokens.coverTitle(branding)),
          pw.SizedBox(height: 12),
          pw.Text(subtitle, style: PdfBrandTokens.coverSubtitle(branding)),
          pw.SizedBox(height: 56),
          _buildMetaGrid(branding: branding, metaFields: metaFields),
        ],
      ),
    );
  }

  // ── Shared helpers ──

  static pw.Widget _buildLogoRow({
    required PdfBranding branding,
    required Uint8List? logoBytes,
    required String companyName,
  }) {
    final accent = PdfBrandTokens.accent(branding);
    final primary = PdfBrandTokens.primary(branding);
    final fonts = PdfFontRegistry.instance;

    final pw.Widget logoMark;
    if (logoBytes != null) {
      logoMark = pw.Container(
        width: 44,
        height: 44,
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Image(
            pw.MemoryImage(logoBytes),
            height: branding.logoMaxHeight.clamp(20, 36),
            fit: pw.BoxFit.contain,
          ),
        ),
      );
    } else {
      final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'F';
      logoMark = pw.Container(
        width: 44,
        height: 44,
        decoration: pw.BoxDecoration(
          color: accent,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Center(
          child: pw.Text(
            initial,
            style: pw.TextStyle(
              font: fonts.outfitDisplay,
              fontSize: 22,
              color: primary,
            ),
          ),
        ),
      );
    }

    return pw.Row(
      children: [
        logoMark,
        pw.SizedBox(width: 12),
        pw.Text(
          companyName,
          style: PdfBrandTokens.coverCompanyName(branding),
        ),
      ],
    );
  }

  static pw.Widget _buildMetaGrid({
    required PdfBranding branding,
    required List<({String label, String value})> metaFields,
  }) {
    final onDark = branding.coverStyle == CoverStyle.bold;
    final borderColor = onDark
        ? const PdfColor.fromInt(0x26FFFFFF)
        : PdfBrandTokens.border;

    return pw.Container(
      padding: pw.EdgeInsets.only(top: 24),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          top: pw.BorderSide(color: borderColor, width: 0.5),
        ),
      ),
      child: pw.Wrap(
        spacing: 32,
        runSpacing: 16,
        children: metaFields
            .map((m) => _buildMetaItem(branding: branding, label: m.label, value: m.value))
            .toList(),
      ),
    );
  }

  static pw.Widget _buildMetaItem({
    required PdfBranding branding,
    required String label,
    required String value,
  }) {
    return pw.SizedBox(
      width: 220,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            label.toUpperCase(),
            style: PdfBrandTokens.coverMetaLabel(branding),
          ),
          pw.SizedBox(height: 3),
          pw.Text(
            value,
            style: PdfBrandTokens.coverMetaValue(branding),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// Legacy API — kept for backward compatibility until Sessions 1.3/1.4
// rewire the five PDF services to use PdfCoverBuilder.build() directly.
// ═══════════════════════════════════════════════════════════════════════

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
  final branding = PdfBranding(
    coverStyle: style,
    primaryColour: _pdfColorToHex(primaryColor),
    accentColour: _pdfColorToHex(accentColor),
    logoMaxHeight: logoMaxHeight,
    updatedAt: DateTime.now(),
    lastModifiedAt: DateTime.now(),
  );

  return pw.Page(
    pageFormat: PdfPageFormat.a4,
    margin: pw.EdgeInsets.zero,
    build: (_) => PdfCoverBuilder.build(
      branding: branding,
      docType: BrandingDocType.report,
      defaultEyebrow: eyebrow,
      defaultTitle: title,
      defaultSubtitle: subtitle,
      metaFields: metaItems,
      logoBytes: logoBytes,
      companyName: companyName,
    ),
  );
}

String _pdfColorToHex(PdfColor c) {
  final r = (c.red * 255).round().toRadixString(16).padLeft(2, '0');
  final g = (c.green * 255).round().toRadixString(16).padLeft(2, '0');
  final b = (c.blue * 255).round().toRadixString(16).padLeft(2, '0');
  return '#$r$g$b';
}
