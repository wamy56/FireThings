import 'package:pdf/widgets.dart' as pw;
import '../models/pdf_branding.dart';
import 'pdf_widgets/pdf_brand_tokens.dart';

class PdfFooterBuilder {
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
}
