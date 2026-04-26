import 'dart:typed_data';
import 'package:pdf/widgets.dart' as pw;
import '../../models/pdf_branding.dart';
import 'pdf_brand_tokens.dart';

class PdfHeaderBuilder {
  PdfHeaderBuilder._();

  static pw.Widget build({
    required PdfBranding branding,
    required String companyName,
    required String metaText,
    required Uint8List? logoBytes,
  }) {
    final showName = branding.headerShowCompanyName;
    final showDoc = branding.headerShowDocNumber;

    if (!showName && !showDoc) return pw.SizedBox.shrink();

    return switch (branding.headerStyle) {
      HeaderStyle.solid => _buildSolid(
          branding: branding,
          companyName: companyName,
          metaText: metaText,
          logoBytes: logoBytes,
          showName: showName,
          showDoc: showDoc,
        ),
      HeaderStyle.minimal => _buildMinimal(
          branding: branding,
          companyName: companyName,
          metaText: metaText,
          logoBytes: logoBytes,
          showName: showName,
          showDoc: showDoc,
        ),
      HeaderStyle.bordered => _buildBordered(
          branding: branding,
          companyName: companyName,
          metaText: metaText,
          logoBytes: logoBytes,
          showName: showName,
          showDoc: showDoc,
        ),
    };
  }

  static pw.Widget _buildSolid({
    required PdfBranding branding,
    required String companyName,
    required String metaText,
    required Uint8List? logoBytes,
    required bool showName,
    required bool showDoc,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: pw.BoxDecoration(color: PdfBrandTokens.primary(branding)),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (showName)
            _buildLeftSide(branding, companyName, logoBytes)
          else
            pw.SizedBox.shrink(),
          if (showDoc)
            pw.Text(metaText, style: PdfBrandTokens.headerMeta(branding))
          else
            pw.SizedBox.shrink(),
        ],
      ),
    );
  }

  static pw.Widget _buildMinimal({
    required PdfBranding branding,
    required String companyName,
    required String metaText,
    required Uint8List? logoBytes,
    required bool showName,
    required bool showDoc,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfBrandTokens.accent(branding), width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (showName)
            _buildLeftSide(branding, companyName, logoBytes)
          else
            pw.SizedBox.shrink(),
          if (showDoc)
            pw.Text(metaText, style: PdfBrandTokens.headerMeta(branding))
          else
            pw.SizedBox.shrink(),
        ],
      ),
    );
  }

  static pw.Widget _buildBordered({
    required PdfBranding branding,
    required String companyName,
    required String metaText,
    required Uint8List? logoBytes,
    required bool showName,
    required bool showDoc,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: const pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfBrandTokens.border, width: 1),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          if (showName)
            _buildLeftSide(branding, companyName, logoBytes)
          else
            pw.SizedBox.shrink(),
          if (showDoc)
            pw.Text(metaText, style: PdfBrandTokens.headerMeta(branding))
          else
            pw.SizedBox.shrink(),
        ],
      ),
    );
  }

  static pw.Widget _buildLeftSide(
    PdfBranding branding,
    String companyName,
    Uint8List? logoBytes,
  ) {
    return pw.Row(
      children: [
        _buildLogoMark(branding, companyName, logoBytes),
        pw.SizedBox(width: 10),
        pw.Text(companyName, style: PdfBrandTokens.headerCompanyName(branding)),
      ],
    );
  }

  static pw.Widget _buildLogoMark(
    PdfBranding branding,
    String companyName,
    Uint8List? logoBytes,
  ) {
    final initial = companyName.isNotEmpty ? companyName[0].toUpperCase() : 'F';

    return pw.Container(
      width: 28,
      height: 28,
      decoration: pw.BoxDecoration(
        color: PdfBrandTokens.accent(branding),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Center(
        child: logoBytes != null
            ? pw.Image(pw.MemoryImage(logoBytes), width: 20, height: 20)
            : pw.Text(initial,
                style: PdfBrandTokens.logoInitial(branding, size: 14)),
      ),
    );
  }
}
