import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/pdf_branding.dart';
import '../models/pdf_footer_config.dart';
import '../models/pdf_header_config.dart';
import 'pdf_widgets/pdf_brand_tokens.dart';

class PdfFooterBuilder {
  static const PdfColor _darkGray = PdfColor.fromInt(0xFF424242);
  static const PdfColor _midGray = PdfColor.fromInt(0xFF757575);
  static const PdfColor _lightGray = PdfColor.fromInt(0xFFE0E0E0);
  static const PdfColor _white = PdfColors.white;

  static pw.Widget buildFooter({
    required PdfFooterConfig config,
    required int pageNumber,
    required int pagesCount,
    Map<String, String> fallbackValues = const {},
    PdfColor? primaryColor,
    FooterStyle? brandingFooterStyle,
    PdfColor? accentColor,
    bool showPageNumbers = true,
  }) {
    if (brandingFooterStyle != null) {
      return switch (brandingFooterStyle) {
        FooterStyle.light => _buildLightFooter(
            config, pageNumber, pagesCount, fallbackValues,
            primaryColor: primaryColor, showPageNumbers: showPageNumbers),
        FooterStyle.minimal => _buildMinimalFooter(
            config, pageNumber, pagesCount, fallbackValues,
            showPageNumbers: showPageNumbers),
        FooterStyle.coloured => _buildColouredFooter(
            config, pageNumber, pagesCount, fallbackValues,
            bgColor: accentColor ?? primaryColor ?? _darkGray,
            showPageNumbers: showPageNumbers),
      };
    }

    return _buildLightFooter(
        config, pageNumber, pagesCount, fallbackValues,
        primaryColor: primaryColor, showPageNumbers: showPageNumbers);
  }

  // ═════════════════════════════════════════════════════════════════════
  // New branded footer — Session 1.3+
  // ═════════════════════════════════════════════════════════════════════

  static pw.Widget buildBrandedFooter({
    required PdfBranding branding,
    required int pageNumber,
    required int pagesCount,
    required String companyName,
    required String defaultFooterText,
  }) {
    return switch (branding.footerStyle) {
      FooterStyle.light => _buildBrandedLight(
          branding: branding,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          companyName: companyName,
          defaultFooterText: defaultFooterText,
        ),
      FooterStyle.minimal => _buildBrandedMinimal(
          branding: branding,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          companyName: companyName,
          defaultFooterText: defaultFooterText,
        ),
      FooterStyle.coloured => _buildBrandedColoured(
          branding: branding,
          pageNumber: pageNumber,
          pagesCount: pagesCount,
          companyName: companyName,
          defaultFooterText: defaultFooterText,
        ),
    };
  }

  static pw.Widget _buildBrandedLight({
    required PdfBranding branding,
    required int pageNumber,
    required int pagesCount,
    required String companyName,
    required String defaultFooterText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: PdfBrandTokens.bgAlt,
      child: _buildBrandedRow(branding, pageNumber, pagesCount, companyName, defaultFooterText),
    );
  }

  static pw.Widget _buildBrandedMinimal({
    required PdfBranding branding,
    required int pageNumber,
    required int pagesCount,
    required String companyName,
    required String defaultFooterText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: PdfBrandTokens.border, width: 1)),
      ),
      child: _buildBrandedRow(branding, pageNumber, pagesCount, companyName, defaultFooterText),
    );
  }

  static pw.Widget _buildBrandedColoured({
    required PdfBranding branding,
    required int pageNumber,
    required int pagesCount,
    required String companyName,
    required String defaultFooterText,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: PdfBrandTokens.primary(branding),
      child: _buildBrandedRow(branding, pageNumber, pagesCount, companyName, defaultFooterText),
    );
  }

  static pw.Widget _buildBrandedRow(
    PdfBranding branding,
    int pageNumber,
    int pagesCount,
    String companyName,
    String defaultFooterText,
  ) {
    final leftText = branding.footerText.isNotEmpty
        ? branding.footerText
        : defaultFooterText;
    final showName = branding.footerShowCompanyName;
    final showPages = branding.footerShowPageNumbers;

    final rightChildren = <pw.Widget>[];
    if (showName) {
      rightChildren.add(
        pw.Text(companyName, style: PdfBrandTokens.footerBrand(branding)),
      );
    }
    if (showName && showPages) {
      rightChildren.add(
        pw.Text(' · ', style: PdfBrandTokens.footerText(branding)),
      );
    }
    if (showPages) {
      rightChildren.add(
        pw.Text('Page $pageNumber of $pagesCount',
            style: PdfBrandTokens.footerText(branding)),
      );
    }

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(leftText, style: PdfBrandTokens.footerText(branding)),
        if (rightChildren.isNotEmpty)
          pw.Row(children: rightChildren),
      ],
    );
  }

  static pw.Widget _buildLightFooter(
    PdfFooterConfig config,
    int pageNumber,
    int pagesCount,
    Map<String, String> fallbackValues, {
    PdfColor? primaryColor,
    required bool showPageNumbers,
  }) {
    final children = <pw.Widget>[];

    final leftWidgets = _buildTextLines(config.leftLines, fallbackValues, _darkGray);
    children.add(
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: leftWidgets,
        ),
      ),
    );

    final centreWidgets = _buildTextLines(config.centreLines, fallbackValues, _darkGray);
    if (centreWidgets.isNotEmpty) {
      children.add(
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreWidgets,
          ),
        ),
      );
    }

    if (showPageNumbers) {
      children.add(
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: const pw.TextStyle(fontSize: 8, color: _darkGray),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      decoration: pw.BoxDecoration(
        border: pw.Border(top: pw.BorderSide(color: primaryColor ?? _lightGray, width: 2)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static pw.Widget _buildMinimalFooter(
    PdfFooterConfig config,
    int pageNumber,
    int pagesCount,
    Map<String, String> fallbackValues, {
    required bool showPageNumbers,
  }) {
    final children = <pw.Widget>[];

    final leftWidgets = _buildTextLines(config.leftLines, fallbackValues, _midGray);
    children.add(
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: leftWidgets,
        ),
      ),
    );

    final centreWidgets = _buildTextLines(config.centreLines, fallbackValues, _midGray);
    if (centreWidgets.isNotEmpty) {
      children.add(
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreWidgets,
          ),
        ),
      );
    }

    if (showPageNumbers) {
      children.add(
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: const pw.TextStyle(fontSize: 8, color: _midGray),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.only(top: 8),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static pw.Widget _buildColouredFooter(
    PdfFooterConfig config,
    int pageNumber,
    int pagesCount,
    Map<String, String> fallbackValues, {
    required PdfColor bgColor,
    required bool showPageNumbers,
  }) {
    final children = <pw.Widget>[];

    final leftWidgets = _buildTextLines(config.leftLines, fallbackValues, _white);
    children.add(
      pw.Expanded(
        flex: 3,
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: leftWidgets,
        ),
      ),
    );

    final centreWidgets = _buildTextLines(config.centreLines, fallbackValues, _white);
    if (centreWidgets.isNotEmpty) {
      children.add(
        pw.Expanded(
          flex: 3,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: centreWidgets,
          ),
        ),
      );
    }

    if (showPageNumbers) {
      children.add(
        pw.Text(
          'Page $pageNumber of $pagesCount',
          style: pw.TextStyle(fontSize: 8, color: _white),
        ),
      );
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: bgColor,
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  static List<pw.Widget> _buildTextLines(
    List<HeaderTextLine> lines,
    Map<String, String> fallbackValues,
    PdfColor textColor,
  ) {
    final widgets = <pw.Widget>[];
    for (final line in lines) {
      final text = line.value.isNotEmpty
          ? line.value
          : (fallbackValues[line.key] ?? '');
      if (text.isEmpty) continue;

      widgets.add(
        pw.Text(
          text,
          style: pw.TextStyle(
            fontSize: line.fontSize,
            fontWeight: line.bold ? pw.FontWeight.bold : null,
            color: textColor,
          ),
        ),
      );
    }
    return widgets;
  }
}
